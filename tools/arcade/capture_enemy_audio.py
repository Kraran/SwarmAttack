"""Record MAME audio and sound-register writes against a local input replay.

ROMs, replays and resulting captures stay outside the game distribution.
"""
import argparse
import csv
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=Path("D:/mame/mame.exe"))
    parser.add_argument("--rom-dir", type=Path, required=True)
    parser.add_argument("--machine", required=True)
    parser.add_argument("--replay", type=Path, required=True)
    parser.add_argument("--frames", type=int, default=20800)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with args.replay.open(newline="") as source, (output / "inputs.csv").open("w", newline="") as target:
        writer = csv.writer(target)
        writer.writerow(["frame", "coin", "start", "left", "right", "fire"])
        previous = None
        for row in csv.DictReader(source):
            if int(row["frame"]) >= args.frames:
                break
            controls = [row[key] for key in ["coin", "start", "left", "right", "fire"]]
            if controls != previous:
                writer.writerow([row["frame"], *controls])
                previous = controls
    lua = Path(__file__).with_name("trace.lua").read_text(encoding="utf-8")
    extra = r'''
local sound = assert(io.open("sound.csv", "wb"))
sound:write("frame;time;address;data;wave;loss;pc\n")
local commands = assert(io.open("commands.csv", "wb"))
commands:write("frame;command;wave;slot;phase;turns\n")
local taps = {}
local function tap(first, last)
    taps[#taps + 1] = program:install_write_tap(first, last, "enemy_audio", function(offset, data)
        if offset >= 0xa800 or (offset & 7) >= 4 then
            local address = offset & (offset >= 0xb800 and 0xf800 or 0xf807)
            sound:write(string.format("%d;%.9f;%04x;%02x;%02x;%02x;%04x\n", frame,
                emu.time(), address, data, program:read_u8(0x809b), program:read_u8(0x8004),
                machine.devices[":maincpu"].state["PC"].value))
        end
    end)
end
tap(0xa004, 0xa7ff)
tap(0xa800, 0xafff)
tap(0xb800, 0xbfff)
taps[#taps + 1] = program:install_write_tap(0x80ef, 0x80ef, "audio_command", function(offset, data)
    local cpu = machine.devices[":maincpu"]
    if cpu.state["PC"].value == 0x08e6 then
        local ix = cpu.state["IX"].value
        commands:write(string.format("%d;%d;%02x;%04x;%02x;%02x\n", frame,
            cpu.state["E"].value >> 2, program:read_u8(0x809b), ix,
            program:read_u8((ix + 5) & 0xffff), program:read_u8((ix + 7) & 0xffff)))
    end
end)
'''
    lua = lua.replace("local subscription\n", extra + "\nlocal subscription\n")
    # Keep the tap handles alive for the whole capture (Lua otherwise collects them).
    lua = lua.replace('function()\n    output:write', 'function()\n    assert(#taps == 4)\n    output:write')
    lua = lua.replace('assert(output:close())', 'assert(output:close())\n        assert(sound:close())\n        assert(commands:close())')
    script = output / "record.lua"
    script.write_text(lua, encoding="utf-8")
    command = [str(args.mame.resolve()), "-noreadconfig", "-rompath", str(args.rom_dir.resolve()), args.machine,
               "-nowriteconfig", "-noplugins", "-noautosave", "-video", "none", "-sound", "none",
               "-wavwrite", "original.wav", "-samplerate", "48000", "-nothrottle", "-frameskip", "0",
               "-cfg_directory", "cfg", "-nvram_directory", "nvram", "-seconds_to_run", str(args.frames // 60 + 4),
               "-autoboot_delay", "0", "-autoboot_script", str(script)]
    env = dict(os.environ, SWARM_SCENARIO="replay", SWARM_FRAMES=str(args.frames),
               SWARM_SNAPSHOT_INTERVAL="0", SWARM_SNAPSHOT_START="0", SWARM_PROBE="8000-83ff", SWARM_PROBE_START="0")
    subprocess.run(command, cwd=output, env=env, check=True, timeout=max(90, args.frames // 30))
    print("Recorded:", output)


if __name__ == "__main__":
    main()

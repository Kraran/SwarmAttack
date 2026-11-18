"""Capture enemy flight/impacts, docking and bonus through MAME's sound driver.

Uses the sound-command table of the locally analysed arcade program. No ROM data
is copied to the game: MAME renders the audio into an isolated capture directory.
"""
import argparse
from array import array
import csv
import json
from pathlib import Path
import subprocess
import wave

NAMES = {0: "enemy_ring", 1: "enemy_interceptor", 2: "enemy_claw", 3: "enemy_meteor", 4: "enemy_row",
         5: "hit_ring", 6: "hit_interceptor", 7: "hit_claw", 8: "hit_meteor", 9: "hit_row",
         15: "dock", 16: "bonus"}
LUA = r'''
local machine = manager.machine
local program = machine.devices[":maincpu"].spaces["program"]
local log = assert(io.open("cues.csv", "w"))
log:write("command;start;end\n")
local selected = {0,1,2,3,4,5,6,7,8,9,15,16}
local frame, index, command, start = 0, 0, -1, 0
local busy = false
local subscription
subscription = emu.add_machine_frame_notifier(function()
    -- Leave the boot RAM test untouched; the attract screen is already silent.
    -- Suspend its fifteen gameplay jobs after boot. Keep the NMI sound driver
    -- running without graphics work stretching its command timing.
    if frame >= 150 then
        for address = 0x801d, 0x802b do program:write_u8(address, 0x20) end
        program:write_u8(0x8004, 0)
    end
    if frame >= 200 and (frame - 200) % 1200 == 0 then
        assert(not busy, "Previous sound did not finish")
        index = index + 1
        command = selected[index]
        local table = 0x08ee + command * 4
        local pointer = program:read_u8(table + 1) + 256 * program:read_u8(table + 2)
        assert(pointer >= 0x0540 and pointer <= 0x0841, "Unexpected sound table")
        for address = 0x80f1, 0x80fa do program:write_u8(address, 0) end
        program:write_u8(0x80f9, program:read_u8(table))
        program:write_u8(0x80ef, pointer & 255)
        program:write_u8(0x80f0, pointer >> 8)
        start, busy = emu.time(), true
    elseif busy then
        local pointer = program:read_u8(0x80ef) + 256 * program:read_u8(0x80f0)
        if program:read_u8(pointer) == 0xfe then
            log:write(string.format("%d;%.9f;%.9f\n", command, start, emu.time()))
            busy = false
        end
    end
    frame = frame + 1
    if frame >= 200 + #selected * 1200 then
        assert(command == 16 and not busy)
        log:close()
        subscription:unsubscribe()
        machine:exit()
    end
end)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mame", type=Path, default=Path("D:/mame/mame.exe"))
    parser.add_argument("--rom-dir", type=Path, required=True)
    parser.add_argument("--machine", required=True)
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    capture, output = args.capture.resolve(), args.output.resolve()
    capture.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    script = capture / "isolate.lua"
    script.write_text(LUA, encoding="utf-8")
    subprocess.run([str(args.mame.resolve()), "-noreadconfig", "-rompath", str(args.rom_dir.resolve()),
                    args.machine, "-nowriteconfig", "-noplugins", "-noautosave", "-video", "none",
                    "-sound", "none", "-wavwrite", "isolated.wav", "-samplerate", "48000",
                    "-nothrottle", "-frameskip", "0", "-cfg_directory", "cfg", "-nvram_directory", "nvram",
                    "-seconds_to_run", "250", "-autoboot_delay", "0", "-autoboot_script", str(script)],
                   cwd=capture, check=True, timeout=120)
    with wave.open(str(capture / "isolated.wav")) as source:
        assert (source.getnchannels(), source.getsampwidth(), source.getframerate()) == (1, 2, 48000)
        pcm = array("h", source.readframes(source.getnframes()))
    metadata = []
    with (capture / "cues.csv").open() as source:
        for row in csv.DictReader(source, delimiter=";"):
            command = int(row["command"])
            start, end = (float(row[key].replace(",", ".")) for key in ("start", "end"))
            samples = pcm[round(start * 48000):round((end + 0.08) * 48000)]
            assert len(samples) > 4800 and max(map(abs, samples)) > 1000
            # Short anti-click ramps preserve the recorded body and level.
            for index in range(96):
                samples[index] = round(samples[index] * index / 95)
            for index in range(480):
                samples[-1-index] = round(samples[-1-index] * index / 479)
            with wave.open(str(output / (NAMES[command] + ".wav")), "wb") as target:
                target.setparams((1, 2, 48000, 0, "NONE", "not compressed"))
                target.writeframes(samples.tobytes())
            metadata.append(dict(name=NAMES[command], command=command, start=start, end=end,
                                 duration=len(samples)/48000, peak=max(map(abs, samples))))
    assert len(metadata) == len(NAMES)
    (capture / "extraction.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    for cue in metadata:
        print(cue["name"], round(cue["duration"],3), "s", "peak", cue["peak"])


if __name__ == "__main__":
    main()

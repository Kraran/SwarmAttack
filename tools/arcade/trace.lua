-- Relevé des registres vidéo et des entrées à la fin de chaque frame MAME.
local machine = manager.machine
local screen = assert(machine.screens[":screen"])
local program = assert(machine.devices[":maincpu"].spaces["program"])
local scenario = assert(os.getenv("SWARM_SCENARIO"))
local frames = assert(tonumber(os.getenv("SWARM_FRAMES")))
local snapshot_interval = assert(tonumber(os.getenv("SWARM_SNAPSHOT_INTERVAL")))
local snapshot_start = assert(tonumber(os.getenv("SWARM_SNAPSHOT_START")))
local probe_list = os.getenv("SWARM_PROBE") or ""
local probe_start = tonumber(os.getenv("SWARM_PROBE_START") or "0")

local function get_field(port, mask)
    for _, field in pairs(assert(machine.ioport.ports[port]).fields) do
        if field.mask == mask then
            return field
        end
    end
    error(string.format("Champ introuvable %s/%02x", port, mask))
end

local controls = {
    coin = get_field(":IN0", 0x01),
    start = get_field(":IN1", 0x01),
    left = get_field(":IN0", 0x04),
    right = get_field(":IN0", 0x08),
    fire = get_field(":IN0", 0x10),
}

local function active(frame, first, last)
    return (frame >= first and frame <= last) and 1 or 0
end

local function scripted_inputs(frame)
    local fire = 0
    if scenario == "fire" then
        fire = active(frame, 535, 814)
    elseif scenario == "fire_tap" then
        fire = math.max(active(frame, 535, 547), active(frame, 554, 557),
            active(frame, 600, 604), active(frame, 675, 679),
            active(frame, 750, 754), active(frame, 800, 804))
    elseif scenario == "fire_busy" then
        fire = math.max(active(frame, 535, 547), active(frame, 554, 630), active(frame, 640, 647))
    end
    local opposed = scenario == "opposed" and active(frame, 570, 589) or 0
    return {
        coin = scenario ~= "attract" and active(frame, 120, 123) or 0,
        start = scenario ~= "attract" and active(frame, 150, 153) or 0,
        left = scenario == "movement" and active(frame, 535, 604) or opposed,
        right = scenario == "movement" and active(frame, 615, 784) or opposed,
        fire = fire,
    }
end

local function replay_inputs()
    local states = {}
    local file = assert(io.open("inputs.csv", "r"))
    assert(file:read("*l"))
    for row in file:lines() do
        local frame, coin, start, left, right, fire = row:match("^(%d+),([01]),([01]),([01]),([01]),([01])$")
        states[assert(tonumber(frame))] = {
            coin = tonumber(coin), start = tonumber(start), left = tonumber(left),
            right = tonumber(right), fire = tonumber(fire),
        }
    end
    file:close()
    local state = assert(states[0])
    return function(frame)
        state = states[frame] or state
        return state
    end
end

local inputs = scenario == "replay" and replay_inputs() or scripted_inputs

local function registers(first, last)
    local values = {}
    for addr = first, last do
        values[#values + 1] = string.format("%02x", program:read_u8(addr))
    end
    return table.concat(values)
end

local output = assert(io.open("trace.csv", "wb"))
output:write("frame,coin,start,left,right,fire,tile_scroll,sprite_ram,bullet_ram\n")

-- Sonde optionnelle : plages d'adresses du programme, une colonne par plage.
local probe_ranges = {}
for first, last in probe_list:gmatch("(%x+)%-(%x+)") do
    probe_ranges[#probe_ranges + 1] = {tonumber(first, 16), tonumber(last, 16)}
end
local probe
if #probe_ranges > 0 then
    probe = assert(io.open("probe.csv", "wb"))
    probe:write("frame," .. probe_list .. "\n")
end

local frame = 0
local applied = inputs(frame)
for name, field in pairs(controls) do
    field:set_value(applied[name])
end

local subscription
subscription = emu.add_machine_frame_notifier(function()
    output:write(string.format("%d,%d,%d,%d,%d,%d,%s,%s,%s\n",
        frame, applied.coin, applied.start, applied.left, applied.right, applied.fire,
        registers(0x9800, 0x983f), registers(0x9840, 0x985f), registers(0x9860, 0x987f)))

    if probe and frame >= probe_start then
        local values = {}
        for index, range in ipairs(probe_ranges) do
            values[index] = registers(range[1], range[2])
        end
        probe:write(string.format("%d,%s\n", frame, table.concat(values, ",")))
    end

    if snapshot_interval > 0 and frame >= snapshot_start
        and (frame - snapshot_start) % snapshot_interval == 0 then
        local filename = string.format("frame-%05d.png", frame)
        assert(not screen:snapshot(filename), "Capture impossible : " .. filename)
    end

    frame = frame + 1
    if frame == frames then
        if probe then
            assert(probe:close())
        end
        assert(output:close())
        subscription:unsubscribe()
        machine:exit()
        return
    end

    applied = inputs(frame)
    for name, field in pairs(controls) do
        field:set_value(applied[name])
    end
end)

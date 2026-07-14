
local raycaster = peripheral.find('raycaster')

local ships = {}
local mode = 'SEEKING'
local target_ship_id = 37

local sqrt = math.sqrt
local tan = math.tan
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local asin = math.asin
local insert = table.insert
local rad = math.rad

local function calculate_cone( pitch_range, pitch_tries, yaw_range, yaw_tries)
    local len_args = 0
    local args = {}
    
    for pitch = -pitch_range/2, pitch_range/2, (pitch_range/pitch_tries) do
        for yaw = -yaw_range/2, yaw_range/2, (yaw_range/yaw_tries) do
            local x, y, z = cos(yaw), sin(pitch), sin(yaw)
            
            local len = sqrt(x^2 + y^2 + z^2)
            
            local pitch, yaw = asin(y/len), asin(z/len)
            
            len_args = len_args + 1
            args[len_args] = {tan(pitch), tan(yaw)}
        end
        sleep()
    end

    return args
end

local function try(cone, max_distance)
    for i = 1, #cone do
        local args = cone[i]

        local result = raycaster.raycast(max_distance, args, false, true, true)

        if result.ship_id then
            ships[result.ship_id] = {
                position =  result.hit_pos,
                timestamp = os.clock()
            }
        end

        if (i % 1000) == 0 then
            sleep()
        end
    end
end

local wide = calculate_cone(rad(22), 22, rad(120), 800)
local function seeking()
    while true do
        repeat sleep()
        until mode == 'SEEKING'
        
        try(wide, 300)
    end
end

local function transformVector(q, v)
    local u = vector.new(q.x, q.y, q.z)
    return u * (u * 2):dot(v) + v*(q.w * q.w - u:dot(u)) + (u * 2 * q.w):cross(v)
end

function vector.fromTable(t)
    return vector.new(t.x, t.y, t.z)
end

local function inverseQuat(q)
    return {
        x = -q.x,
        y = -q.y,
        z = -q.z,
        w = q.w
    }
end

local shipyard_offset = vector.new(0,0.5,-1)

local function getAngles(v)
    local yaw = atan2(v.x, v.z)
    local pitch = asin(v.y)
    return yaw, pitch
end

local function getRaycasterRay()
    local quat = ship.getQuaternion()

    local offset = transformVector(quat, shipyard_offset)
    local pos = vector.fromTable(ship.getWorldspacePosition()):add(offset)

    local dir = vector.new(0, 0, -1)
    dir = transformVector(quat, dir)

    return {pos=pos, dir=dir}
end

local function tracking()
    while true do
        repeat sleep()
        until mode == 'TRACKING'
        
        local r = getRaycasterRay()
        local t = ships[target_ship_id].position
        
        local pos = r.pos
        local dir = r.dir
        
        local target_pos = vector.new(t[1], t[2], t[3])
        local target_dir = target_pos:sub(pos)
        
        local target_relativeTo_raycaster = transformVector(inverseQuat(ship.getQuaternion()), target_dir)

        local vec = target_relativeTo_raycaster
        local dYaw, dPitch = getAngles(vec:normalize())

        local hit_positions = {}

        local raycasts = 25
        local height = 6
        local width = 24

        local distance = target_dir:length()
        local yaw_range = atan2(width, distance)
        local pitch_range = atan2(height, distance)
        
        local yaw_step = yaw_range/raycasts*2
        local pitch_step = pitch_range/raycasts*2

        for yaw = -yaw_range, yaw_range, yaw_step do
            for pitch = -pitch_range, pitch_range, pitch_step do
                local result = raycaster.raycast(500, {math.tan(dPitch + pitch), math.tan(-dYaw + yaw)}, false, true, true)
                if (result.hit_pos) and (result.ship_id == target_ship_id) then
                    insert(hit_positions, result.hit_pos)
                end
            end
        end

        local count = #hit_positions
        if not (count == 0) then
            local total_pos = vector.new()

            for i, pos in pairs(hit_positions) do
                total_pos = total_pos:add(vector.new(pos[1], pos[2], pos[3]))
            end

            local t = total_pos:div(count)
            ships[target_ship_id].timestamp = os.clock()
            ships[target_ship_id].position = {t.x,t.y,t.z}
        end
        
        sleep()
    end
end

local abandon_time = 3
local function main()
    while true do
        print(textutils.serialise(ships))
        print(mode)

        local target = ships[target_ship_id]
        local time_stamp = os.clock()

        if target and (time_stamp - target.timestamp) < abandon_time then
            print(time_stamp - target.timestamp)

            local t = ships[target_ship_id].position
            commands.execAsync('/vs teleport pointer '..t[1]..' '..(t[2]+5)..' '..t[3])
            
            mode = 'TRACKING'
        else
            commands.execAsync('/vs teleport pointer 0 0 0')
            mode = 'SEEKING'
        end
        

        sleep()
        term.clear()
    end
end

parallel.waitForAll(seeking, seeking, tracking, tracking, main)
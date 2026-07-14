local PITCH = peripheral.wrap("back")
local YAW = peripheral.wrap("right")
local PITCH_DIR = -1
local YAW_DIR = -1
local FIRE = "top"
local RELOAD_SPEED = 5
LOW_ANGLE = 1
HIGH_ANGLE = 2
RPM_TO_CDPT = ((360/60) / 20) / 8 -- rpm to cannon degrees per tick
MAX_SPEED = 32

local current = {
    x = -71,
    y = 69,
    z = -273
}
local target = {
    x = 55,
    y = 69,
    z = 36
}
local ammo_config = {
    gravity = -0.025,
    drag = 0.01
}
local cannon_config = {
    length = 6,
    trajectory = HIGH_ANGLE,
    min_pitch = -30,
    max_pitch = 60
}

-- Input: current and target coordinates
-- Output: yaw needed to hit target in degrees
local function calculate_yaw(current, target, cannon_config)
    local dx = target.x - current.x
    local dz = target.z - current.z
    local yaw = math.deg(math.atan2(-dx, dz))
    return yaw
end

-- Input: current and target coordinates
-- Output: horizontal distance to target in blocks
local function calculate_distance(current, target)
    local delta_x = target.x - current.x
    local delta_z = target.z - current.z
    local distance = math.sqrt(delta_x^2 + delta_z^2)
    return distance
end

-- Calculates the pitch at which the projectile will barely reach the target
-- If the solution exists, it should be within the +/- of the returned pitch
local function calculate_pitch_limits(distance, speed, ammo_config, cannon_config)
    local drag = ammo_config.drag
    local speed = speed / 20 -- Convert to blocks per tick

    local pitch_limit = math.acos((2 * distance * drag) / (speed * (2 - drag) + (2 * cannon_config.length * drag))) * 0.999
    
    return math.deg(pitch_limit)
end

local function try_pitch(pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
    local pitch_rad = math.rad(pitch)
    local gravity = ammo_config.gravity
    local drag = ammo_config.drag
    local speed = speed / 20 -- Convert to blocks per tick

    -- Adjust distance and elevation to account for cannon length
    -- Starting point is the cannon muzzle
    local distance = distance - (cannon_config.length * math.cos(pitch_rad))
    local elevation_diff = elevation_diff - (cannon_config.length * math.sin(pitch_rad))

    local horizontalVel = speed * math.cos(pitch_rad)
    local verticalVel = speed * math.sin(pitch_rad)

    -- Calculate t based on horizontal time to target
    local maxDistance = ((2 - drag) * horizontalVel) / (2 * drag)
    -- Check if target is out of range. If it is, return a large negative error
    if distance >= maxDistance then return -math.huge end
    local t = math.log(1 - (distance / maxDistance), 1 - drag)

    -- Calculate y based on t
    local terminalVelocity = gravity / drag
    local a = 1 - (drag / 2)
    local b = verticalVel - terminalVelocity
    local c = (1 - (1 - drag)^t) / drag
    local d = terminalVelocity * t
    
    local y = (a * b * c) + d
    local error = y - elevation_diff

    return error
end

-- Use secant method to find the root based on two starting angles
-- If there is no solution, it returns nil
local function calculate_pitch(seed_pitch_0, seed_pitch_1, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
    -- Initialize 2 points for secant
    local pitch_prev = seed_pitch_0
    local pitch = seed_pitch_1
    local error_prev = try_pitch(pitch_prev, distance, elevation_diff, speed, ammo_config, cannon_config)
    local error = try_pitch(pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
    
    local max_iter = 20
    local error_tol = 0.1
    local min_slope = 1e-8  -- derivative threshold

    for i = 1, max_iter do
        print(i)
        -- Calculate slope between 2 points
        local slope = (error - error_prev) / (pitch - pitch_prev)

        -- Check if slope is too small
        -- NR/secant will fail on slopes close to 0
        if math.abs(slope) < min_slope then
            return nil
        end

        -- Secant step
        pitch_prev = pitch
        error_prev = error
        pitch = pitch_prev - (error_prev / slope)

        -- Clamp if next point is out of bounds
        pitch = math.min(math.max(pitch, min_pitch), max_pitch)

        error = try_pitch(pitch, distance, elevation_diff, speed, ammo_config, cannon_config)

        -- Check if error is within tolerance
        if math.abs(error) < error_tol then
            return pitch  -- Converged
        end
    end

    -- Max iterations reached without convergence
    return nil
end

local function calculate_pitch_from_scratch(distance, elevation_diff, speed, ammo_config, cannon_config)
    local pitch_limit = calculate_pitch_limits(distance, speed, ammo_config, cannon_config)
    local min_pitch = math.max(-pitch_limit, cannon_config.min_pitch)
    local max_pitch = math.min(pitch_limit, cannon_config.max_pitch)

    local pitch = nil
    -- Prioritize high trajectory
    if cannon_config.trajectory == HIGH_ANGLE then
        pitch = calculate_pitch(max_pitch - 0.01, max_pitch, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
        if pitch == nil then
            pitch = calculate_pitch(min_pitch, min_pitch + 0.01, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
        end
    -- Prioritize low trajectory
    else
        pitch = calculate_pitch(min_pitch, min_pitch + 0.01, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)
        if pitch == nil then
            pitch = calculate_pitch(max_pitch - 0.01, max_pitch, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)            
        end
    end

    return pitch
end

local function calculate_pitch_from_seed(seed_pitches, distance, elevation_diff, speed, ammo_config, cannon_config)
    local seed_pitch_0 = nil
    local seed_pitch_1 = nil
    -- If seed_pitches is a single variable, then treat it as a seed pitch
    if type(seed_pitches) ~= "table" then
        seed_pitch_0 = seed_pitches - 0.01
        seed_pitch_1 = seed_pitches + 0.01
    -- If seed_pitches is a table, then use the closest seed
    else
        local closest_seed_pitch = nil
        local smallest_error = math.huge
        for _, seed in ipairs(seed_pitches) do
            local error = math.abs(seed.distance - distance)
            if error < smallest_error and seed.pitch ~= nil then
                closest_seed_pitch = seed.pitch
                smallest_error = error
            end
        end
        seed_pitch_0 = closest_seed_pitch - 0.01
        seed_pitch_1 = closest_seed_pitch + 0.01
    end

    local pitch_limit = calculate_pitch_limits(distance, speed, ammo_config, cannon_config)
    local min_pitch = math.max(-pitch_limit, cannon_config.min_pitch)
    local max_pitch = math.min(pitch_limit, cannon_config.max_pitch)

    pitch = calculate_pitch(seed_pitch_0, seed_pitch_1, min_pitch, max_pitch, distance, elevation_diff, speed, ammo_config, cannon_config)

    return pitch
end

local function aim_cannon(current_yaw, target_yaw, current_pitch, target_pitch)
    local aim_yaw = function()
        local yaw = current_yaw
        local delta_yaw = (target_yaw - yaw + 180) % 360 - 180
        while delta_yaw ~= 0 do
            local needed_RPM = (delta_yaw) / RPM_TO_CDPT
            needed_RPM = math.min(math.max(needed_RPM, -MAX_SPEED), MAX_SPEED)
            YAW.setTargetSpeed(needed_RPM * YAW_DIR)
            delta_yaw = delta_yaw - needed_RPM * RPM_TO_CDPT
        end
        YAW.setTargetSpeed(0)
    end
    local aim_pitch = function()
        local pitch = current_pitch
        while pitch ~= target_pitch do
            local needed_RPM = (target_pitch - pitch) / RPM_TO_CDPT
            needed_RPM = math.min(math.max(needed_RPM, -MAX_SPEED), MAX_SPEED)
            PITCH.setTargetSpeed(needed_RPM * PITCH_DIR)
            pitch = pitch + needed_RPM * RPM_TO_CDPT
        end
        PITCH.setTargetSpeed(0)
    end
    parallel.waitForAll(aim_yaw, aim_pitch)
    return target_yaw, target_pitch
end

local function generate_circle_seedlist(current, center, r, speed, ammo_config, cannon_config)
    -- Seed the center and edges
    local distance = calculate_distance(current, target)
    local elevation_diff = target.y - current.y
    local center_pitch = calculate_pitch_from_scratch(distance, elevation_diff, speed, ammo_config, cannon_config)
    local closest_pitch = calculate_pitch_from_seed(center_pitch, distance - r, elevation_diff, speed, ammo_config, cannon_config)
    local furthest_pitch = calculate_pitch_from_seed(center_pitch, distance + r, elevation_diff, speed, ammo_config, cannon_config)
    local seedlist = {
        {distance = distance - r, pitch = closest_pitch},
        {distance = distance, pitch = center_pitch},
        {distance = distance + r, pitch = furthest_pitch}
    }
    return seedlist
end

local function generate_circle_point(center, radius)
    -- Uniform polar coordinates
    local angle = math.random() * 2 * math.pi
    local r = radius * math.sqrt(math.random()) -- sqrt to make distribution uniform

    return {
        x = center.x + r * math.cos(angle),
        y = center.y,
        z = center.z + r * math.sin(angle)
    }
end

local function generate_rectangle_seedlist(current, p1, p2, speed, ammo_config, cannon_config)
    -- Find the closest point, center, and furthest point from the rectange
    local xmin = math.min(p1.x, p2.x)
    local xmax = math.max(p1.x, p2.x)
    local zmin = math.min(p1.z, p2.z)
    local zmax = math.max(p1.z, p2.z)
    
    local center_point = {
        x = (p1.x + p2.x) / 2,
        y = (p1.y + p2.y) / 2,
        z = (p1.z + p2.z) / 2
    }
    local closest_point = {
        x = math.max(xmin, math.min(current.x, xmax)),
        z = math.max(zmin, math.min(current.z, zmax))
    }
    local furthest_point = {
        x = (current.x < (xmin + xmax) * 0.5) and xmax or xmin,
        z = (current.z < (zmin + zmax) * 0.5) and zmax or zmin
    }
    
    local elevation_diff = target.y - center_point.y

    local center_distance = calculate_distance(current, center_point)
    local center_pitch = calculate_pitch_from_scratch(center_distance, elevation_diff, speed, ammo_config, cannon_config)
    local closest_distance = calculate_distance(current, closest_point)
    local closest_pitch = calculate_pitch_from_seed(center_pitch, closest_distance, elevation_diff, speed, ammo_config, cannon_config)
    local furthest_distance = calculate_distance(current, furthest_point)
    local furthest_pitch = calculate_pitch_from_seed(center_pitch, furthest_distance, elevation_diff, speed, ammo_config, cannon_config)

    local seedlist = {
        {distance = closest_distance, pitch = closest_pitch},
        {distance = center_distance, pitch = center_pitch},
        {distance = furthest_distance, pitch = furthest_pitch}
    }
    return seedlist
end

local function generate_rectangle_point(p1, p2)
    return {
        x = p1.x + math.random() * (p2.x - p1.x),
        y = (p1.y + p2.y) / 2,
        z = p1.z + math.random() * (p2.z - p1.z)
    }
end

local function generate_line_seedlist(current, p1, p2, r, speed, ammo_config, cannon_config)
    -- Find the closest point, center, and furthest point from the line (capsule)
    -- Closest point
    local closest_point = {
        x = nil,
        z = nil
    }
    local p12 = {
        x = p2.x - p1.x,
        z = p2.z - p1.z
    }
    local len2 = p12.x^2 + p12.z^2      -- length squared
    if len2 == 0 then
        closest_point = {         -- line is a single point
            x = p1.x,
            z = p1.z
        }
    else
        local proj = ((current.x - p1.x) * p12.x + (current.z - p1.z) * p12.z) / len2
        proj = math.max(math.min(proj, 1), 0)
        closest_point = {
            x = p1.x + p12.x * proj,
            z = p1.z + p12.z * proj
        }
    end
    -- Center point
    local center_point = {
        x = (p1.x + p2.x) / 2,
        y = (p1.y + p2.y) / 2,
        z = (p1.z + p2.z) / 2
    }
    -- Furthest point
    local furthest_point = {
        x = nil,
        z = nil
    }
    if calculate_distance(current, p1) > calculate_distance(current, p2) then
        furthest_point = {
            x = p1.x,
            z = p1.z
        }
    else
        furthest_point = {
            x = p2.x,
            z = p2.z
        }
    end
    
    local elevation_diff = target.y - center_point.y

    local center_distance = calculate_distance(current, center_point)
    local center_pitch = calculate_pitch_from_scratch(center_distance, elevation_diff, speed, ammo_config, cannon_config)
    local closest_distance = calculate_distance(current, closest_point) - r
    local closest_pitch = calculate_pitch_from_seed(center_pitch, closest_distance, elevation_diff, speed, ammo_config, cannon_config)
    local furthest_distance = calculate_distance(current, furthest_point) + r
    local furthest_pitch = calculate_pitch_from_seed(center_pitch, furthest_distance, elevation_diff, speed, ammo_config, cannon_config)

    local seedlist = {
        {distance = closest_distance, pitch = closest_pitch},
        {distance = center_distance, pitch = center_pitch},
        {distance = furthest_distance, pitch = furthest_pitch}
    }
    return seedlist
end

local function generate_line_point(p1, p2, r)
    -- Pick a point on the line
    local k = math.random()
    local point = {
        x = p1.x + k * (p2.x - p1.x),
        z = p1.z + k * (p2.z - p1.z)
    }
    -- Pick an offset (based on the width) and an angle to add to the point
    local angle = math.random() * 2 * math.pi
    local offset = r * math.sqrt(math.random()) -- sqrt to make distribution uniform
    return {
        x = point.x + offset * math.cos(angle),
        y = (p1.y + p2.y) / 2,
        z = point.z + offset * math.sin(angle)
    }
end

-- local elevation_diff = target.y - current.y

-- local current_yaw = 90
-- local current_pitch = 0

-- local seedlist = generate_circle_seedlist(current, target, 10, 120, ammo_config, cannon_config)

-- while true do
--     local new_target = generate_circle_point(target, 10)
--     local new_distance = calculate_distance(current, new_target)
--     local new_yaw = calculate_yaw(current, new_target, cannon_config)
--     local new_pitch = calculate_nearby_pitch(seedlist, -30, 60, new_distance, elevation_diff, 120, ammo_config, cannon_config)
--     print(new_yaw)
--     print(new_pitch)
--     if new_pitch then
--         current_yaw, current_pitch = aim_cannon(current_yaw, new_yaw, current_pitch, new_pitch)
--         sleep(1)
--         redstone.setOutput(FIRE, true)
--         sleep(1)
--         redstone.setOutput(FIRE, false)
--         sleep(3)
--     else
--         print("Could not converge")
--     end
-- end

-- local p1 = {
--     x = 158,
--     y = 68,
--     z = -517
-- }
-- local p2 = {
--     x = 190,
--     y = 64,
--     z = -479
-- }

-- local current_yaw = 0
-- local current_pitch = 0

-- local elevation_diff = target.y - current.y
-- local distance = calculate_distance(current, target)
-- local speed = 120

-- -- local seedlist = generate_circle_seedlist(current, target, 32, speed, ammo_config, cannon_config)
-- -- local seedlist = generate_rectangle_seedlist(current, p1, p2, speed, ammo_config, cannon_config)
-- local seedlist = generate_line_seedlist(current, p1, p2, 5, speed, ammo_config, cannon_config)
-- while true do
--     -- local next_target = generate_circle_point(target, 32)
--     -- local next_target = generate_rectangle_point(p1, p2)
--     local next_target = generate_line_point(p1, p2, 5)
--     local yaw = calculate_yaw(current, next_target, cannon_config)
--     distance = calculate_distance(current, next_target)
--     local pitch = calculate_pitch_from_seed(seedlist, distance, elevation_diff, speed, ammo_config, cannon_config)
--     if pitch ~= nil then
--         print("Valid shot, aiming")
--         current_yaw, current_pitch = aim_cannon(current_yaw, yaw, current_pitch, pitch)
--     else
--         print("Invalid shot, skipping")
--     end
--     redstone.setOutput(FIRE, true)
--     sleep(1)
--     redstone.setOutput(FIRE, false)
--     sleep(4)
-- end

-- local pitch = calculate_pitch_from_scratch(distance, elevation_diff, speed, ammo_config, cannon_config)

-- current_yaw, current_pitch = aim_cannon(current_yaw, yaw, current_pitch, pitch)

local function calibrate_cannon()
    MAX_SPEED = 1
    write("Current yaw: ")
    current_yaw = read()
    if current_yaw == "" then current_yaw = yaw end
    write("Current pitch: ")
    current_pitch = read()
    if current_pitch == "" then current_pitch = pitch end
    print("Calibrating...")
    current_yaw, current_pitch = aim_cannon(current_yaw, yaw, current_pitch, pitch)
    print("Calibration complete")
end

local function fire()
    redstone.setOutput(FIRE, true)
    sleep(1)
    redstone.setOutput(FIRE, false)
    sleep(4)
end


return {
    calculate_distance = calculate_distance,
    calculate_yaw = calculate_yaw,
    calculate_pitch_from_scratch = calculate_pitch_from_scratch,
    calculate_pitch_from_seed = calculate_pitch_from_seed,
    generate_circle_point = generate_circle_point,
    aim_cannon = aim_cannon
}

-- calibrate_cannon()
-- fire_loop()
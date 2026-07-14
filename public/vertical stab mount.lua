local rsc = peripheral.wrap('left')

local offset_yaw = math.rad(90) * 0 -- * [0 - 4]

local mount_constant = 320 / 252

local last_o = 0
local cos, sin = math.cos, math.sin
local deg = math.deg
while true do
    local control_rpm = (redstone.getInput('front') and 12 or 0) + (redstone.getInput('right') and -12 or 0)
    
    local o = ship.getOmega()
    local yaw = -ship.getYaw() + offset_yaw

    local omega_pitch = cos(yaw) * o.x - sin(yaw) * o.z

    local accel = (omega_pitch - last_o) / 0.05
    last_o = omega_pitch

    local counter_velocity = -deg(omega_pitch + accel*0.1) * mount_constant

    rsc.setTargetSpeed(counter_velocity + control_rpm)
end

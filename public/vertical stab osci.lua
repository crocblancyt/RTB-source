local rsc = peripheral.wrap('front')
local rad_to_rpm = 1/math.pi/2*60

local offset_yaw = math.rad(90) * 0 -- * [0 - 4]

local last_o = 0
local cos, sin = math.cos, math.sin

function ship.getYaw()
    local q = ship.getQuaternion()
    return math.atan2(2 * (q.w * q.y + q.x * q.z), 1 - 2 * (q.y * q.y + q.x * q.x))
end

while true do
    local control_rpm = (redstone.getInput('front') and 12 or 0) + (redstone.getInput('right') and -12 or 0)
    
    local o = ship.getOmega()
    local yaw = -ship.getYaw() + offset_yaw

    local omega_pitch = cos(yaw) * o.x - sin(yaw) * o.z

    local accel = (omega_pitch - last_o) / 0.05
    last_o = omega_pitch

    local counter_velocity = -(omega_pitch + accel*0.1) * rad_to_rpm

    rsc.setTargetSpeed(counter_velocity + control_rpm*8)
end
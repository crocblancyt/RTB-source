local rsc = peripheral.wrap('left')
local rad_to_rpm = 1/math.pi/2*60

local last_o = 0
while true do
    local control_rpm = (redstone.getInput('front') and 12 or 0) + (redstone.getInput('right') and -12 or 0)
    
    local o = ship.getOmega()
    local accel = (o.y - last_o) / 0.05
    last_o = o.y

    local counter_velocity = -(o.y + accel*0.1) * rad_to_rpm

    rsc.setTargetSpeed(counter_velocity + control_rpm)
end
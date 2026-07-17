local channel = 606
------------ SETUP ------------
--- firstly place the turtle ontop of your depot
--- secondly change the channel to match your pocket computers channel so it can receive input
--- thirdly add ammo, the shellswitcher will switch shells between slots 1-4
--- you can change the keybind for shell switching at line 28 by changing pressedKeys.x from x to your desired keybind
--- that should be about it, the code comes with a findShells() function which will put all current switchable ammo in the shells table which can be useful if you wanna know your current shell and slot and you can pair it with the sendInfo() if you'd like
-------------------------------

local modem = peripheral.find('modem') or error('No modem attached!', 0)
local pressedKeys = {}
modem.open(channel)
turtle.select(1)
local shells ={}

local function inputReciever()
    while true do
		local _, _, channel, _, message = os.pullEvent("modem_message")
		if channel == channel then
			pressedKeys = message
		end
    end
end

local function shellSwitch()
    while true do
        local slot = turtle.getSelectedSlot()
        if pressedKeys.x == true then
            turtle.suckDown()
            turtle.select(slot + 1)
            turtle.dropDown()
        end
        if turtle.getSelectedSlot() == 5 then
            turtle.select(1)
            turtle.suckDown()
            turtle.dropDown()
        end
        sleep()
    end
end

local function findShells()
    for slots = 1, 4 do
        local item = turtle.getItemDetail(slots)
        if item then
            table.insert(shells, item.name)
        end
    end
end
local function sendInfo()
    while true do
        modem.transmit(channel, 0, shells)
    end
end

parallel.waitForAny(inputReciever, shellSwitch)

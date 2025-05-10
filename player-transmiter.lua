-- Transmitter control script

local function initializePeripherals()
    local modem = peripheral.find("modem")
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        rednet.open(modemSide)
        print("RedNet opened on: " .. modemSide)
        return modem
    else
        print("No modem detected")
        return nil
    end
end

local function sendCommand(command)
    local success, err = pcall(function() rednet.broadcast(command) end)
    if success then
        print("Sent: " .. command)
    else
        print("Failed to send: " .. tostring(err))
    end
end

local modem = initializePeripherals()
if not modem then return end

local args = {...}
if #args > 0 then
    sendCommand(table.concat(args, " "))
else
    while true do
        write("Enter command (play <url>, stop, loop, update <url>, exit): ")
        local input = read()
        if input == "exit" then break end
        sendCommand(input)
    end
end

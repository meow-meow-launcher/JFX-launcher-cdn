-- Initialize peripherals
local function initializePeripherals()
    local modem = peripheral.find("modem")
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        if peripheral.getType(modemSide) == "modem" then
            rednet.open(modemSide)
            print("Attempting to open rednet on: " .. modemSide)
            local success = pcall(function() rednet.broadcast("Modem test message") end)
            if success then
                print("Modem test message sent successfully")
            else
                print("Failed to send test message, modem may not be functional")
            end
        else
            print("Modem on " .. modemSide .. " is not of type 'modem'")
            return nil
        end
    else
        print("No modem detected")
        return nil
    end
    return modem
end

-- Initialize modem
local modem = initializePeripherals()
if not modem then
    return
end

-- Send command
local function sendCommand(command)
    if modem then
        pcall(function() rednet.broadcast(command) end)
        print("Sent command: " .. command)
    end
end

-- Get command from arguments or input
local args = {...}
if #args > 0 then
    sendCommand(table.concat(args, " "))
else
    while true do
        print("Enter command (e.g., 'play https://example.com/audio.dfpwm', 'stop', 'loop', 'exit'):")
        local input = read()
        if input == "exit" then break end
        sendCommand(input)
    end
end

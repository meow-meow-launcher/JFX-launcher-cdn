-- Initialize peripherals
local function initializePeripherals()
    local monitor = peripheral.find("monitor")
    local speaker = peripheral.find("speaker")
    local modem = peripheral.find("modem")

    -- Debug peripheral list
    print("Available peripherals: " .. table.concat(peripheral.getNames(), ", "))
    if not speaker then
        print("Warning: No speaker found, audio will be disabled")
    else
        print("Speaker found on: " .. peripheral.getName(speaker))
    end
    if monitor then
        print("Monitor found on: " .. peripheral.getName(monitor))
        monitor.setTextScale(0.5)
    else
        print("No monitor found, using terminal")
    end
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
        end
    else
        print("No modem detected")
    end

    return monitor, speaker, modem
end

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false
local url = ""
local activeSpeaker = nil

-- Get URL from command-line arguments
local args = {...}
if #args > 0 then
    url = args[1]
end

-- Initialize peripherals
local monitor, speaker, modem = initializePeripherals()
activeSpeaker = speaker

-- Draw interface on specified device
local function drawInterface(device)
    device.clear()
    device.setCursorPos(1, 1)
    
    -- URL field
    device.setTextColor(colors.white)
    device.write("URL: " .. url)
    
    -- Buttons
    local buttonY = 3
    device.setCursorPos(2, buttonY)
    
    -- Play button
    if isPlaying then
        device.setBackgroundColor(colors.green)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Play ")
    
    -- Stop button
    device.setCursorPos(10, buttonY)
    if not isPlaying then
        device.setBackgroundColor(colors.red)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Stop ")
    
    -- Loop button
    device.setCursorPos(18, buttonY)
    if isLooping and isPlaying then
        device.setBackgroundColor(colors.yellow)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Loop ")
    
    -- Override button
    device.setCursorPos(26, buttonY)
    device.setBackgroundColor(colors.gray)
    device.write(" Override ")
    
    device.setBackgroundColor(colors.black)
end

-- Update interface on all devices
local function updateInterface()
    drawInterface(term)
    if monitor then
        drawInterface(monitor)
    end
end

-- Input URL
local function inputURL(device)
    device.setCursorPos(6, 1)
    device.setTextColor(colors.white)
    device.setBackgroundColor(colors.black)
    url = read()
    updateInterface()
end

-- Find available speakers
local function findSpeakers()
    local speakers = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "speaker" then
            table.insert(speakers, peripheral.wrap(side))
        end
    end
    return speakers
end

-- Check and switch speaker
local function checkSpeaker()
    local speakers = findSpeakers()
    if #speakers == 0 then
        print("Warning: No speakers available, audio disabled")
        return nil
    end
    if not activeSpeaker or not peripheral.isPresent(peripheral.getName(activeSpeaker)) then
        activeSpeaker = speakers[1]
        if modem then
            pcall(function() rednet.broadcast("Speaker changed to: " .. peripheral.getName(activeSpeaker)) end)
        end
        print("Switched to speaker: " .. peripheral.getName(activeSpeaker))
    end
    return activeSpeaker
end

-- Play DFPM
local function playDFPM()
    if url == "" or isPlaying then return end
    isPlaying = true
    updateInterface()
    activeSpeaker = checkSpeaker()
    if not activeSpeaker then
        print("Cannot play: No speaker available")
        isPlaying = false
        updateInterface()
        return
    end

    -- Load and play in a separate thread
    parallel.waitForAny(
        function()
            local handle = http.get(url, nil, true) -- Binary mode
            if not handle then
                isPlaying = false
                updateInterface()
                return
            end

            while isPlaying do
                local chunk = handle.read(16 * 1024)
                if not chunk then
                    if isLooping then
                        handle.close()
                        handle = http.get(url, nil, true)
                        if not handle then
                            isPlaying = false
                            updateInterface()
                            return
                        end
                        chunk = handle.read(16 * 1024)
                        if not chunk then
                            isPlaying = false
                            updateInterface()
                            return
                        end
                    else
                        isPlaying = false
                        updateInterface()
                        handle.close()
                        return
                    end
                end

                local buffer = decoder(chunk)
                activeSpeaker = checkSpeaker() -- Check for hot-swap
                if activeSpeaker then
                    while not activeSpeaker.playAudio(buffer) do
                        os.pullEvent("speaker_audio_empty")
                    end
                end
                if modem then
                    pcall(function() rednet.broadcast("Playing: " .. url) end)
                end
            end
            handle.close()
        end,
        function()
            while isPlaying do
                os.pullEvent("speaker_audio_empty")
            end
        end
    )
end

-- Stop playback
local function stopDFPM()
    isPlaying = false
    updateInterface()
    if modem then
        pcall(function() rednet.broadcast("Stopped") end)
    end
end

-- Toggle loop mode
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        updateInterface()
        if modem then
            pcall(function() rednet.broadcast("Looping: " .. tostring(isLooping)) end)
        end
    end
end

-- Override speaker
local function overrideSpeaker()
    local speakers = findSpeakers()
    if #speakers > 1 then
        for i, spk in ipairs(speakers) do
            if spk ~= activeSpeaker then
                activeSpeaker = spk
                updateInterface()
                if modem then
                    pcall(function() rednet.broadcast("Speaker overridden to: " .. peripheral.getName(activeSpeaker)) end)
                end
                print("Overridden to speaker: " .. peripheral.getName(activeSpeaker))
                return
            end
        end
    end
end

-- Handle input
local function handleInput()
    while true do
        local event, param1, x, y = os.pullEvent()
        
        if event == "monitor_touch" and monitor then
            if y == 3 then
                if x >= 2 and x <= 7 then -- Play
                    playDFPM()
                elseif x >= 10 and x <= 15 then -- Stop
                    stopDFPM()
                elseif x >= 18 and x <= 23 then -- Loop
                    toggleLoop()
                elseif x >= 26 and x <= 33 then -- Override
                    overrideSpeaker()
                end
            elseif y == 1 then -- URL input
                inputURL(monitor)
            end
        elseif event == "mouse_click" then
            if y == 3 then
                if x >= 2 and x <= 7 then -- Play
                    playDFPM()
                elseif x >= 10 and x <= 15 then -- Stop
                    stopDFPM()
                elseif x >= 18 and x <= 23 then -- Loop
                    toggleLoop()
                elseif x >= 26 and x <= 33 then -- Override
                    overrideSpeaker()
                end
            elseif y == 1 then -- URL input
                inputURL(term)
            end
        end
    end
end

-- Main function
local function main()
    updateInterface()
    handleInput()
end

main()

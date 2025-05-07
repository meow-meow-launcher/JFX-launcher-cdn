-- Initialize peripherals
local function initializePeripherals()
    local speaker = peripheral.find("speaker")
    local modem = peripheral.find("modem")

    -- Debug peripheral list
    print("Available peripherals: " .. table.concat(peripheral.getNames(), ", "))
    if not speaker then
        print("Warning: No speaker found, audio will be disabled")
        return nil, nil
    else
        print("Speaker found on: " .. peripheral.getName(speaker))
    end
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        if peripheral.getType(modemSide) == "modem" then
            rednet.open(modemSide)
            print("Attempting to open rednet on: " .. modemSide)
            local success = pcall(function() rednet.broadcast("Receiver ready") end)
            if success then
                print("Receiver ready message sent successfully")
            else
                print("Failed to send receiver ready message")
            end
        else
            print("Modem on " .. modemSide .. " is not of type 'modem'")
            return speaker, nil
        end
    else
        print("No modem detected")
        return speaker, nil
    end

    return speaker, modem
end

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false
local url = ""
local activeSpeaker = nil

-- Initialize peripherals
local speaker, modem = initializePeripherals()
activeSpeaker = speaker

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
local function playDFPM(newUrl)
    if newUrl then url = newUrl end
    if url == "" or isPlaying then return end
    isPlaying = true
    activeSpeaker = checkSpeaker()
    if not activeSpeaker then
        print("Cannot play: No speaker available")
        isPlaying = false
        return
    end

    print("Playing: " .. url)
    if modem then
        pcall(function() rednet.broadcast("Playing: " .. url) end)
    end

    -- Load and play in a separate thread
    parallel.waitForAny(
        function()
            local handle = http.get(url, nil, true) -- Binary mode
            if not handle then
                isPlaying = false
                print("Failed to load URL: " .. url)
                if modem then
                    pcall(function() rednet.broadcast("Failed to load: " .. url) end)
                end
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
                            print("Failed to reload URL: " .. url)
                            if modem then
                                pcall(function() rednet.broadcast("Failed to reload: " .. url) end)
                            end
                            return
                        end
                        chunk = handle.read(16 * 1024)
                        if not chunk then
                            isPlaying = false
                            print("No data after reload: " .. url)
                            if modem then
                                pcall(function() rednet.broadcast("No data after reload: " .. url) end)
                            end
                            return
                        end
                    else
                        isPlaying = false
                        print("Playback ended: " .. url)
                        if modem then
                            pcall(function() rednet.broadcast("Playback ended: " .. url) end)
                        end
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
    print("Stopped playback")
    if modem then
        pcall(function() rednet.broadcast("Stopped") end)
    end
end

-- Toggle loop mode
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        print("Looping set to: " .. tostring(isLooping))
        if modem then
            pcall(function() rednet.broadcast("Looping: " .. tostring(isLooping)) end)
        end
    end
end

-- Handle rednet messages
local function handleRednetMessages()
    while true do
        local id, message = rednet.receive()
        if message then
            print("Received rednet message: " .. message)
            local command, param = message:match("([^%s]+)%s*(.*)")
            if command == "play" and param ~= "" then
                playDFPM(param)
            elseif command == "stop" then
                stopDFPM()
            elseif command == "loop" then
                toggleLoop()
            end
        end
    end
end

-- Main function
local function main()
    parallel.waitForAny(
        handleRednetMessages
    )
end

main()

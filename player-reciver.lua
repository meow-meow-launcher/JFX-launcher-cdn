-- editeeeed
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
local isLooping = false -- Explicitly set to false by default
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
    if newUrl then
        if isPlaying and url == newUrl then
            print("Already playing this URL: " .. newUrl)
            return
        end
        url = newUrl
    end
    if url == "" or isPlaying then
        print("Cannot start playback: Already playing or no URL")
        return
    end
    isPlaying = true
    activeSpeaker = checkSpeaker()
    if not activeSpeaker then
        print("Cannot play: No speaker available")
        isPlaying = false
        return
    end

    print("Playing: " .. url)

    -- Load and play in a separate thread
    parallel.waitForAny(
        function()
            print("Attempting to load URL: " .. url)
            local handle = http.get(url, nil, true) -- Binary mode
            if not handle then
                isPlaying = false
                print("Failed to load URL: " .. url)
                return
            end

            print("URL loaded successfully")
            local chunkCount = 0
            while isPlaying do
                local chunk = handle.read(16 * 1024)
                if not chunk then
                    if isLooping then
                        print("Looping: Restarting URL: " .. url)
                        handle.close()
                        handle = http.get(url, nil, true)
                        if not handle then
                            isPlaying = false
                            print("Failed to reload URL: " .. url)
                            return
                        end
                        chunk = handle.read(16 * 1024)
                        if not chunk then
                            isPlaying = false
                            print("No data after reload: " .. url)
                            return
                        end
                    else
                        isPlaying = false
                        print("Playback ended: " .. url)
                        print("Processed " .. chunkCount .. " chunks")
                        handle.close()
                        return
                    end
                end

                local buffer = decoder(chunk)
                chunkCount = chunkCount + 1
                activeSpeaker = checkSpeaker() -- Check for hot-swap
                if activeSpeaker then
                    print("Playing chunk " .. chunkCount)
                    local waitCount = 0
                    while not activeSpeaker.playAudio(buffer) do
                        waitCount = waitCount + 1
                        print("Waiting for speaker to be ready (attempt " .. waitCount .. ") for chunk " .. chunkCount)
                        os.pullEvent("speaker_audio_empty")
                    end
                end
                -- Check for stop command during playback
                if not isPlaying then
                    if activeSpeaker then
                        pcall(function() activeSpeaker.stopAudio() end) -- Stop current audio
                    end
                    break
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

-- Stop playback and reboot
local function stopDFPM()
    if not isPlaying then
        print("Already stopped")
    else
        isPlaying = false
        print("Stopping playback immediately")
        if activeSpeaker then
            pcall(function() activeSpeaker.stopAudio() end) -- Attempt to stop audio immediately
        end
    end
    print("Rebooting receiver...")
    os.reboot()
end

-- Toggle loop mode
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        print("Looping set to: " .. tostring(isLooping))
        if modem then
            pcall(function() rednet.broadcast("loop") end)
        end
    else
        print("Cannot toggle loop: Not playing")
    end
end

-- Handle rednet messages
local function handleRednetMessages()
    while true do
        local id, message = rednet.receive()
        if message then
            print("Received rednet message: " .. tostring(message))
            local command, param = message:match("([^%s]+)%s*(.*)")
            print("Parsed command: " .. tostring(command) .. ", param: " .. tostring(param))
            if command == "play" and param ~= "" then
                playDFPM(param)
            elseif command == "stop" then
                stopDFPM()
            elseif command == "loop" then
                toggleLoop()
            else
                print("Unknown command: " .. tostring(command))
            end
        else
            print("Received nil message")
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

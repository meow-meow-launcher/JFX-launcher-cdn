-- falix mrazi
-- Initialize peripherals
local function initializePeripherals()
    local modem = peripheral.find("modem")

    -- Debug peripheral list
    print("Available peripherals: " .. table.concat(peripheral.getNames(), ", "))
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
            return nil, nil
        end
    else
        print("No modem detected")
        return nil, nil
    end

    return modem
end

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false -- Explicitly set to false by default
local url = ""
local activeSpeakers = {} -- List of active speakers

-- Initialize peripherals
local modem = initializePeripherals()
if not modem then
    print("Initialization failed: No modem found")
    return
end

-- Find available speakers
local function findSpeakers()
    local speakers = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "speaker" then
            table.insert(speakers, peripheral.wrap(side))
            print("Found speaker on: " .. side)
        end
    end
    return speakers
end

-- Update active speakers list (supports hot-swap)
local function updateSpeakers()
    activeSpeakers = findSpeakers()
    if #activeSpeakers == 0 then
        print("Warning: No speakers available, audio disabled")
        return false
    end
    print("Updated speakers list: " .. #activeSpeakers .. " speakers active")
    if modem then
        pcall(function() rednet.broadcast("Updated to " .. #activeSpeakers .. " speakers") end)
    end
    return true
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

    -- Update speakers list before playing
    if not updateSpeakers() then
        print("Cannot play: No speakers available")
        return
    end

    isPlaying = true
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
                -- Update speakers list (hot-swap support)
                if not updateSpeakers() then
                    isPlaying = false
                    print("Playback stopped: No speakers available")
                    return
                end

                -- Play on all speakers
                for _, speaker in ipairs(activeSpeakers) do
                    print("Playing chunk " .. chunkCount .. " on speaker: " .. peripheral.getName(speaker))
                    local waitCount = 0
                    while not speaker.playAudio(buffer) do
                        waitCount = waitCount + 1
                        print("Waiting for speaker " .. peripheral.getName(speaker) .. " to be ready (attempt " .. waitCount .. ") for chunk " .. chunkCount)
                        os.pullEvent("speaker_audio_empty")
                    end
                end

                -- Check for stop command during playback
                if not isPlaying then
                    for _, speaker in ipairs(activeSpeakers) do
                        pcall(function() speaker.stopAudio() end) -- Stop current audio
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
        for _, speaker in ipairs(activeSpeakers) do
            pcall(function() speaker.stopAudio() end) -- Attempt to stop audio immediately
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
    -- Initial speaker discovery
    updateSpeakers()
    if #activeSpeakers == 0 then
        print("No speakers found at startup, waiting for commands...")
    end

    parallel.waitForAny(
        handleRednetMessages
    )
end

main()

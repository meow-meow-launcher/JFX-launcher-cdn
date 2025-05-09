-- Firmware version
local FIRMWARE_VERSION = "1.1.0"
print("Speaker Receiver Firmware v" .. FIRMWARE_VERSION)

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false
local url = ""
local activeSpeakers = {}
local stopRequested = false

-- Initialize peripherals
local function initializePeripherals()
    local modem = peripheral.find("modem")
    print("Available peripherals: " .. table.concat(peripheral.getNames(), ", "))
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        if peripheral.getType(modemSide) == "modem" then
            rednet.open(modemSide)
            print("Rednet opened on: " .. modemSide)
            pcall(function() rednet.broadcast("Receiver ready") end)
        else
            print("Peripheral is not a modem")
            return nil
        end
    else
        print("No modem detected")
        return nil
    end
    return modem
end

local modem = initializePeripherals()
if not modem then return end

-- Speaker discovery
local function findSpeakers()
    local speakers = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "speaker" then
            table.insert(speakers, peripheral.wrap(side))
            print("Found speaker: " .. side)
        end
    end
    return speakers
end

local function updateSpeakers()
    activeSpeakers = findSpeakers()
    if #activeSpeakers == 0 then
        print("Warning: No speakers found")
        return false
    end
    print("Speakers updated: " .. #activeSpeakers)
    pcall(function() rednet.broadcast("Updated to " .. #activeSpeakers .. " speakers") end)
    return true
end

-- Stop playback cleanly
local function stopPlayback()
    if isPlaying then
        print("Stopping playback immediately")
        stopRequested = true
        for _, speaker in ipairs(activeSpeakers) do
            pcall(function() speaker.stopAudio() end)
        end
    else
        print("Not playing")
    end
end

-- Toggle loop
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        print("Looping: " .. tostring(isLooping))
        pcall(function() rednet.broadcast("loop") end)
    else
        print("Can't toggle loop: Not playing")
    end
end

-- Main playback function
local function playDFPM(newUrl)
    if newUrl then
        if isPlaying and url == newUrl then
            print("Already playing this URL")
            return
        end
        url = newUrl
    end
    if url == "" or isPlaying then
        print("Cannot play: Already playing or no URL")
        return
    end

    if not updateSpeakers() then return end

    isPlaying = true
    stopRequested = false
    print("Starting playback: " .. url)

    parallel.waitForAny(
        function()
            local handle = http.get(url, nil, true)
            if not handle then
                print("Failed to fetch: " .. url)
                isPlaying = false
                return
            end

            local chunkCount = 0
            while not stopRequested do
                local chunk = handle.read(16 * 1024)
                if not chunk then
                    if isLooping then
                        print("Looping: restarting")
                        handle.close()
                        handle = http.get(url, nil, true)
                        if not handle then break end
                        chunk = handle.read(16 * 1024)
                        if not chunk then break end
                    else
                        print("Playback complete")
                        break
                    end
                end

                local buffer = decoder(chunk)
                chunkCount = chunkCount + 1

                if not updateSpeakers() then break end

                -- Distribute chunks by index
                local speakerIndex = ((chunkCount - 1) % #activeSpeakers) + 1
                local speaker = activeSpeakers[speakerIndex]
                print("Chunk " .. chunkCount .. " → speaker: " .. peripheral.getName(speaker))

                local waitCount = 0
                while not speaker.playAudio(buffer) and not stopRequested do
                    waitCount = waitCount + 1
                    print("Waiting speaker ready: attempt " .. waitCount)
                    os.pullEvent("speaker_audio_empty")
                end

                if stopRequested then break end
            end

            handle.close()
            isPlaying = false
            stopRequested = false
        end,

        function()
            while isPlaying and not stopRequested do
                os.pullEvent("speaker_audio_empty")
            end
        end
    )
end

-- Message handling
local function handleMessages()
    while true do
        local id, message = rednet.receive()
        if message then
            print("Rednet msg: " .. tostring(message))
            local cmd, param = message:match("([^%s]+)%s*(.*)")
            if cmd == "play" and param ~= "" then
                playDFPM(param)
            elseif cmd == "stop" then
                stopPlayback()
            elseif cmd == "loop" then
                toggleLoop()
            else
                print("Unknown command: " .. tostring(cmd))
            end
        end
    end
end

-- Main
local function main()
    updateSpeakers()
    parallel.waitForAny(handleMessages)
end

main()

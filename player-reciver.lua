-- Speaker Receiver Firmware v1.1.1

local FIRMWARE_VERSION = "1.1.1"

-- Debug print
print("Speaker Receiver Firmware v" .. FIRMWARE_VERSION)

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player state
local isPlaying = false
local isLooping = false
local url = ""
local activeSpeakers = {}

-- Initialize modem
local function initializePeripherals()
    local modem = peripheral.find("modem")
    print("Available peripherals: " .. table.concat(peripheral.getNames(), ", "))
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        rednet.open(modemSide)
        print("Rednet opened on: " .. modemSide)
        return modem
    else
        print("No modem found")
        return nil
    end
end

local modem = initializePeripherals()
if not modem then return end

-- Find speakers
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

-- Update speaker list
local function updateSpeakers()
    activeSpeakers = findSpeakers()
    print("Speakers updated: " .. #activeSpeakers)
    return #activeSpeakers > 0
end

-- Play DFPWM
local function playDFPM(newUrl)
    if newUrl then
        if isPlaying and url == newUrl then return end
        url = newUrl
    end
    if url == "" or isPlaying then return end

    if not updateSpeakers() then
        print("No speakers available")
        return
    end

    isPlaying = true
    print("Streaming from: " .. url)

    parallel.waitForAny(
        function()
            local handle = http.get(url, nil, true)
            if not handle then
                isPlaying = false
                print("Failed to open URL")
                return
            end

            local chunkCount = 0
            while isPlaying do
                local chunk = handle.read(4 * 1024)  -- УМЕНЬШЕННЫЙ ЧАНК (~4КБ)
                if not chunk then
                    if isLooping then
                        print("Looping audio...")
                        handle.close()
                        handle = http.get(url, nil, true)
                        if not handle then break end
                        chunk = handle.read(4 * 1024)
                        if not chunk then break end
                    else
                        break
                    end
                end

                local buffer = decoder(chunk)

                -- YIELD: чтобы избежать "Too long without yielding"
                os.queueEvent("dfpwm_yield")
                os.pullEvent("dfpwm_yield")

                if not updateSpeakers() then
                    isPlaying = false
                    return
                end

                for _, speaker in ipairs(activeSpeakers) do
                    while not speaker.playAudio(buffer) do
                        os.pullEvent("speaker_audio_empty")
                    end
                end

                chunkCount = chunkCount + 1
            end
            handle.close()
            isPlaying = false
            print("Playback complete. Chunks: " .. chunkCount)
        end,
        function()
            while isPlaying do
                os.pullEvent("speaker_audio_empty")
            end
        end
    )
end

-- Stop audio
local function stopDFPM()
    if isPlaying then
        isPlaying = false
        print("Stopping playback")
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
    else
        print("Can't toggle loop: not playing")
    end
end

-- Rednet handler
local function handleRednetMessages()
    while true do
        local _, msg = rednet.receive()
        if type(msg) ~= "string" then goto continue end

        local cmd, param = msg:match("([^%s]+)%s*(.*)")
        if cmd == "play" and param and param ~= "" then
            playDFPM(param)
        elseif cmd == "stop" then
            stopDFPM()
        elseif cmd == "loop" then
            toggleLoop()
        elseif cmd == "version" then
            rednet.broadcast("Firmware v" .. FIRMWARE_VERSION)
        else
            print("Unknown command: " .. tostring(cmd))
        end
        ::continue::
    end
end

-- Main
local function main()
    updateSpeakers()
    parallel.waitForAny(handleRednetMessages)
end

main()

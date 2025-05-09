-- Speaker Receiver Firmware v1.2.0

-- Load modules
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- State
local modem = peripheral.find("modem")
local isPlaying = false
local isLooping = false
local activeSpeakers = {}
local audioURL = ""

-- Show firmware info
print("Speaker Receiver Firmware v1.2.0")

-- Open modem
if modem then
    local name = peripheral.getName(modem)
    rednet.open(name)
    print("RedNet opened on: " .. name)
else
    print("No modem found!")
    return
end

-- Detect speakers
local function updateSpeakers()
    activeSpeakers = {}
    for _, side in ipairs(peripheral.getNames()) do
        if peripheral.getType(side) == "speaker" then
            table.insert(activeSpeakers, peripheral.wrap(side))
            print("Found speaker: " .. side)
        end
    end
    print("Speakers updated: " .. tostring(#activeSpeakers))
end

-- Play buffer to one speaker
local function speakerWorker(speaker, bufferQueue)
    while isPlaying do
        local buffer = table.remove(bufferQueue, 1)
        if buffer then
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
        else
            os.pullEvent("speaker_audio_empty")
        end
    end
end

-- Main playback logic
local function playDFPWM(url)
    if isPlaying then
        print("Already playing")
        return
    end
    if url == "" then
        print("Empty URL")
        return
    end

    audioURL = url
    isPlaying = true
    updateSpeakers()

    print("Streaming from: " .. url)
    while isPlaying do
        local h = http.get(audioURL, nil, true)
        if not h then
            print("Failed to load: " .. audioURL)
            isPlaying = false
            return
        end

        local bufferQueue = {}
        local coroutines = {}

        for _, speaker in ipairs(activeSpeakers) do
            table.insert(coroutines, function()
                speakerWorker(speaker, bufferQueue)
            end)
        end

        -- Decoder loop
        local reader = function()
            while isPlaying do
                local chunk = h.read(16 * 1024)
                if not chunk then
                    break
                end
                local decoded = decoder(chunk)
                table.insert(bufferQueue, decoded)
                os.queueEvent("audio_chunk") -- Yield
                os.pullEvent("audio_chunk")
            end
        end

        table.insert(coroutines, reader)
        parallel.waitForAll(table.unpack(coroutines))
        h.close()

        if not isLooping then
            isPlaying = false
            print("Playback finished")
            break
        else
            print("Looping track...")
        end
    end
end

-- Stop playback
local function stopPlayback()
    if not isPlaying then
        print("Not playing")
        return
    end
    isPlaying = false
    print("Playback stopped")
end

-- Toggle loop
local function toggleLoop()
    isLooping = not isLooping
    print("Loop mode: " .. tostring(isLooping))
end

-- Handle rednet commands
local function listenCommands()
    while true do
        local _, msg = rednet.receive()
        if type(msg) == "string" then
            local cmd, arg = msg:match("([^%s]+)%s*(.*)")
            if cmd == "play" and arg and arg ~= "" then
                playDFPWM(arg)
            elseif cmd == "stop" then
                stopPlayback()
            elseif cmd == "loop" then
                toggleLoop()
            else
                print("Unknown command: " .. msg)
            end
        end
    end
end

-- Init
updateSpeakers()
listenCommands()

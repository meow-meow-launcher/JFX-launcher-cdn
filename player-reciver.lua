-- Speaker Receiver Firmware v1.3.0

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

local modem = peripheral.find("modem")
local isPlaying, isLooping, stopFlag = false, false, false
local activeSpeakers = {}
local audioURL = ""

print("Speaker Receiver Firmware v1.3.0")

if modem then
    local name = peripheral.getName(modem)
    rednet.open(name)
    print("RedNet opened on: " .. name)
else
    print("No modem found!")
    return
end

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

local function playDFPWM(url)
    if isPlaying then return end
    if url == "" then return end

    audioURL = url
    isPlaying = true
    stopFlag = false
    updateSpeakers()
    print("Streaming from: " .. url)

    repeat
        local h = http.get(audioURL, nil, true)
        if not h then break end

        local bufferQueue, coroutines = {}, {}
        for _, speaker in ipairs(activeSpeakers) do
            table.insert(coroutines, function()
                speakerWorker(speaker, bufferQueue)
            end)
        end
        table.insert(coroutines, function()
            while not stopFlag do
                local chunk = h.read(16 * 1024)
                if not chunk then break end
                local decoded = decoder(chunk)
                table.insert(bufferQueue, decoded)
                os.queueEvent("audio_chunk")
                os.pullEvent("audio_chunk")
            end
            h.close()
        end)
        parallel.waitForAll(table.unpack(coroutines))
        if not isLooping then break end
        print("Looping...")
    until stopFlag

    isPlaying = false
    stopFlag = false
    print("Playback finished")
end

local function stopPlayback()
    if isPlaying then
        stopFlag = true
        print("Stopping...")
    end
end

local function toggleLoop()
    isLooping = not isLooping
    print("Loop mode: " .. tostring(isLooping))
end

local function updateFromURL(url)
    print("Updating from: " .. url)
    local h = http.get(url)
    if not h then
        print("Failed to fetch update")
        return
    end
    local content = h.readAll()
    h.close()

    local f = fs.open("receiver.lua", "w")
    f.write(content)
    f.close()
    print("Update complete. Rebooting...")
    sleep(1)
    shell.run("receiver.lua")
end

local function listenCommands()
    while true do
        local _, msg = rednet.receive()
        if type(msg) ~= "string" then goto continue end
        local cmd, arg = msg:match("([^%s]+)%s*(.*)")
        if cmd == "play" and arg ~= "" then
            stopPlayback()
            sleep(0.2)
            playDFPWM(arg)
        elseif cmd == "stop" then
            stopPlayback()
        elseif cmd == "loop" then
            toggleLoop()
        elseif cmd == "update" and arg ~= "" then
            updateFromURL(arg)
        else
            print("Unknown command: " .. msg)
        end
        ::continue::
    end
end

updateSpeakers()
listenCommands()

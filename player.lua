-- Require Basalt
local basalt = require("basalt")

-- Initialize peripherals
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

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false
local url = ""
local activeSpeaker = speaker

-- Get URL from command-line arguments
local args = {...}
if #args > 0 then
    url = args[1]
end

-- Initialize rednet for modem (wireless or Ender)
local function initializeModem()
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Detected modem on side: " .. modemSide)
        if peripheral.getType(modemSide) == "modem" then
            rednet.open(modemSide)
            print("Attempting to open rednet on: " .. modemSide)
            -- Test broadcast to confirm modem functionality
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
end

-- Create main Basalt frame
local mainFrame
if monitor then
    monitor.setTextScale(0.5)
    mainFrame = basalt.createFrame("mainFrame", monitor)
else
    mainFrame = basalt.createFrame("mainFrame")
end

-- Create interface elements
local urlLabel = mainFrame:addLabel()
    :setText("URL: ")
    :setPosition(2, 2)
    :setForeground(colors.white)

local urlInput = mainFrame:addInput()
    :setPosition(7, 2)
    :setSize(20, 1)
    :setDefaultText(url)
    :setForeground(colors.white)

local playButton = mainFrame:addButton()
    :setText("Play")
    :setPosition(2, 4)
    :setSize(6, 1)
    :setBackground(isPlaying and colors.green or colors.gray)

local stopButton = mainFrame:addButton()
    :setText("Stop")
    :setPosition(10, 4)
    :setSize(6, 1)
    :setBackground(not isPlaying and colors.red or colors.gray)

local loopButton = mainFrame:addButton()
    :setText("Loop")
    :setPosition(18, 4)
    :setSize(6, 1)
    :setBackground(isLooping and isPlaying and colors.yellow or colors.gray)

local overrideButton = mainFrame:addButton()
    :setText("Override")
    :setPosition(26, 4)
    :setSize(8, 1)
    :setBackground(colors.gray)

-- Update interface
local function updateInterface()
    playButton:setBackground(isPlaying and colors.green or colors.gray)
    stopButton:setBackground(not isPlaying and colors.red or colors.gray)
    loopButton:setBackground(isLooping and isPlaying and colors.yellow or colors.gray)
    overrideButton:setBackground(colors.gray)
end

-- Update URL from input field
urlInput:onChange(function(self)
    url = self:getValue()
end)

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

-- Handle events
playButton:onClick(function()
    playDFPM()
end)

stopButton:onClick(function()
    stopDFPM()
end)

loopButton:onClick(function()
    toggleLoop()
end)

overrideButton:onClick(function()
    overrideSpeaker()
end)

-- Main function
local function main()
    initializeModem() -- Initialize modem at startup
    updateInterface()
    basalt.autoUpdate()
end

main()

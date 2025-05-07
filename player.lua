-- Require Basalt
local basalt = require("basalt")

-- Initialize peripherals
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
if not speaker then
    error("Speaker not found")
end

-- DFPM module
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Player states
local isPlaying = false
local isLooping = false
local url = ""

-- Get URL from command-line arguments
local args = {...}
if #args > 0 then
    url = args[1]
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

-- Update interface and force redraw
local function updateInterface()
    playButton:setBackground(isPlaying and colors.green or colors.gray)
    stopButton:setBackground(not isPlaying and colors.red or colors.gray)
    loopButton:setBackground(isLooping and isPlaying and colors.yellow or colors.gray)

    -- Force redraw of buttons
    playButton:update()
    stopButton:update()
    loopButton:update()
    mainFrame:update()
end

-- Update URL from input field
urlInput:onChange(function(self)
    url = self:getValue()
end)

-- Play DFPM
local function playDFPM()
    if url == "" or isPlaying then return end
    isPlaying = true
    updateInterface()

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
                while not speaker.playAudio(buffer) do
                    os.pullEvent("speaker_audio_empty")
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
end

-- Toggle loop mode
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        updateInterface()
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

-- Main function
local function main()
    updateInterface()
    basalt.autoUpdate()
end

main()

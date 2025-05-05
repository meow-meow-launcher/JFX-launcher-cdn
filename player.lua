local basalt = dofile("/basalt.lua")
local dfpwm = require("cc.audio.dfpwm")

local args = { ... }
local audioUrl = args[1]

local main = basalt.createFrame()
main:setBackground(colors.black)

-- Состояния
local isLooping = false
local isPlaying = false
local playThread = nil

-- UI элементы
main:addLabel()
    :setText("Audio Player")
    :setPosition(2, 1)
    :setForeground(colors.white)

main:addLabel()
    :setText("URL: " .. (audioUrl or "не задан"))
    :setPosition(2, 3)
    :setForeground(colors.white)

local loopButton = main:addButton()
    :setText("Loop")
    :setPosition(2, 5)
    :setSize(8, 3)
    :setBackground(colors.gray)

local playButton = main:addButton()
    :setText("Play")
    :setPosition(12, 5)
    :setSize(8, 3)
    :setBackground(colors.gray)

local stopButton = main:addButton()
    :setText("Stop")
    :setPosition(22, 5)
    :setSize(8, 3)
    :setBackground(colors.gray)

-- Обновление цвета кнопок
local function updateButtonStates()
    loopButton:setBackground(isLooping and colors.orange or colors.gray)
    playButton:setBackground(isPlaying and colors.green or colors.gray)
    stopButton:setBackground(isPlaying and colors.red or colors.gray)
end

-- Воспроизведение
local function playAudio(url)
    local decoder = dfpwm.make_decoder()

    repeat
        local speakers = { peripheral.find("speaker") }
        if #speakers == 0 then
            print("No speakers found.")
            break
        end

        local res, err = http.get({ url = url, binary = true })
        if not res then
            print("Download failed: " .. (err or "unknown"))
            break
        end

        while true do
            local chunk = res.read(16 * 1024)
            if not chunk or not isPlaying then break end

            local buffer = decoder(chunk)
            for _, spk in ipairs(speakers) do
                while not spk.playAudio(buffer) do
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end

        res.close()
    until not isLooping or not isPlaying

    isPlaying = false
    updateButtonStates()
end

-- Кнопка Loop
loopButton:onClick(function()
    isLooping = not isLooping
    updateButtonStates()
end)

-- Кнопка Play
playButton:onClick(function()
    if isPlaying or not audioUrl then return end
    isPlaying = true
    updateButtonStates()
    playThread = function() playAudio(audioUrl) end
    parallel.waitForAny(playThread, function() while isPlaying do os.sleep(0.1) end end)
end)

-- Кнопка Stop
stopButton:onClick(function()
    if isPlaying then
        isPlaying = false
        updateButtonStates()
    end
end)

updateButtonStates()
basalt.autoUpdate()

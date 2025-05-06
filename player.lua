-- Требуем Basalt
local basalt = require("basalt")

-- Инициализация периферий
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
if not speaker then
    error("Динамик не найден")
end

-- Модуль для DFPM
local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

-- Состояния плеера
local isPlaying = false
local isLooping = false
local url = ""

-- Получение URL из аргументов командной строки
local args = {...}
if #args > 0 then
    url = args[1]
end

-- Создание главного фрейма Basalt
local mainFrame
if monitor then
    monitor.setTextScale(0.5)
    mainFrame = basalt.createFrame("mainFrame", monitor)
else
    mainFrame = basalt.createFrame("mainFrame")
end

-- Создание элементов интерфейса
local urlField = mainFrame:addLabel()
    :setText("URL: " .. url)
    :setPosition(2, 2)
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

-- Обновление интерфейса
local function updateInterface()
    urlField:setText("URL: " .. url)
    playButton:setBackground(isPlaying and colors.green or colors.gray)
    stopButton:setBackground(not isPlaying and colors.red or colors.gray)
    loopButton:setBackground(isLooping and isPlaying and colors.yellow or colors.gray)
end

-- Обработка ввода URL
local function inputURL()
    basalt.stopUpdate()
    term.setCursorPos(6, 2)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    url = read()
    updateInterface()
    basalt.startUpdate()
end

-- Воспроизведение DFPM
local function playDFPM()
    if url == "" or isPlaying then return end
    isPlaying = true
    updateInterface()

    -- Загрузка и воспроизведение в отдельном потоке
    parallel.waitForAny(
        function()
            local handle = http.get(url, nil, true) -- Бинарный режим
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

-- Остановка воспроизведения
local function stopDFPM()
    isPlaying = false
    updateInterface()
end

-- Переключение режима повтора
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        updateInterface()
    end
end

-- Обработка событий
urlField:onClick(function()
    inputURL()
end)

playButton:onClick(function()
    playDFPM()
end)

stopButton:onClick(function()
    stopDFPM()
end)

loopButton:onClick(function()
    toggleLoop()
end)

-- Основной цикл
local function main()
    updateInterface()
    basalt.run()
end

main()

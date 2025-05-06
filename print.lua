-- Инициализация периферий
local monitor = peripheral.find("monitor")
local term = term -- Терминал компьютера
if monitor then
    monitor.setTextScale(0.5)
end

-- Состояния плеера
local isPlaying = false
local isLooping = false
local url = ""

-- Получение URL из аргументов командной строки
local args = {...}
if #args > 0 then
    url = args[1]
end

-- Цвета
local colors = {
    green = colors.green,
    yellow = colors.yellow,
    red = colors.red,
    gray = colors.gray,
    white = colors.white,
    black = colors.black
}

-- Отрисовка интерфейса на указанном устройстве
local function drawInterface(device)
    device.clear()
    device.setCursorPos(1, 1)
    
    -- Поле URL
    device.setTextColor(colors.white)
    device.write("URL: " .. url)
    
    -- Кнопки
    local buttonY = 3
    device.setCursorPos(2, buttonY)
    
    -- Кнопка Play
    if isPlaying then
        device.setBackgroundColor(colors.green)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Play ")
    
    -- Кнопка Stop
    device.setCursorPos(10, buttonY)
    if not isPlaying then
        device.setBackgroundColor(colors.red)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Stop ")
    
    -- Кнопка Loop
    device.setCursorPos(18, buttonY)
    if isLooping and isPlaying then
        device.setBackgroundColor(colors.yellow)
    else
        device.setBackgroundColor(colors.gray)
    end
    device.write(" Loop ")
    
    device.setBackgroundColor(colors.black)
end

-- Обновление интерфейса на всех устройствах
local function updateInterface()
    drawInterface(term)
    if monitor then
        drawInterface(monitor)
    end
end

-- Обработка ввода URL
local function inputURL(device)
    device.setCursorPos(6, 1)
    device.setTextColor(colors.white)
    device.setBackgroundColor(colors.black)
    url = read()
    updateInterface()
end

-- Воспроизведение DFPM
local function playDFPM()
    if url ~= "" then
        isPlaying = true
        -- Здесь должен быть код для воспроизведения DFPM
        updateInterface()
    end
end

-- Остановка воспроизведения
local function stopDFPM()
    isPlaying = false
    -- Здесь должен быть код для остановки воспроизведения
    updateInterface()
end

-- Переключение режима повтора
local function toggleLoop()
    if isPlaying then
        isLooping = not isLooping
        updateInterface()
    end
end

-- Обработка событий кликов
local function handleInput()
    while true do
        local event, param1, x, y = os.pullEvent()
        
        if event == "monitor_touch" and monitor then
            if y == 3 then
                if x >= 2 and x <= 7 then -- Play
                    playDFPM()
                elseif x >= 10 and x <= 15 then -- Stop
                    stopDFPM()
                elseif x >= 18 and x <= 23 then -- Loop
                    toggleLoop()
                end
            elseif y == 1 then -- URL input
                inputURL(monitor)
            end
        elseif event == "mouse_click" then
            if y == 3 then
                if x >= 2 and x <= 7 then -- Play
                    playDFPM()
                elseif x >= 10 and x <= 15 then -- Stop
                    stopDFPM()
                elseif x >= 18 and x <= 23 then -- Loop
                    toggleLoop()
                end
            elseif y == 1 then -- URL input
                inputURL(term)
            end
        end
    end
end

-- Основной цикл
local function main()
    updateInterface()
    handleInput()
end

main()

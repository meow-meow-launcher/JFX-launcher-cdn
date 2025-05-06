local basalt = require("basalt")
local speaker = peripheral.find("speaker")

-- Создаём основной фрейм
local main = basalt.createFrame()

-- Добавляем элементы интерфейса (только статус и кнопку)
local statusLabel = main:addLabel()
statusLabel:setPosition(2, 2)
statusLabel:setText("Status: Idle")

local startButton = main:addButton()
startButton:setPosition(2, 4)
startButton:setSize(18, 1)
startButton:setText("Start mining")

-- Список ненужных предметов
local trashItems = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:granite"] = true
}

-- Функция установки статуса с звуковой индикацией
local function setStatus(text)
    if statusLabel then
        statusLabel:setText("Status: " .. text)
    else
        print("Status: " .. text)
    end
    if speaker then
        if text:find("Mining started") then
            speaker.playSound("pling", 1.0, 0.5) -- Начало копания
        elseif text:find("Bedrock") then
            speaker.playSound("note.bass", 0.8, 0.3) -- Обнаружена bedrock
        elseif text:find("Returning") then
            speaker.playSound("note.harp", 1.2, 0.4) -- Возвращение
        elseif text:find("Returned to start") then
            speaker.playSound("note.pling", 1.5, 0.5) -- Вернулась
        elseif text:find("Code executed") then
            speaker.playSound("note.bell", 1.0, 0.6) -- Код выполнен
        end
    end
end

-- Функция сброса мусора
local function dropTrash()
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item and trashItems[item.name] then
            turtle.drop()
        end
    end
end

-- Функция возвращения в стартовую позицию
local function returnToStart(x, y, z, dir)
    setStatus("Returning")
    
    -- Поднимаемся на нужную высоту
    for i = 1, y do turtle.up() end
    
    -- Корректируем направление
    if dir == "right" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end
    
    -- Двигаемся по X
    for i = 1, math.abs(x) do
        turtle.forward()
    end
    
    -- Корректируем направление обратно
    if dir == "right" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end
    
    -- Двигаемся по Z
    for i = 1, math.abs(z) do
        turtle.forward()
    end
    
    -- Опускаемся вниз
    for i = 1, y do turtle.down() end
    
    setStatus("Returned to start")
end

-- Функция копания
local function digArea(width, length, height)
    setStatus("Mining started")
    local x, z, y = 0, 0, 0
    local direction = "right"

    for h = 1, height do
        for l = 1, length do
            for w = 1, width - 1 do
                if turtle.detect() then
                    turtle.dig()
                end
                turtle.forward()
                if direction == "right" then x = x + 1 else x = x - 1 end
            end

            if l < length then
                if l % 2 == 1 then
                    turtle.turnRight()
                    if turtle.detect() then turtle.dig() end
                    turtle.forward()
                    turtle.turnRight()
                    direction = "left"
                    z = z + 1
                else
                    turtle.turnLeft()
                    if turtle.detect() then turtle.dig() end
                    turtle.forward()
                    turtle.turnLeft()
                    direction = "right"
                    z = z + 1
                end
            end
        end

        if h < height then
            if turtle.detectDown() then turtle.digDown() end
            if not turtle.down() then
                setStatus("Bedrock! Returning")
                returnToStart(x, y, z, direction)
                return
            end
            y = y + 1
        end
    end

    dropTrash()
    returnToStart(x, y, z, direction)
    setStatus("Code executed")
end

-- Обработчик клика по кнопке
startButton:onClick(function()
    -- Запрашиваем значения через консоль
    setStatus("Enter values in console")
    print("Enter Width:")
    local w = tonumber(io.read()) or 0
    print("Enter Length:")
    local l = tonumber(io.read()) or 0
    print("Enter Height:")
    local h = tonumber(io.read()) or 0
    
    -- Проверяем, что значения корректны
    if not w or not l or not h or w <= 0 or l <= 0 or h <= 0 then
        setStatus("Invalid input: values must be greater than 0, got w=" .. tostring(w) .. ", l=" .. tostring(l) .. ", h=" .. tostring(h))
        return
    end

    setStatus("Started mining " .. w .. "x" .. l .. "x" .. h)
    digArea(w, l, h)
end)

-- Автообновление интерфейса
basalt.autoUpdate()

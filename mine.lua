local basalt = require("basalt")
local speaker = peripheral.find("speaker")

local main = basalt.createFrame()
local widthInput = main:addTextfield():setPosition(2, 2):setSize(10, 1):setText("5")
main:addLabel():setPosition(14, 2):setText("Ширина")

local lengthInput = main:addTextfield():setPosition(2, 4):setSize(10, 1):setText("5")
main:addLabel():setPosition(14, 4):setText("Длина")

local heightInput = main:addTextfield():setPosition(2, 6):setSize(10, 1):setText("Высота")

local stateLabel = main:addLabel():setPosition(2, 9):setText("Состояние: Ожидание")

local startBtn = main:addButton():setPosition(2, 8):setSize(12, 1):setText("Начать копать")

local trashList = { "minecraft:cobblestone", "minecraft:dirt" }

local function isTrash(item)
    for _, name in ipairs(trashList) do
        if item.name == name then return true end
    end
    return false
end

local function sayStatus(text)
    stateLabel:setText("Состояние: " .. text)
    if speaker then
        speaker.speak(text)
    end
end

local function dropTrash()
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item and isTrash(item) then
            turtle.drop()
        end
    end
end

local function returnToStart(x, y, z, facing)
    sayStatus("Возвращаюсь")

    -- Возвращаемся по Z
    for i = 1, math.abs(z) do
        if z > 0 then
            turtle.back()
        else
            turtle.forward()
        end
    end

    -- Поворачиваем к X
    if facing == "right" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end

    -- Возвращаемся по X
    for i = 1, math.abs(x) do
        turtle.forward()
    end

    -- Возвращаемся по Y (вверх)
    for i = 1, y do
        turtle.up()
    end

    sayStatus("Готово")
end

local function digArea(width, length, height)
    sayStatus("Начинаю работу")
    local facing = "right"
    local startX, startY, startZ = 0, 0, 0
    local x, z = 0, 0

    for h = 1, height do
        for l = 1, length do
            for w = 1, width - 1 do
                turtle.dig()
                if turtle.forward() then
                    if facing == "right" then x = x + 1 else x = x - 1 end
                end
            end

            if l < length then
                if l % 2 == 1 then
                    turtle.turnRight()
                    facing = "left"
                    turtle.dig()
                    turtle.forward()
                    z = z + 1
                    turtle.turnRight()
                else
                    turtle.turnLeft()
                    facing = "right"
                    turtle.dig()
                    turtle.forward()
                    z = z + 1
                    turtle.turnLeft()
                end
            end
        end

        -- Попытка копать вниз
        if h < height then
            if turtle.detectDown() then
                turtle.digDown()
            end

            if not turtle.down() then
                sayStatus("Бедрок, остановка")
                returnToStart(x, h - 1, z, facing)
                return
            end
        end
    end

    dropTrash()
    returnToStart(x, height - 1, z, facing)
end

startBtn:onClick(function()
    local w = tonumber(widthInput:getValue())
    local l = tonumber(lengthInput:getValue())
    local h = tonumber(heightInput:getValue())
    digArea(w, l, h)
end)

basalt.autoUpdate()

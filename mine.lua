local basalt = require("basalt")
local speaker = peripheral.find("speaker")

local main = basalt.createFrame()

main:addLabel():setText("Width:"):setPosition(2, 2)
local widthInput = main:addTextfield()
widthInput:setPosition(12, 2)
widthInput:setSize(5, 1)
widthInput:setText("5")

main:addLabel():setText("Length:"):setPosition(2, 4)
local lengthInput = main:addTextfield()
lengthInput:setPosition(12, 4)
lengthInput:setSize(5, 1)
lengthInput:setText("5")

main:addLabel():setText("Height:"):setPosition(2, 6)
local heightInput = main:addTextfield()
heightInput:setPosition(12, 6)
heightInput:setSize(5, 1)
heightInput:setText("5")

local statusLabel = main:addLabel()
statusLabel:setPosition(2, 8)
statusLabel:setText("Status: Idle")

local startButton = main:addButton()
startButton:setPosition(2, 10)
startButton:setSize(18, 1)
startButton:setText("Start mining")

local trashItems = {
    ["minecraft:cobblestone"] = true,
    ["minecraft:dirt"] = true,
    ["minecraft:gravel"] = true,
    ["minecraft:granite"] = true
}

local function setStatus(text)
    statusLabel:setText("Status: " .. text)
    if speaker then speaker.speak(text) end
end

local function dropTrash()
    for i = 1, 16 do
        turtle.select(i)
        local item = turtle.getItemDetail()
        if item and trashItems[item.name] then
            turtle.drop()
        end
    end
end

local function returnToStart(x, y, z, dir)
    setStatus("Returning")

    for i = 1, y do turtle.up() end

    if dir == "right" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end

    for i = 1, math.abs(x) do turtle.forward() end

    if dir == "right" then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end

    for i = 1, math.abs(z) do turtle.forward() end

    setStatus("Done")
end

local function digArea(width, length, height)
    setStatus("Mining started")
    local x, z, y = 0, 0, 0
    local direction = "right"

    for h = 1, height do
        for l = 1, length do
            for w = 1, width - 1 do
                turtle.dig()
                turtle.forward()
                if direction == "right" then x = x + 1 else x = x - 1 end
            end

            if l < length then
                if l % 2 == 1 then
                    turtle.turnRight()
                    turtle.dig()
                    turtle.forward()
                    turtle.turnRight()
                    direction = "left"
                    z = z + 1
                else
                    turtle.turnLeft()
                    turtle.dig()
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
end

startButton:onClick(function()
    local w = tonumber(widthInput:getValue())
    local l = tonumber(lengthInput:getValue())
    local h = tonumber(heightInput:getValue())
    if not w or not l or not h then
        setStatus("Invalid input")
        return
    end
    setStatus("Started mining " .. w .. "x" .. l .. "x" .. h)
    -- Тут можешь вставить свою функцию копания
end)

basalt.autoUpdate()

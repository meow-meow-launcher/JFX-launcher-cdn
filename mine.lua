-- Mining script for CC:Tweaked turtle with pickaxe and speaker
-- Command: mine <length> <depth> <width>
-- Digs a rectangular prism, signals via speaker, manages inventory, stops at bedrock

local args = {...}
local length, depth, width
local speaker = peripheral.find("speaker")
local startY, currentY
local startX, startZ = 0, 0
local trashItems = {
    "minecraft:stone", "minecraft:cobblestone", "minecraft:dirt", "minecraft:gravel",
    "minecraft:andesite", "minecraft:diorite", "minecraft:granite", "minecraft:sand"
}
local valuableItems = {
    "minecraft:iron_ore", "minecraft:coal_ore", "minecraft:gold_ore", "minecraft:redstone_ore",
    "minecraft:diamond_ore", "minecraft:lapis_ore", "minecraft:emerald_ore", "minecraft:copper_ore",
    "minecraft:deepslate_iron_ore", "minecraft:deepslate_coal_ore", "minecraft:deepslate_gold_ore",
    "minecraft:deepslate_redstone_ore", "minecraft:deepslate_diamond_ore", "minecraft:deepslate_lapis_ore",
    "minecraft:deepslate_emerald_ore", "minecraft:deepslate_copper_ore"
}

-- Play sound via speaker
local function playSound(sound)
    if speaker then
        speaker.playSound(sound, 1.0, 1.0)
    end
end

-- Check if item is trash
local function isTrash(item)
    if not item then return false end
    for _, trash in ipairs(trashItems) do
        if item.name == trash then return true end
    end
    return false
end

-- Manage inventory: drop trash items if inventory is full
local function manageInventory()
    for slot = 1, 16 do
        local item = turtle.getItemDetail(slot)
        if item and isTrash(item) then
            turtle.select(slot)
            turtle.dropDown() -- Drop trash items downward
        end
    end
    turtle.select(1) -- Return to slot 1
end

-- Check if inventory has space
local function hasInventorySpace()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return true
        end
    end
    return false
end

-- Move forward with digging
local function tryForward()
    while turtle.detect() do
        if not turtle.dig() then
            return false -- Likely hit bedrock or unbreakable block
        end
        if not hasInventorySpace() then
            manageInventory()
        end
    end
    return turtle.forward()
end

-- Move down with digging
local function tryDown()
    print("Trying to move down, current Y: " .. currentY)
    while turtle.detectDown() do
        if not turtle.digDown() then
            print("Cannot dig down, likely bedrock.")
            playSound("minecraft:block.anvil.land") -- Signal bedrock hit
            return false
        end
        if not hasInventorySpace() then
            manageInventory()
        end
    end
    if turtle.down() then
        currentY = currentY - 1
        print("Moved down, new Y: " .. currentY)
        return true
    else
        print("Failed to move down.")
        return false
    end
end

-- Move up
local function tryUp()
    while turtle.detectUp() do
        turtle.digUp()
        if not hasInventorySpace() then
            manageInventory()
        end
    end
    if turtle.up() then
        currentY = currentY + 1
        return true
    end
    return false
end

-- Return to starting position
local function returnToStart()
    playSound("minecraft:entity.enderman.teleport") -- Signal return
    print("Returning to starting position...")
    
    -- Return to starting Y level
    while currentY < startY do
        tryUp()
    end
    while currentY > startY do
        if not turtle.down() then break end
        currentY = currentY - 1
    end
    
    -- Return to starting X, Z (0, 0 relative)
    while startX > 0 do
        turtle.back()
        startX = startX - 1
    end
    while startZ > 0 do
        turtle.turnRight()
        turtle.forward()
        turtle.turnLeft()
        startZ = startZ - 1
    end
end

-- Check and refuel if needed
local function checkFuel()
    if turtle.getFuelLevel() < (length * width * depth) + 50 then
        print("Low fuel! Refuel with at least " .. ((length * width * depth) + 50) .. " units.")
        for slot = 1, 16 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)
                turtle.refuel(1)
                if turtle.getFuelLevel() >= (length * width * depth) + 50 then
                    print("Refueled successfully.")
                    return true
                end
            end
        end
        print("Not enough fuel to proceed. Add fuel and try again.")
        return false
    end
    return true
end

-- Main mining function
local function mine()
    playSound("minecraft:block.note_block.bell") -- Signal start
    print("Starting mining operation: " .. length .. "x" .. depth .. "x" .. width)
    
    -- Initialize starting position
    startY = 0
    currentY = 0
    if not checkFuel() then return end
    
    for z = 1, width do
        for x = 1, length do
            -- Dig down to depth or bedrock
            for y = 1, depth do
                if not tryDown() then
                    print("Stopped at Y: " .. currentY .. ", returning up.")
                    while currentY < startY do
                        tryUp()
                    end
                    break
                end
            end
            
            -- Move back up to start Y
            while currentY < startY do
                tryUp()
            end
            
            -- Move to next X position
            if x < length then
                if not tryForward() then
                    print("Blocked, stopping.")
                    playSound("minecraft:block.anvil.break") -- Signal stop
                    returnToStart()
                    return
                end
                startX = startX + 1
            end
        end
        
        -- Move to next Z row
        if z < width then
            turtle.turnRight()
            if not tryForward() then
                print("Blocked, stopping.")
                playSound("minecraft:block.anvil.break") -- Signal stop
                returnToStart()
                return
            end
            turtle.turnLeft()
            startZ = startZ + 1
            startX = 0 -- Reset X for new row
        end
    end
    
    print("Mining complete.")
    returnToStart()
end

-- Validate and parse arguments
if #args ~= 3 then
    print("Usage: mine <length> <depth> <width>")
    return
end

length = tonumber(args[1])
depth = tonumber(args[2])
width = tonumber(args[3])

if not length or not depth or not width or length < 1 or depth < 1 or width < 1 then
    print("Invalid dimensions. Use positive integers.")
    return
end

-- Start mining
mine()

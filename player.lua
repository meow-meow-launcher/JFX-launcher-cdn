-- Include Basalt library
local basalt = require("basalt")

-- Find printer
local printer = peripheral.find("printer")
local printerInitialized = false

-- Create main frame
local mainFrame = basalt.createFrame()

-- Create GUI elements
local inputField = mainFrame:addInput()
    :setPosition(2, 2)
    :setSize(48, 15) -- Large input field (width: 48, height: 15) for a full page
    :setDefaultText("Enter text (use Enter for paragraphs)")

local initButton = mainFrame:addButton()
    :setPosition(2, 18)
    :setSize(14, 1)
    :setText("Initialize")

local printButton = mainFrame:addButton()
    :setPosition(18, 18)
    :setSize(14, 1)
    :setText("Print")

local statusLabel = mainFrame:addLabel()
    :setPosition(2, 20)
    :setSize(48, 1)
    :setText("Status: Waiting")

-- Function to initialize printer
local function initializePrinter()
    if printer then
        printerInitialized = true
        initButton:setText("Printer Ready")
        statusLabel:setText("Status: Printer Ready")
    else
        printer = peripheral.find("printer")
        if not printer then
            initButton:setText("Printer Not Found")
            statusLabel:setText("Status: Printer Not Found")
        end
    end
end

-- Function to print text with paragraphs
local function printText()
    if not printerInitialized then
        statusLabel:setText("Status: Initialize Printer")
        return
    end

    local textToPrint = inputField:getValue() or "Empty text"

    if not printer.newPage() then
        statusLabel:setText("Status: No Paper/Ink")
        return
    end

    printer.setPageTitle("Basalt Print")

    -- Split text into lines to handle paragraphs
    local lines = {}
    for line in textToPrint:gmatch("([^\n]*)\n?") do
        if line ~= "" then
            table.insert(lines, line)
        end
    end

    -- Print each line, respecting paragraphs
    local cursorY = 1
    for _, line in ipairs(lines) do
        printer.setCursorPos(1, cursorY)
        printer.write(line)
        cursorY = cursorY + 1
    end

    if not printer.endPage() then
        statusLabel:setText("Status: Print Error")
        return
    end

    statusLabel:setText("Status: Print Complete")
end

-- Handle button events
initButton:onClick(function()
    initializePrinter()
end)

printButton:onClick(function()
    printText()
end)

-- Run Basalt
basalt.autoUpdate()

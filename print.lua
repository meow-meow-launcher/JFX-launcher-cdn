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
    :setSize(30, 1)
    :setDefaultText("Enter text")

local initButton = mainFrame:addButton()
    :setPosition(2, 4)
    :setSize(14, 1)
    :setText("Initialize")

local printButton = mainFrame:addButton()
    :setPosition(18, 4)
    :setSize(14, 1)
    :setText("Print")

local statusLabel = mainFrame:addLabel()
    :setPosition(2, 6)
    :setSize(30, 1)
    :setText("Status: Waiting")

-- Function to initialize printer
local function initializePrinter()
    if printer then
        printerInitialized = true
        initButton:setText("Printer Ready")
        printButton:setEnabled(true)
        statusLabel:setText("Status: Printer Ready")
    else
        printer = peripheral.find("printer")
        if not printer then
            initButton:setText("Printer Not Found")
            statusLabel:setText("Status: Printer Not Found")
        end
    end
end

-- Function to print text
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
    printer.write(textToPrint)

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

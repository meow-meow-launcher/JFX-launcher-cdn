-- Include CCPrettyGUI library
local gui = require("ccprettygui")

-- Find printer
local printer = peripheral.find("printer")
local printerInitialized = false

-- Create GUI
local screen = gui.Screen()

-- Add input field
local inputField = gui.TextInput({
    x = 2,
    y = 2,
    w = 30,
    placeholder = "Enter text"
})
screen:add(inputField)

-- Add initialize button
local initButton = gui.Button({
    x = 2,
    y = 4,
    w = 14,
    text = "Initialize"
})
screen:add(initButton)

-- Add print button
local printButton = gui.Button({
    x = 18,
    y = 4,
    w = 14,
    text = "Print"
})
screen:add(printButton)

-- Add status label
local statusLabel = gui.Label({
    x = 2,
    y = 6,
    w = 30,
    text = "Status: Waiting"
})
screen:add(statusLabel)

-- Function to initialize printer
local function initializePrinter()
    if printer then
        printerInitialized = true
        initButton:setText("Printer Ready")
        printButton.active = true
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

    local textToPrint = inputField:getText() or "Empty text"

    if not printer.newPage() then
        statusLabel:setText("Status: No Paper/Ink")
        return
    end

    printer.setPageTitle("CCPrettyGUI Print")
    printer.write(textToPrint)

    if not printer.endPage() then
        statusLabel:setText("Status: Print Error")
        return
    end

    statusLabel:setText("Status: Print Complete")
end

-- Handle button clicks
initButton:onClick(function()
    initializePrinter()
end)

printButton:onClick(function()
    printText()
end)

-- Run the GUI
screen:run()

-- Include CCSimpleGUI library
local gui = require("ccsg.gui")
local text = require("ccsg.text")
local button = require("ccsg.button")
local entry = require("ccsg.entry")

-- Find printer
local printer = peripheral.find("printer")
local printerInitialized = false

-- Create GUI window
local win = gui.new({
    -- Text input field
    input = entry.new{pos={2,2}, size={30,1}, label="Enter text:"},
    -- Initialize button
    initButton = button.new{pos={2,4}, size={14,1}, label="Initialize"},
    -- Print button
    printButton = button.new{pos={18,4}, size={14,1}, label="Print", active=false},
}, {autofit=true})

-- Function to initialize printer
local function initializePrinter()
    if printer then
        printerInitialized = true
        win.widgets.initButton.label = "Printer Ready"
        win.widgets.printButton.active = true
        win:draw()
    else
        printer = peripheral.find("printer")
        if not printer then
            win.widgets.initButton.label = "Printer Not Found"
            win:draw()
        end
    end
end

-- Function to print text
local function printText()
    if not printerInitialized then
        win.widgets.initButton.label = "Initialize Printer"
        win:draw()
        return
    end

    local textToPrint = win.widgets.input.value or "Empty text"
    
    if not printer.newPage() then
        win.widgets.initButton.label = "No Paper/Ink"
        win:draw()
        return
    end

    printer.setPageTitle("CCSimpleGUI Print")
    printer.write(textToPrint)
    
    if not printer.endPage() then
        win.widgets.initButton.label = "Print Error"
        win:draw()
        return
    end

    win.widgets.initButton.label = "Print Complete"
    win:draw()
end

-- Main event loop
while true do
    local events, values = win:read()
    
    if events == "initButton" then
        initializePrinter()
    elseif events == "printButton" then
        printText()
    elseif events == "quit" then
        term.clear()
        term.setCursorPos(1,1)
        break
    end
end

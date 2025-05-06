-- Подключение библиотеки CCSimpleGUI
local gui = require("ccsg.gui")
local text = require("ccsg.text")
local button = require("ccsg.button")
local entry = require("ccsg.entry")

-- Поиск принтера
local printer = peripheral.find("printer")
local printerInitialized = false

-- Создание GUI окна
local win = gui.new({
    -- Поле ввода текста
    input = entry.new{pos={2,2}, size={30,1}, label="Введите текст:"},
    -- Кнопка инициализации принтера
    initButton = button.new{pos={2,4}, size={14,1}, label="Инициализировать"},
    -- Кнопка печати
    printButton = button.new{pos={18,4}, size={14,1}, label="Печатать"},
}, {autofit=true})

-- Функция инициализации принтера
local function initializePrinter()
    if printer then
        printerInitialized = true
        win.widgets.initButton.label = "Принтер готов"
        win.widgets.printButton.active = true
        win:draw()
    else
        printer = peripheral.find("printer")
        if not printer then
            win.widgets.initButton.label = "Принтер не найден"
            win:draw()
        end
    end
end

-- Функция печати
local function printText()
    if not printerInitialized then
        win.widgets.initButton.label = "Инициализируйте принтер"
        win:draw()
        return
    end

    local textToPrint = win.widgets.input.value or "Пустой текст"
    
    if not printer.newPage() then
        win.widgets.initButton.label = "Нет бумаги/чернил"
        win:draw()
        return
    end

    printer.setPageTitle("CC Print")
    printer.write(textToPrint)
    
    if not printer.endPage() then
        win.widgets.initButton.label = "Ошибка печати"
        win:draw()
        return
    end

    win.widgets.initButton.label = "Печать завершена"
    win:draw()
end

-- Основной цикл обработки событий
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

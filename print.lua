-- Подключение библиотеки Basalt
local basalt = require("basalt")

-- Поиск принтера
local printer = peripheral.find("printer")
local printerInitialized = false

-- Создание основного фрейма
local mainFrame = basalt.createFrame()

-- Создание элементов GUI
local inputField = mainFrame:addInput()
    :setPosition(2, 2)
    :setSize(30, 1)
    :setDefaultText("Введите текст")

local initButton = mainFrame:addButton()
    :setPosition(2, 4)
    :setSize(14, 1)
    :setText("Инициализировать")

local printButton = mainFrame:addButton()
    :setPosition(18, 4)
    :setSize(14, 1)
    :setText("Печатать")

local statusLabel = mainFrame:addLabel()
    :setPosition(2, 6)
    :setSize(30, 1)
    :setText("Статус: Ожидание")

-- Функция инициализации принтера
local function initializePrinter()
    if printer then
        printerInitialized = true
        initButton:setText("Принтер готов")
        printButton:setEnabled(true)
        statusLabel:setText("Статус: Принтер готов")
    else
        printer = peripheral.find("printer")
        if not printer then
            initButton:setText("Принтер не найден")
            statusLabel:setText("Статус: Принтер не найден")
        end
    end
end

-- Функция печати
local function printText()
    if not printerInitialized then
        statusLabel:setText("Статус: Инициализируйте принтер")
        return
    end

    local textToPrint = inputField:getValue() or "Пустой текст"

    if not printer.newPage() then
        statusLabel:setText("Статус: Нет бумаги/чернил")
        return
    end

    printer.setPageTitle("Basalt Print")
    printer.write(textToPrint)

    if not printer.endPage() then
        statusLabel:setText("Статус: Ошибка печати")
        return
    end

    statusLabel:setText("Статус: Печать завершена")
end

-- Обработка событий кнопок
initButton:onClick(function()
    initializePrinter()
end)

printButton:onClick(function()
    printText()
end)

-- Запуск Basalt
basalt.autoUpdate()

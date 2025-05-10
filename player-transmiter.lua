-- Audio Transmitter Controller
-- Управляет сетью приёмников через RedNet

local function initializePeripherals()
    local modem = peripheral.find("modem")
    if modem then
        local modemSide = peripheral.getName(modem)
        print("Обнаружен модем на стороне: " .. modemSide)
        rednet.open(modemSide)
        print("RedNet открыт на: " .. modemSide)
        return modem
    else
        print("Модем не найден")
        return nil
    end
end

local function sendCommand(command)
    local success, err = pcall(function() rednet.broadcast(command) end)
    if success then
        print("Отправлено: " .. command)
    else
        print("Ошибка при отправке: " .. tostring(err))
    end
end

local function printHelp()
    print("Доступные команды:")
    print("  play <url>   - воспроизведение DFPWM по ссылке")
    print("  stop         - остановить воспроизведение")
    print("  loop         - переключить режим повтора")
    print("  update <url> - обновить все приёмники по ссылке")
    print("  help         - показать эту справку")
    print("  exit         - выйти из трансмиттера")
end

local modem = initializePeripherals()
if not modem then return end

local args = {...}
if #args > 0 then
    if args[1] == "help" then
        printHelp()
    else
        sendCommand(table.concat(args, " "))
    end
else
    print("Трансмиттер готов. Введите 'help' для списка команд.")
    while true do
        write(">>> ")
        local input = read()
        if input == "exit" then break end
        if input == "help" then
            printHelp()
        elseif input ~= "" then
            sendCommand(input)
        end
    end
end

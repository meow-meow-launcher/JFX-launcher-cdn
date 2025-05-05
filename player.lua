local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")

local args = { ... }
local audioUrl = args[1]

local main = basalt.createFrame()
main:setBackground(colors.black)

main:addLabel()
    :setText("Audio Player")
    :setPosition(2, 1)
    :setForeground(colors.white)

main:addLabel()
    :setText("URL: " .. (audioUrl or "не задан"))
    :setPosition(2, 3)
    :setForeground(colors.white)

local statusLabel = main:addLabel()
    :setText("Status: Idle")
    :setPosition(2, 5)
    :setForeground(colors.white)

local loopCheckbox = main:addCheckbox()
    :setText("Loop")
    :setPosition(2, 7)

local playButton = main:addButton()
    :setText("Play")
    :setPosition(2, 9)

local stopButton = main:addButton()
    :setText("Stop")
    :setPosition(10, 9)

local playing = false
local loop = false

local function playAudio(url)
    local speakers = { peripheral.find("speaker") }
    if #speakers == 0 then
        statusLabel:setText("Status: No speakers found")
        return
    end

    local decoder = dfpwm.make_decoder()

    repeat
        local response, err = http.get({ url = url, binary = true })
        if not response then
            statusLabel:setText("Status: Error: " .. (err or "Unknown"))
            return
        end

        statusLabel:setText("Status: Playing")
        playing = true

        while true do
            local chunk = response.read(16 * 1024)
            if not chunk or not playing then break end
            local buffer = decoder(chunk)
            for _, speaker in ipairs(speakers) do
                while not speaker.playAudio(buffer) do
                    os.pullEvent("speaker_audio_empty")
                end
            end
        end

        response.close()
    until not loop or not playing

    statusLabel:setText("Status: Idle")
    playing = false
end

playButton:onClick(function()
    if not audioUrl then
        statusLabel:setText("Status: URL не указан")
        return
    end
    if playing then
        statusLabel:setText("Status: Already playing")
        return
    end

    loop = loopCheckbox:getValue()
    playing = true

    parallel.waitForAll(function()
        playAudio(audioUrl)
    end)
end)

stopButton:onClick(function()
    if playing then
        playing = false
        statusLabel:setText("Status: Stopped")
    else
        statusLabel:setText("Status: Not playing")
    end
end)

basalt.autoUpdate()

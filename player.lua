local basalt = dofile("/basalt.lua")
local http = require("http")
local dfpwm = require("cc.audio.dfpwm")

local main = basalt.createFrame()
main:setBackground(colors.black)

main:addLabel()
    :setText("Audio Player")
    :setPosition(2, 1)
    :setForeground(colors.white)

main:addLabel()
    :setText("URL:")
    :setPosition(2, 3)
    :setForeground(colors.white)

local urlInput = main:addInput()
    :setPosition(7, 3)
    :setSize(30, 1)

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
            statusLabel:setText("Status: Download error: " .. (err or "Unknown"))
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
    if playing then
        statusLabel:setText("Status: Already playing")
        return
    end
    local url = urlInput:getValue()
    if url == "" then
        statusLabel:setText("Status: Please enter a URL")
        return
    end
    loop = loopCheckbox:getValue()
    parallel.waitForAny(function() playAudio(url) end, function() while playing do os.sleep(0.1) end end)
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

-- Updater script
local url = "https://yourdomain.com/receiver.lua"  -- Заменить на актуальный URL

print("Fetching receiver.lua from: " .. url)
local response = http.get(url)
if not response then
    print("Failed to fetch update.")
    return
end

local data = response.readAll()
response.close()

local f = fs.open("receiver.lua", "w")
f.write(data)
f.close()

print("receiver.lua updated. Rebooting...")
sleep(1)
shell.run("receiver.lua")

-- Auto-launch receiver
if fs.exists("receiver.lua") then
    shell.run("receiver.lua")
else
    print("receiver.lua not found.")
end

--!strict
local task = require("@lune/task")
local worker = require("./Packages/_Index/that-guynamedbrian_worker@1.0.0/worker/src")
local signal = require("./src/mock")

local a = signal<<(number, string)>>(worker, task.spawn)
local b = a:Once(function(a0: number)  
    print(a0)
end)
b:Disconnect()
a:Connect(function(a0: number)  end)
print(a)
a:Fire(344)
print(a)
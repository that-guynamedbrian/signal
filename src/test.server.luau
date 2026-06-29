--!strict
const RunService = game:GetService("RunService")

const signal = require("@game/ReplicatedStorage/Packages/signal")

local a = signal.new<<(string, number)>>()

a:Connect(function(a0: string, a1: number)
    
end):Disconnect()

a:Once(function(a0: string, a1: number)
    
end):Disconnect()

a:Fire("",2)

a:DisconnectAll()

a:Destroy()

local _:string, _:number = a:Wait()

a:Destroy()

local b = signal.wrap(RunService.Heartbeat)

b:Destroy()
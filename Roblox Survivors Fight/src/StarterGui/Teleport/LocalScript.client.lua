local tweenService = game:GetService("TweenService")
local tweenInfo = TweenInfo.new(1)
local tween1 = tweenService:Create(game.Lighting.Blur, tweenInfo, {["Size"] = 24})
local tween2 = tweenService:Create(game.Lighting.Blur, tweenInfo, {["Size"] = 0})

game.ReplicatedStorage.RemoteEvents.Teleporting.OnClientEvent:Connect(function()
	tween1:Play()
	
	script.Parent.Enabled = true
	task.wait(10)
	script.Parent.Enabled = false
	tween2:Play()
end)
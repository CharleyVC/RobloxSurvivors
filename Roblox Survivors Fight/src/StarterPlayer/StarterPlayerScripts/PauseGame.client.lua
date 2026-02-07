local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local pauseRemoteEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PauseRemoteEvent")

-- Block all inputs
local function blockInputs()
	ContextActionService:BindAction(
		"BlockAllInputs",
		function() return Enum.ContextActionResult.Sink end, -- Block all inputs
		false
	)
end

-- Unblock inputs
local function unblockInputs()
	ContextActionService:UnbindAction("BlockAllInputs")
end

-- Listen for pause state changes from the server
pauseRemoteEvent.OnClientEvent:Connect(function(isPaused)
	if isPaused then
		print("Game is paused.")
		blockInputs()
	else
		print("Game is resumed.")
		unblockInputs()
	end
end)

-- Handle the "P" key to toggle pause
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.KeyCode == Enum.KeyCode.P then -- Use P to toggle pause
		print("pause")
		pauseRemoteEvent:FireServer() -- Notify the server to toggle pause
	end
end)

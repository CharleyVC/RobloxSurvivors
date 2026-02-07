local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local teleporting = game.ReplicatedStorage.RemoteEvents.Teleporting

-- Ensure the GUI is stored in ReplicatedStorage
local deathGuiTemplate = ReplicatedStorage.PlayerGui:WaitForChild("ReviveGui")

local DeathGuiHandler = {}

-- Function to display the death GUI and handle button clicks
function DeathGuiHandler.showDeathGui(player, callback)
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		warn(player.Name .. " has no PlayerGui.")
		return
	end

	-- Clone the GUI for the player
	local gui = deathGuiTemplate:Clone()
	gui.Parent = playerGui
	gui.Enabled = true

	-- Button actions
	local reviveButton = gui.Frame:WaitForChild("ReviveButton")
	local hubButton = gui.Frame:WaitForChild("HubButton")
	local score = gui.Frame:WaitForChild("Score")
	local character = player.Character or player.CharacterAdded:Wait()
	
	
	score.Text = "Score: " .. character:GetAttribute("RunScore")
	
	-- Handle revive button click
	reviveButton.MouseButton1Click:Connect(function()
		callback("revive")
	end)

	-- Handle teleport to hub button click
	hubButton.MouseButton1Click:Connect(function()
		gui:Destroy()
		callback("teleport")
		teleporting:FireClient(player)
	end)

	-- Automatically remove the GUI after a timeout
	task.delay(30, function()
		if gui and gui.Parent then
			gui:Destroy()
			callback("teleport")
			teleporting:FireClient(player)
		end
	end)
end

return DeathGuiHandler

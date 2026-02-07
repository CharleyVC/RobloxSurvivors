local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIHandler = {}

-- Define button properties (template for all buttons)
local BUTTONS = {
	Store = {
		Name = "Store",
		Position = UDim2.new(0.05, 0, 0.8, 0), -- Adjust position as needed
		Tooltip = "Open the Store",
		Image = "rbxassetid://<Insert_Store_Icon_Asset_ID>", -- Replace with store icon asset
		SoundHover = "rbxassetid://<Insert_Hover_Sound_ID>", -- Replace with hover sound
		SoundClick = "rbxassetid://<Insert_Click_Sound_ID>", -- Replace with click sound
		Callback = function() 
			-- Function to handle store button click
			print("Store button clicked!")
		end,
	},
	Upgrades = {
		Name = "Upgrades",
		Position = UDim2.new(0.25, 0, 0.8, 0),
		Tooltip = "View and upgrade your skills",
		Image = "rbxassetid://<Insert_Upgrades_Icon_Asset_ID>",
		SoundHover = "rbxassetid://<Insert_Hover_Sound_ID>",
		SoundClick = "rbxassetid://<Insert_Click_Sound_ID>",
		Callback = function()
			-- Function to handle upgrades button click
			print("Upgrades button clicked!")
		end,
	},
}

-- Function to create buttons
function UIHandler.createButton(parent, properties)
	local button = Instance.new("ImageButton")
	button.Name = properties.Name
	button.Size = UDim2.new(0.15, 0, 0.08, 0) -- Default size (adjust as needed)
	button.Position = properties.Position
	button.Image = properties.Image -- Set button image
	button.BackgroundTransparency = 1 -- Transparent background
	button.Parent = parent

	-- Tooltip
	local tooltip = Instance.new("TextLabel")
	tooltip.Size = UDim2.new(0.3, 0, 0.05, 0)
	tooltip.Position = UDim2.new(0, 0, -0.1, 0)
	tooltip.Text = properties.Tooltip
	tooltip.TextScaled = true
	tooltip.Font = Enum.Font.SourceSansBold
	tooltip.TextColor3 = Color3.new(1, 1, 1)
	tooltip.BackgroundTransparency = 0.5
	tooltip.Visible = false -- Initially hidden
	tooltip.Parent = button

	-- Hover and click effects
	button.MouseEnter:Connect(function()
		tooltip.Visible = true
		if properties.SoundHover then
			local sound = Instance.new("Sound", button)
			sound.SoundId = properties.SoundHover
			sound:Play()
			sound.Ended:Connect(function() sound:Destroy() end)
		end
		TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0.16, 0, 0.09, 0)}):Play()
	end)

	button.MouseLeave:Connect(function()
		tooltip.Visible = false
		TweenService:Create(button, TweenInfo.new(0.2), {Size = UDim2.new(0.15, 0, 0.08, 0)}):Play()
	end)

	button.MouseButton1Click:Connect(function()
		if properties.SoundClick then
			local sound = Instance.new("Sound", button)
			sound.SoundId = properties.SoundClick
			sound:Play()
			sound.Ended:Connect(function() sound:Destroy() end)
		end
		if properties.Callback then
			properties.Callback()
		end
	end)

	return button
end

-- Function to create pop-ups
function UIHandler.showPopup(playerGui, titleText)
	local popup = Instance.new("Frame")
	popup.Size = UDim2.new(0.6, 0, 0.4, 0)
	popup.Position = UDim2.new(0.2, 0, 0.3, 0)
	popup.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	popup.BackgroundTransparency = 1
	popup.Parent = playerGui

	-- Animate pop-up (inflate effect)
	TweenService:Create(popup, TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()

	-- Title
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.2, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.Text = titleText
	title.Font = Enum.Font.SourceSansBold
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.BackgroundTransparency = 1
	title.Parent = popup

	-- Exit button
	local exitButton = Instance.new("TextButton")
	exitButton.Size = UDim2.new(0.1, 0, 0.1, 0)
	exitButton.Position = UDim2.new(0.9, -10, 0, 10)
	exitButton.Text = "X"
	exitButton.Font = Enum.Font.SourceSansBold
	exitButton.TextScaled = true
	exitButton.TextColor3 = Color3.new(1, 0, 0)
	exitButton.BackgroundTransparency = 1
	exitButton.Parent = popup

	exitButton.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
end

-- Initialize UI for a player
function UIHandler.initializeUI(player)
	local playerGui = player:FindFirstChild("PlayerGui") or Instance.new("PlayerGui", player)

	-- Create buttons
	for _, properties in pairs(BUTTONS) do
		UIHandler.createButton(playerGui, properties)
	end
end

-- Listen for players joining
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		UIHandler.initializeUI(player)
	end)
end)

return UIHandler

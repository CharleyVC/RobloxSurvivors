local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- GUI Elements
local expBarBackground = script.Parent:WaitForChild("ExpBarBackground")
local expBarFill = expBarBackground:WaitForChild("ExpBarFill")
local expLabel = expBarBackground:WaitForChild("ExpLabel")
local levelLabel = script.Parent.LevelCounter:WaitForChild("LevelLabel")

expLabel.Visible = false

-- Tween function for smooth bar updates
local function tweenExpBar(targetSize, targetColor)
	local sizeTween = TweenService:Create(
		expBarFill,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(targetSize, 0, 1, 0) }
	)
	local colorTween = TweenService:Create(
		expBarFill,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = targetColor }
	)

	sizeTween:Play()
	colorTween:Play()
end

-- Function to determine the color based on health percentage
local function getExpBarColor(expPercentage)
	return Color3.fromRGB(236, 240, 241)
end

-- Function to update exp bar and label
local function updateExp()
	local currentExp = character:GetAttribute("RunExperience") or 0
	
	local level = character:GetAttribute("RunLevel") or 1
	local expThreshold = 100 * level * (level - 1) * 0.5   -- D&D Level Scaling is used for now.
	if expThreshold == 0 then
		expThreshold = 1 -- Prevent division by zero
	end
	
	local expPercentage = math.clamp(currentExp / expThreshold, 0, 1)

	-- Tween the bar size and color
	tweenExpBar(expPercentage, getExpBarColor(expPercentage))

	-- Update the health label text
	expLabel.Text = string.format("Experience: %d/%d", math.floor(currentExp), math.floor(expThreshold))
	levelLabel.Text = string.format("Level: %d", level)
end

-- Connect to exp changes
character:GetAttributeChangedSignal("RunExperience"):Connect(updateExp)
character:GetAttributeChangedSignal("RunLevel"):Connect(updateExp)


-- Initial update
updateExp()

-- Handle hover events for the exp bar
expBarBackground.MouseEnter:Connect(function()
	expLabel.Visible = true -- Show health label on hover
end)

expBarBackground.MouseLeave:Connect(function()
	expLabel.Visible = false -- Hide health label when not hovering
end)
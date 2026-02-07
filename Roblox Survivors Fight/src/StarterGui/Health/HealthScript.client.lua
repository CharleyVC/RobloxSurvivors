local TweenService = game:GetService("TweenService")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- GUI Elements
local healthBarBackground = script.Parent:WaitForChild("HealthBarBackground")
local healthBarFill = healthBarBackground:WaitForChild("HealthBarFill")
local healthLabel = healthBarBackground:WaitForChild("HealthLabel")

healthLabel.Visible = false

-- Tween function for smooth bar updates
local function tweenHealthBar(targetSize, targetColor)
	local sizeTween = TweenService:Create(
		healthBarFill,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(targetSize, 0, 1, 0) }
	)

	local colorTween = TweenService:Create(
		healthBarFill,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = targetColor }
	)

	sizeTween:Play()
	colorTween:Play()
end

-- Function to determine the color based on health percentage
local function getHealthBarColor(healthPercentage)
	if healthPercentage > 0.5 then
		return Color3.fromRGB(238, 49, 45) -- Green
	elseif healthPercentage > 0.2 then
		return Color3.fromRGB(238, 49, 45) -- Yellow
	else
		return Color3.fromRGB(238, 49, 45) -- Red
	end
end

-- Function to update health bar and label
local function updateHealth()
	local currentHealth = humanoid.Health
	local maxHealth = humanoid.MaxHealth
	local healthPercentage = math.clamp(currentHealth / maxHealth, 0, 1)

	-- Tween the bar size and color
	tweenHealthBar(healthPercentage, getHealthBarColor(healthPercentage))

	-- Update the health label text
	healthLabel.Text = string.format("Health: %d/%d", math.floor(currentHealth), math.floor(maxHealth))
end

-- Connect to health changes
humanoid.HealthChanged:Connect(updateHealth)

-- Initial update
updateHealth()

-- Handle hover events for the health bar
healthBarBackground.MouseEnter:Connect(function()
	healthLabel.Visible = true -- Show health label on hover
end)

healthBarBackground.MouseLeave:Connect(function()
	healthLabel.Visible = false -- Hide health label when not hovering
end)
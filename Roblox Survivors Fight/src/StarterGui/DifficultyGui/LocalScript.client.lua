local TweenService = game:GetService("TweenService")
local difficultyIncrement = game.ReplicatedStorage.RemoteEvents:WaitForChild("DifficultyIncrement")
local clockFrame = script.Parent.MaskFrame:WaitForChild("ClockFrame") -- The parent clock frame
local clockSize = clockFrame.AbsoluteSize.X / 2 -- Radius of the clock (assuming it's a square)

-- Function to create a number label
local function createNumber(number, angle)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.2, 0, 0.2, 0) -- Adjust size as needed
	label.BackgroundTransparency = 1 -- Transparent background
	label.Text = tostring(number)
	label.Font = Enum.Font.Bangers
	label.TextScaled = true
	label.TextColor3 = Color3.new(236, 240, 241) -- White text
	label.TextStrokeTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Parent = clockFrame
	
	if number == 12 then
		label.Text = "MAX"
		label.Size = UDim2.new(0.25, 0, 0.25, 0) -- Adjust size as needed
	end
	-- Calculate the position of the number
	local angleRadians = math.rad(angle - 90) -- Subtract 90° to start at the top (12 o'clock)
	local radius = clockSize * 0.8 -- Position numbers slightly inside the edge of the clock
	local x = math.cos(angleRadians) * radius
	local y = math.sin(angleRadians) * radius

	label.Position = UDim2.new(0.5, x, 0.5, y)

	-- Rotate the label to face the center
	label.Rotation = angle -- Rotate the label to match its angle
end

-- Place numbers around the clock
for i = 1, 12 do
	local angle = (360 / 12) * (i - 1) -- Calculate the angle for each number
	createNumber(i, angle)
end


-- GUI Elements
local maskFrame = script.Parent:WaitForChild("MaskFrame") -- Frame that masks the bottom half
local difficultyFrame = maskFrame:WaitForChild("ClockFrame") -- Rotating clock inside the mask

-- Configure mask frame
maskFrame.ClipsDescendants = true -- Enable clipping

local currentDifficulty = 1
local rotationStep = 360 / 12 -- Adjust based on how many steps (e.g., hours on a clock)
local currentRotation = 0 -- Track the current rotation

-- Function to rotate and update difficulty
local function advanceDifficulty(newDifficulty)
	-- Calculate the target rotation (anti-clockwise)
	currentRotation -= rotationStep
	if currentRotation < -360 then
		currentRotation = currentRotation + 360 -- Reset rotation to prevent overflow
	end

	-- Tween the rotation of the frame
	local rotationTween = TweenService:Create(
		difficultyFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Rotation = currentRotation }
	)

	-- Play the rotation
	rotationTween:Play()
end

difficultyIncrement.OnClientEvent:Connect(function(difficulty)
	advanceDifficulty(difficulty)
end
)

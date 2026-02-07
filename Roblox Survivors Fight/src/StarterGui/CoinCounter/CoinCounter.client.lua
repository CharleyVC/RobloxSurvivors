local TweenService = game:GetService("TweenService")

-- GUI Elements
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local screenGui = script.Parent
local counterFrame = screenGui.CounterFrame:WaitForChild("CounterFrame2") -- Frame containing the numbers
local currentLabel = counterFrame:WaitForChild("CurrentLabel")
local nextLabel = counterFrame:WaitForChild("NextLabel")

-- Variables
local coinCount = 0 -- Starting coin count
local displayCount = 0 -- Count currently displayed on the GUI
local tweenDuration = 0.2 -- Duration of the sliding animation

-- Function to update the counter visually
local function updateCounter()
	local currentCoins = character:GetAttribute("RunCoins") or 0
	nextLabel.Text = tostring(currentCoins) -- Set the next number

	-- Tween the TextLabels upward
	local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local currentTween = TweenService:Create(currentLabel, tweenInfo, {
		Position = UDim2.new(0.5, 0, -0.5, 0) -- Move currentLabel up
	})
	local nextTween = TweenService:Create(nextLabel, tweenInfo, {
		Position = UDim2.new(0.5, 0, 0.5, 0) -- Move nextLabel into place
	})

	currentTween:Play()
	nextTween:Play()

	-- After the animation completes
	currentTween.Completed:Connect(function()
		-- Reset positions for the next animation
		currentLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
		nextLabel.Position = UDim2.new(0.5, 0, 1.5, 0)
		-- Update currentLabel to the new count
		currentLabel.Text = tostring(currentCoins)
		nextLabel.Text = ""
	end)
end

character:GetAttributeChangedSignal("RunCoins"):Connect(updateCounter)

-- Example usage
task.wait(2) -- Simulate delay before adding coins


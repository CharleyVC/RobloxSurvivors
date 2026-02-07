local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MobileCombatGui")

local attackGui = gui:WaitForChild("Attack")
local mainPad = attackGui:WaitForChild("MainAttackPad")
local altPad = attackGui:WaitForChild("AltAttackPad")
local dashButton = attackGui:WaitForChild("DashButton")

local primaryStick = gui:WaitForChild("AimStickPrimary")
local primaryBase = primaryStick:WaitForChild("Base")
local primaryThumb = primaryBase:WaitForChild("Thumb")

local secondaryStick = gui:WaitForChild("AimStickSecondary")
local secondaryBase = secondaryStick:WaitForChild("Base")
local secondaryThumb = secondaryBase:WaitForChild("Thumb")

local InputController = require(ReplicatedStorage.Controllers:WaitForChild("InputController"))
local Targeting = require(ReplicatedStorage.Controllers:WaitForChild("Targeting"))


---------------------------------------------------------------------
-- UI Setup (sticks always visible, base/centers anchored correctly)
---------------------------------------------------------------------
primaryBase.AnchorPoint = Vector2.new(0.5, 0.5)
primaryThumb.AnchorPoint = Vector2.new(0.5, 0.5)
secondaryBase.AnchorPoint = Vector2.new(0.5, 0.5)
secondaryThumb.AnchorPoint = Vector2.new(0.5, 0.5)

primaryStick.Enabled = true
secondaryStick.Enabled = true

primaryThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
secondaryThumb.Position = UDim2.new(0.5, 0, 0.5, 0)


---------------------------------------------------------------------
-- Internal State
---------------------------------------------------------------------
local activeTouch = nil
local startPos = nil
local currentMode = nil  -- "Primary" or "Secondary"
local currentStick = nil
local currentBase = nil
local currentThumb = nil

local MAX_RADIUS = 70       -- thumb distance limit (behavioral)
local SPRINT_EXTRA_RANGE = 1.2  -- movement only; aiming ignores sprint


---------------------------------------------------------------------
-- Convert aim2D → world direction (camera-relative)
---------------------------------------------------------------------
local function ConvertToWorldDirection(aim2D)
	local camCF = workspace.CurrentCamera.CFrame

	local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
	local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

	local dir = forward * -aim2D.Y + right * aim2D.X
	if dir.Magnitude < 0.1 then
		return forward
	end

	return dir.Unit
end


---------------------------------------------------------------------
-- Helper: Convert screen position → stick-local space
---------------------------------------------------------------------
local function ScreenToStick(pos, stickFrame)
	local absPos = stickFrame.AbsolutePosition
	return pos - Vector2.new(absPos.X, absPos.Y)
end


---------------------------------------------------------------------
-- BEGIN AIM (touch start)
---------------------------------------------------------------------
local function BeginAim(input, mode)
	activeTouch = input
	startPos = Vector2.new(input.Position.X, input.Position.Y)
	currentMode = mode

	if mode == "Primary" then
		currentStick = primaryStick
		currentBase = primaryBase
		currentThumb = primaryThumb
		InputController.MobilePrimaryBegin()
	else
		currentStick = secondaryStick
		currentBase = secondaryBase
		currentThumb = secondaryThumb
		InputController.MobileSecondaryBegin()
	end

	-- Snap base to touch position (in stick-local space)
	local localCenter = ScreenToStick(startPos, currentStick)
	currentBase.Position = UDim2.fromOffset(localCenter.X, localCenter.Y)

	-- Reset thumb to center of base
	currentThumb.Position = UDim2.new(0.5, 0, 0.5, 0)
end


---------------------------------------------------------------------
---------------------------------------------------------------------
-- UPDATE AIM (drag) — direction + strength
---------------------------------------------------------------------
local function UpdateAim(input)
	if input ~= activeTouch then return end

	local currentScreen = Vector2.new(input.Position.X, input.Position.Y)
	local diff = currentScreen - startPos
	local dist = diff.Magnitude

	-- Visual thumb movement
	currentThumb.Position = UDim2.new(0.5, diff.X, 0.5, diff.Y)

	-- Clamped aiming
	local clamped = diff
	if dist > MAX_RADIUS then
		clamped = diff.Unit * MAX_RADIUS
	end

	-- Strength 0–1
	local strength = math.clamp(clamped.Magnitude / MAX_RADIUS, 0, 1)

	local rawAim = clamped / MAX_RADIUS



	-- OPTION 2: Nonlinear curve (softens small motions)
	local magnitude = rawAim.Magnitude
	rawAim = rawAim * magnitude    -- cubic-like response

	-- Final aim2D after sensitivity control
	local aim2D = rawAim
	
	local aim3D = ConvertToWorldDirection(aim2D)

	-- Send aiming info
	Targeting:SetMobileAim({ dir = aim3D, strength = strength })

	if currentMode == "Primary" then
		InputController.MobilePrimaryAim(aim3D, strength)
	else
		InputController.MobileSecondaryAim(aim3D, strength)
	end
end


---------------------------------------------------------------------
-- END AIM (touch release)
---------------------------------------------------------------------
local function EndAim(input)
	if input ~= activeTouch then return end

	if currentMode == "Primary" then
		InputController.MobilePrimaryEnd()
	else
		InputController.MobileSecondaryEnd()
	end

	-- Reset thumb visual
	currentThumb.Position = UDim2.new(0.5, 0, 0.5, 0)

	-- Clear state
	activeTouch = nil
	startPos = nil
	currentMode = nil
	currentStick = nil
	currentBase = nil
	currentThumb = nil
end


---------------------------------------------------------------------
-- PRIMARY PAD BEGIN AIM
---------------------------------------------------------------------
mainPad.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
		BeginAim(input, "Primary")
	end
end)

---------------------------------------------------------------------
-- SECONDARY PAD BEGIN AIM
---------------------------------------------------------------------
altPad.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not activeTouch then
		BeginAim(input, "Secondary")
	end
end)

---------------------------------------------------------------------
-- GLOBAL TOUCH MOVEMENT (works outside UI)
---------------------------------------------------------------------
UIS.TouchMoved:Connect(function(input)
	if input == activeTouch then
		UpdateAim(input)
	end
end)

---------------------------------------------------------------------
-- GLOBAL TOUCH ENDED (works even if released outside UI)
---------------------------------------------------------------------
UIS.TouchEnded:Connect(function(input)
	if input == activeTouch then
		EndAim(input)
	end
end)

---------------------------------------------------------------------
-- DASH BUTTON
---------------------------------------------------------------------
local dashButton = attackGui:WaitForChild("DashButton")

dashButton.Activated:Connect(function()
	InputController.MobileDash()
end)
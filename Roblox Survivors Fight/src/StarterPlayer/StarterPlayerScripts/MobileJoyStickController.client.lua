-- StarterPlayerScripts/MobileJoystickController.lua
-- Dynamic touch joystick: first touch on left side becomes center

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local sprintEvent = game.ReplicatedStorage.BindableEvents:WaitForChild("MobileSprintEvent")
local MovementState = require(game.ReplicatedStorage.Controllers:WaitForChild("MovementState"))
local Targeting = require(game.ReplicatedStorage.Controllers:WaitForChild("Targeting"))

-- Only run on touch devices
if not UserInputService.TouchEnabled then
	return
end

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local camera = workspace.CurrentCamera

-- UI references
local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("MobileCombatGui")
local moveFolder = gui:WaitForChild("Move")

local area = moveFolder:WaitForChild("JoystickArea")   -- big left-side region
local base = area:WaitForChild("JoystickBase")         -- visual circle
local thumb = base:WaitForChild("JoystickThumb")       -- inner circle

-- Ensure anchors are centered so positions are intuitive
base.AnchorPoint = Vector2.new(0.5, 0.5)
thumb.AnchorPoint = Vector2.new(0.5, 0.5)

-- SETTINGS
local JOYSTICK_RADIUS = 60   -- max distance thumb can move (pixels) (used indirectly)
local DEADZONE = 4           -- minimum drag magnitude to register movement
local SPRINT_THRESHOLD = 1.2 -- joystick magnitude (0-1) at which sprint starts

-- STATE
local controllingTouch: InputObject? = nil
local moveVector = Vector3.zero
local joystickCenter: Vector2? = nil  -- in AREA-local space
local isSprinting = false
MovementState.SetMoveVector(moveVector)

----------------------------------------------------
-- HELPERS
----------------------------------------------------

local function screenToArea(pos: Vector2): Vector2
	-- Convert from screen-space to JoystickArea-local space
	local areaPos = area.AbsolutePosition
	return pos - Vector2.new(areaPos.X, areaPos.Y)
end

local function getMaxRadius()
	local baseSize = base.AbsoluteSize
	local thumbSize = thumb.AbsoluteSize

	-- Circle radius of base (use smaller side)
	local baseRadius = math.min(baseSize.X, baseSize.Y) / 2
	-- Radius of the thumb
	local thumbRadius = math.min(thumbSize.X, thumbSize.Y) / 2

	-- Max distance from base center to thumb center
	return baseRadius - thumbRadius
end

local function resetJoystick()
	base.Visible = false
	thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	moveVector = Vector3.zero
	MovementState.SetMoveVector(Vector3.zero)

	if isSprinting then
		isSprinting = false
		sprintEvent:Fire(false)
	end

	joystickCenter = nil
end

local function updateFromTouch(touchPosScreen: Vector2)
	local localPos = screenToArea(touchPosScreen)

	if not joystickCenter then
		joystickCenter = localPos
		base.Position = UDim2.fromOffset(joystickCenter.X, joystickCenter.Y)
		base.Visible = true
		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)
	end

	local center = joystickCenter
	local diff = localPos - center
	local dist = diff.Magnitude

	-- Thumb no longer clamped visually
	thumb.Position = UDim2.new(0.5, diff.X, 0.5, diff.Y)

	-- Movement stays clamped (gameplay)
	local maxRadius = getMaxRadius()
	local movementVector2D = diff
	if dist > maxRadius then
		movementVector2D = diff.Unit * maxRadius
	end

	-- Deadzone
	local DEADZONE = 6
	if dist < DEADZONE then
		moveVector = Vector3.zero
		MovementState.SetMoveVector(Vector3.zero)
		sprintEvent:Fire(false)
		isSprinting = false
		return
	end

	-- Convert to world-space
	local camCF = camera.CFrame
	local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
	local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

	local normalizedX = movementVector2D.X / maxRadius
	local normalizedY = movementVector2D.Y / maxRadius

	local movementDir = right * normalizedX + forward * -normalizedY

	-- Normalize movement vector
	if movementDir.Magnitude > 1 then
		movementDir = movementDir.Unit
	end

	moveVector = movementDir
	MovementState.SetMoveVector(moveVector)

	-- Sprint threshold based on extended radius
	local sprintThreshold = maxRadius * 1.2
	local shouldSprint = dist > sprintThreshold

	if shouldSprint ~= isSprinting then
		isSprinting = shouldSprint
		sprintEvent:Fire(isSprinting)
	end
end



----------------------------------------------------
-- INPUT HANDLERS
----------------------------------------------------

area.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not controllingTouch then
		controllingTouch = input

		local startPosScreen = Vector2.new(input.Position.X, input.Position.Y)
		local startLocal = screenToArea(startPosScreen)
		joystickCenter = startLocal

		base.Position = UDim2.fromOffset(startLocal.X, startLocal.Y)
		base.Visible = true
		thumb.Position = UDim2.new(0.5, 0, 0.5, 0)

		updateFromTouch(startPosScreen)
	end
end)

UserInputService.TouchMoved:Connect(function(input)
	if input == controllingTouch then
		updateFromTouch(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

UserInputService.TouchEnded:Connect(function(input)
	if input == controllingTouch then
		controllingTouch = nil
		resetJoystick()
	end
end)

----------------------------------------------------
-- APPLY MOVEMENT EACH FRAME
----------------------------------------------------

RunService.RenderStepped:Connect(function()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if Targeting.InputMode ~= "Touch" then
		return  -- let WASD / gamepad take over
	end

	humanoid:Move(moveVector, true)
end)

player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = character:WaitForChild("Humanoid")
	resetJoystick()
end)

resetJoystick()

-- ReplicatedStorage/Controllers/Input/TouchInput.lua
-- OOP Touch Input Module - Movement + Primary + Secondary + Dash (fixed centering & aim)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Targeting = require(ReplicatedStorage.Controllers:WaitForChild("Targeting"))
local InputController = require(ReplicatedStorage.Controllers:WaitForChild("InputController"))
local MovementState = require(ReplicatedStorage.Controllers:WaitForChild("MovementState"))

local TouchInput = {}
TouchInput.__index = TouchInput

---------------------------------------------------------------------
-- Utility: screen position → local UDim2 in a parent GuiObject
---------------------------------------------------------------------
local function screenToLocalUDim2(parentGuiObject: GuiObject, screenPos: Vector2): UDim2
	local parentPos = parentGuiObject.AbsolutePosition
	local rel = screenPos - parentPos
	return UDim2.fromOffset(rel.X, rel.Y)
end

---------------------------------------------------------------------
-- Constructor
---------------------------------------------------------------------
function TouchInput.new(mobileGui)
	local self = setmetatable({}, TouchInput)

	self.Gui = mobileGui
	self.Enabled = false

	-- Movement joystick UI
	local moveFolder = mobileGui:WaitForChild("Move")
	self.MoveArea = moveFolder:WaitForChild("JoystickArea")
	self.MoveBase = self.MoveArea:WaitForChild("JoystickBase")
	self.MoveThumb = self.MoveBase:WaitForChild("JoystickThumb")

	-- Attack UI
	local attackFolder = mobileGui:WaitForChild("Attack")
	self.MainPad = attackFolder:WaitForChild("MainAttackPad")
	self.AltPad = attackFolder:WaitForChild("AltAttackPad")
	self.DashButton = attackFolder:WaitForChild("DashButton")

	-- Attack joysticks now live INSIDE each pad
	self.PrimaryBase = self.MainPad:WaitForChild("Base")
	self.PrimaryThumb = self.PrimaryBase:WaitForChild("Thumb")

	self.SecondaryBase = self.AltPad:WaitForChild("Base")
	self.SecondaryThumb = self.SecondaryBase:WaitForChild("Thumb")

	-- Movement state
	self.MoveTouch = nil
	self.MoveCenter = nil      -- screen-space Vector2
	self.MoveVector = Vector3.zero
	self.IsSprinting = false

	-- Attack state
	self.ActiveAttackTouch = nil
	self.ActiveMode = nil      -- "Primary" or "Secondary"

	-- Internals
	self.Connections = {}

	return self
end

---------------------------------------------------------------------
-- Connection helpers
---------------------------------------------------------------------
function TouchInput:_connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(self.Connections, c)
	return c
end

function TouchInput:_disconnectAll()
	for _, c in ipairs(self.Connections) do
		c:Disconnect()
	end
	self.Connections = {}
end

---------------------------------------------------------------------
-- Movement Joystick Helpers
---------------------------------------------------------------------
local DEADZONE = 4
local SPRINT_THRESHOLD = 0.9

local function getMaxRadius(base: GuiObject, thumb: GuiObject)
	local baseSize = base.AbsoluteSize
	local thumbSize = thumb.AbsoluteSize

	local baseRadius = math.min(baseSize.X, baseSize.Y) / 2
	local thumbRadius = math.min(thumbSize.X, thumbSize.Y) / 2

	return baseRadius - thumbRadius
end

function TouchInput:_resetMovement()
	-- Hide base, recenter thumb, stop movement
	self.MoveBase.Visible = false
	self.MoveBase.Position = UDim2.fromScale(0.5, 0.5)
	self.MoveThumb.Position = UDim2.fromScale(0.5, 0.5)
	self.MoveVector = Vector3.zero
	MovementState.SetMoveVector(Vector3.zero)
	Targeting:SetMobileAim(nil)

	if self.IsSprinting then
		self.IsSprinting = false
		ReplicatedStorage.BindableEvents.MobileSprintEvent:Fire(false)
	end

	self.MoveCenter = nil
end

function TouchInput:_updateMovement(pos2D: Vector2, humanoid)
	if not self.MoveCenter then return end
	if not humanoid or humanoid.Health <= 0 then return end

	local raw = pos2D - self.MoveCenter
	local mag = raw.Magnitude

	-- Deadzone
	if mag < DEADZONE then
		self.MoveThumb.Position = UDim2.fromScale(0.5, 0.5)
		self.MoveVector = Vector3.zero
		MovementState.SetMoveVector(Vector3.zero)
		return
	end

	local maxRadius = getMaxRadius(self.MoveBase, self.MoveThumb)
	if mag > maxRadius then
		raw = raw.Unit * maxRadius
		mag = maxRadius
	end

	-- IMPORTANT: thumb centered on base (AnchorPoint 0.5,0.5)
	-- center (0.5,0.5) + pixel offset
	self.MoveThumb.Position = UDim2.new(0.5, raw.X, 0.5, raw.Y)

	-- Camera-relative world movement
	local cam = workspace.CurrentCamera
	if not cam then return end

	local forward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit

	local inputX = raw.X / maxRadius
	local inputY = raw.Y / maxRadius

	local moveDir = (right * inputX) + (forward * -inputY)
	if moveDir.Magnitude > 1 then
		moveDir = moveDir.Unit
	end

	self.MoveVector = moveDir
	MovementState.SetMoveVector(moveDir)

	-- Sprint check
	local normMag = mag / maxRadius
	local shouldSprint = normMag >= SPRINT_THRESHOLD
	if shouldSprint ~= self.IsSprinting then
		self.IsSprinting = shouldSprint
		ReplicatedStorage.BindableEvents.MobileSprintEvent:Fire(self.IsSprinting)
	end
end

---------------------------------------------------------------------
-- Convert 2D stick drag to world aim direction
---------------------------------------------------------------------
local function Vec2ToWorld(aim2D: Vector2): Vector3
	local cam = workspace.CurrentCamera
	if not cam then
		return Vector3.new(0, 0, -1)
	end

	local forward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit

	local worldDir = forward * -aim2D.Y + right * aim2D.X
	if worldDir.Magnitude < 0.1 then
		return forward
	end
	return worldDir.Unit
end

---------------------------------------------------------------------
-- Attack Joystick Begin / Update / End
---------------------------------------------------------------------
local ATTACK_MAX_RADIUS = 60

function TouchInput:_beginAttack(input: InputObject, mode: "Primary" | "Secondary")
	-- Never allow base repositioning once an attack touch exists
	if self.ActiveAttackTouch and self.ActiveAttackTouch ~= input then
		return -- ignore new touches
	end

	-- NEW: prevent repositioning even with same touch
	if self.ActiveAttackTouch == input then
		return
	end


	self.ActiveAttackTouch = input
	self.ActiveMode = mode

	-- Choose pad & base for this mode
	local pad, base, thumb
	if mode == "Primary" then
		pad = self.MainPad
		base = self.PrimaryBase
		thumb = self.PrimaryThumb
	else
		pad = self.AltPad
		base = self.SecondaryBase
		thumb = self.SecondaryThumb
	end

	-- Place base centered at finger (relative to pad)
	local screenPos = Vector2.new(input.Position.X, input.Position.Y)
	base.Position = screenToLocalUDim2(pad, screenPos)

	-- Center thumb on base at start
	thumb.Position = UDim2.fromScale(0.5, 0.5)

	-- Begin firing logic
	if mode == "Primary" then
		InputController.PrimaryBegin()
	else
		InputController.SecondaryBegin()
	end
end

function TouchInput:_updateAttack(input: InputObject)
	if input ~= self.ActiveAttackTouch then return end
	if not self.ActiveMode then return end

	local currentPos = Vector2.new(input.Position.X, input.Position.Y)

	local base, thumb
	if self.ActiveMode == "Primary" then
		base = self.PrimaryBase
		thumb = self.PrimaryThumb
	else
		base = self.SecondaryBase
		thumb = self.SecondaryThumb
	end

	-- Center of base in screen-space
	local baseCenter = base.AbsolutePosition + base.AbsoluteSize / 2
	local raw = currentPos - baseCenter
	local mag = raw.Magnitude

	if mag > ATTACK_MAX_RADIUS then
		raw = raw.Unit * ATTACK_MAX_RADIUS
		mag = ATTACK_MAX_RADIUS
	end

	-- Thumb offset from base center (anchor 0.5,0.5)
	thumb.Position = UDim2.new(0.5, raw.X, 0.5, raw.Y)

	local aim2D = raw / ATTACK_MAX_RADIUS
	local aimDir3D = Vec2ToWorld(aim2D)
	local strength = mag / ATTACK_MAX_RADIUS

	-- This feeds Targeting:GetAim() for mobile twin-stick
	Targeting:SetMobileAim({
		dir = aimDir3D,
		strength = strength,
	})
end

function TouchInput:_endAttack(input: InputObject)
	if input ~= self.ActiveAttackTouch then return end

	local pad, base, thumb
	if self.ActiveMode == "Primary" then
		pad = self.MainPad
		base = self.PrimaryBase
		thumb = self.PrimaryThumb
	else
		pad = self.AltPad
		base = self.SecondaryBase
		thumb = self.SecondaryThumb
	end

	-- Reset base & thumb to neutral center of pad
	base.Position = UDim2.fromScale(0.5, 0.5)
	thumb.Position = UDim2.fromScale(0.5, 0.5)

	-- Fire logic: primary stops, secondary fires once
	if self.ActiveMode == "Primary" then
		InputController.PrimaryEnd()
	else
		InputController.SecondaryEnd()
	end

	self.ActiveAttackTouch = nil
	self.ActiveMode = nil
	Targeting:SetMobileAim(nil)
end

---------------------------------------------------------------------
-- Enable / Disable
---------------------------------------------------------------------
function TouchInput:Enable()
	if self.Enabled then return end
	self.Enabled = true

	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	-------------------------------------------------------------
	-- Movement input
	-------------------------------------------------------------
	self:_connect(self.MoveArea.InputBegan, function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if self.MoveTouch then return end

		self.MoveTouch = input
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		self.MoveCenter = pos

		-- Position MoveBase relative to MoveArea
		self.MoveBase.Position = screenToLocalUDim2(self.MoveArea, pos)
		self.MoveBase.Visible = true

		self:_updateMovement(pos, humanoid)
	end)

	self:_connect(UserInputService.TouchMoved, function(input)
		if input == self.MoveTouch then
			self:_updateMovement(Vector2.new(input.Position.X, input.Position.Y), humanoid)
		end
		if input == self.ActiveAttackTouch then
			self:_updateAttack(input)
		end
	end)

	self:_connect(UserInputService.TouchEnded, function(input)
		if input == self.MoveTouch then
			self.MoveTouch = nil
			self:_resetMovement()
		end
		if input == self.ActiveAttackTouch then
			self:_endAttack(input)
		end
	end)

	-------------------------------------------------------------
	-- Attack pads
	-------------------------------------------------------------
	self:_connect(self.MainPad.InputBegan, function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.Touch then return end

		-- ❗ NEW: prevent starting secondary while primary active
		-- If ANY attack is active (including this same mode), do NOT reposition base.
		if self.ActiveAttackTouch then
			return
		end


		self:_beginAttack(input, "Primary")
	end)

	self:_connect(self.AltPad.InputBegan, function(input, gp)
		if gp then return end
		if input.UserInputType ~= Enum.UserInputType.Touch then return end

		-- If ANY attack is active (including this same mode), do NOT reposition base.
		if self.ActiveAttackTouch then
			return
		end


		self:_beginAttack(input, "Secondary")
	end)


	-- (We rely on global TouchMoved/TouchEnded for continuous update & release)

	-------------------------------------------------------------
	-- Dash button
	-------------------------------------------------------------
	self:_connect(self.DashButton.Activated, function()
		if InputController.DoDash then
			InputController.DoDash()
		end
	end)

	-------------------------------------------------------------
	-- Movement apply loop
	-------------------------------------------------------------
	self:_connect(RunService.RenderStepped, function()
		if not self.Enabled then return end
		if not humanoid or humanoid.Health <= 0 then return end

		humanoid:Move(self.MoveVector, true)
	end)

	print("[TouchInput] Enabled")
end

function TouchInput:Disable()
	if not self.Enabled then return end
	self.Enabled = false

	self:_disconnectAll()

	self:_resetMovement()

	-- Reset attack UI
	self.PrimaryBase.Position = UDim2.fromScale(0.5, 0.5)
	self.PrimaryThumb.Position = UDim2.fromScale(0.5, 0.5)
	self.SecondaryBase.Position = UDim2.fromScale(0.5, 0.5)
	self.SecondaryThumb.Position = UDim2.fromScale(0.5, 0.5)

	self.ActiveAttackTouch = nil
	self.ActiveMode = nil

	Targeting:SetMobileAim(nil)

	print("[TouchInput] Disabled")
end

return TouchInput

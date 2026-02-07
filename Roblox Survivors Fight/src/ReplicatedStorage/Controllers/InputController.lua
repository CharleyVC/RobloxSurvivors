-- ReplicatedStorage/Controllers/InputController.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WeaponClient = require(ReplicatedStorage:WaitForChild("WeaponClient"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("AnimationHandler"))
local KM = require(ReplicatedStorage.Controllers.Input:WaitForChild("KeyboardMouseInput"))
local DashManager = require(ReplicatedStorage.Controllers:WaitForChild("DashManager"))
local GamepadController = require(ReplicatedStorage.Controllers:WaitForChild("GamepadController"))
local AimAssist = require(ReplicatedStorage.Controllers:WaitForChild("AimAssist"))

local InputController = {}
InputController.IsPrimaryAiming = false
InputController.IsSecondaryAiming = false
InputController.MoveDirection = Vector3.zero
InputController.LastMoveDirection = Vector3.zero

------------------------------------------------------------
-- SPRINT HANDLING (PC)
-- Mobile still uses legacy setSprint until refactor
------------------------------------------------------------
function InputController.SprintBegin()
	WeaponClient.SetSprintActive(true)
end

function InputController.SprintEnd()
	WeaponClient.SetSprintActive(false)
end

------------------------------------------------------------
-- ATTACK HANDLERS (PC)
------------------------------------------------------------
function InputController.PrimaryBegin()
	InputController.IsPrimaryAiming = true
	WeaponClient.StartFiring("Primary")
end

function InputController.PrimaryEnd()
	InputController.IsPrimaryAiming = false
	WeaponClient.StopFiring("Primary")
end

function InputController.SecondaryBegin()
	InputController.IsSecondaryAiming = true
	WeaponClient.UpdateAim("Secondary", nil)
end

function InputController.SecondaryEnd()
	InputController.IsSecondaryAiming = false

	local aim = WeaponClient.CurrentAim["Secondary"]
	WeaponClient.FireSingle("Secondary", aim)
	WeaponClient.ClearAim("Secondary")
end

------------------------------------------------------------
-- GAMEPAD AIM HELPERS
------------------------------------------------------------
local function getCharacter()
	return Players.LocalPlayer and Players.LocalPlayer.Character
end

function InputController.SetMoveDirection(direction: Vector3)
	InputController.MoveDirection = direction
	if direction.Magnitude > 0 then
		InputController.LastMoveDirection = direction.Unit
	end

	if InputController.IsPrimaryAiming then
		local aim = InputController.GetAttackDirection()
		WeaponClient.UpdateAim("Primary", aim)
	elseif InputController.IsSecondaryAiming then
		local aim = InputController.GetAttackDirection()
		WeaponClient.UpdateAim("Secondary", aim)
	end
end

function InputController.GetAttackDirection()
	local baseDir = InputController.MoveDirection
	if baseDir.Magnitude <= 0 then
		baseDir = InputController.LastMoveDirection
	end

	if baseDir.Magnitude <= 0 then
		local character = getCharacter()
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			baseDir = hrp.CFrame.LookVector
		else
			baseDir = Vector3.new(0, 0, -1)
		end
	end

	local character = getCharacter()
	return AimAssist.GetAdjustedDirection(character, baseDir)
end

------------------------------------------------------------
-- GAMEPAD ATTACK HANDLERS
------------------------------------------------------------
function InputController.GamepadPrimaryBegin()
	InputController.IsPrimaryAiming = true
	local aim = InputController.GetAttackDirection()
	WeaponClient.UpdateAim("Primary", aim)
	WeaponClient.StartFiring("Primary")
end

function InputController.GamepadPrimaryEnd()
	InputController.IsPrimaryAiming = false
	WeaponClient.StopFiring("Primary")
	WeaponClient.ClearAim("Primary")
end

function InputController.GamepadSecondaryBegin()
	InputController.IsSecondaryAiming = true
	local aim = InputController.GetAttackDirection()
	WeaponClient.UpdateAim("Secondary", aim)
end

function InputController.GamepadSecondaryEnd()
	InputController.IsSecondaryAiming = false
	local aim = WeaponClient.CurrentAim["Secondary"]
	WeaponClient.FireSingle("Secondary", aim)
	WeaponClient.ClearAim("Secondary")
end

function InputController.GamepadDash()
	DashManager.RequestDash()
end

------------------------------------------------------------
-- DASH
------------------------------------------------------------
function InputController.DoDash()
	DashManager.RequestDash()
end

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------
function InputController.Init()

	-- Hook up Keyboard/Mouse
	KM.OnPrimaryBegin   = InputController.PrimaryBegin
	KM.OnPrimaryEnd     = InputController.PrimaryEnd

	KM.OnSecondaryBegin = InputController.SecondaryBegin
	KM.OnSecondaryEnd   = InputController.SecondaryEnd

	KM.OnSprintBegin    = InputController.SprintBegin
	KM.OnSprintEnd      = InputController.SprintEnd

	KM.OnDash           = InputController.DoDash

	KM:Enable()

	GamepadController.OnMove = InputController.SetMoveDirection
	GamepadController.OnPrimaryBegin = InputController.GamepadPrimaryBegin
	GamepadController.OnPrimaryEnd = InputController.GamepadPrimaryEnd
	GamepadController.OnSecondaryBegin = InputController.GamepadSecondaryBegin
	GamepadController.OnSecondaryEnd = InputController.GamepadSecondaryEnd
	GamepadController.OnDash = InputController.GamepadDash

	GamepadController:Enable()

--	print("[InputController] Initialized")
end

return InputController

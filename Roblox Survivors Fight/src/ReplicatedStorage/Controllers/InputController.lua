-- ReplicatedStorage/Controllers/InputController.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local WeaponClient = require(ReplicatedStorage:WaitForChild("WeaponClient"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("AnimationHandler"))
local KM = require(ReplicatedStorage.Controllers.Input:WaitForChild("KeyboardMouseInput"))
local DashManager = require(ReplicatedStorage.Controllers:WaitForChild("DashManager"))

local InputController = {}
InputController.IsPrimaryAiming = false
InputController.IsSecondaryAiming = false

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

--	print("[InputController] Initialized")
end

return InputController

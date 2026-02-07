-- StarterPlayerScripts/ClientInit.client.lua
-- Centralized loader for all client-side systems

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

---------------------------------------------------------------------
-- Helper: SafeRequire (prevents errors from halting initialization)
---------------------------------------------------------------------
local function SafeRequire(module)
	local ok, result = pcall(function()
		return require(module)
	end)

	if not ok then
		warn("Failed to require module:", module, result)
		return nil
	end

	return result
end

---------------------------------------------------------------------
-- Load Core Client Controllers
-- ORDER MATTERS!
---------------------------------------------------------------------

local ControllersFolder = ReplicatedStorage:WaitForChild("Controllers")

local InputController       = SafeRequire(ControllersFolder:WaitForChild("InputController"))
local Targeting             = SafeRequire(ControllersFolder:WaitForChild("Targeting"))
local DashManager           = SafeRequire(ControllersFolder:WaitForChild("DashManager"))
local AnimationHandler      = SafeRequire(ReplicatedStorage:WaitForChild("AnimationHandler"))

---------------------------------------------------------------------
-- Load Weapon System
---------------------------------------------------------------------
local WeaponClient          = SafeRequire(ReplicatedStorage:WaitForChild("WeaponClient"))

---------------------------------------------------------------------
-- INIT ALL MODULES THAT PROVIDE Init() METHODS
---------------------------------------------------------------------

if InputController and InputController.Init then
	InputController.Init()
end

if Targeting and Targeting.Init then
	Targeting.Init()
end

if WeaponClient and WeaponClient.Init then
	WeaponClient.Init()
	print("WeaponClient.Init()")
end

if DashManager and DashManager.Init then
	DashManager.Init()
end


---------------------------------------------------------------------
-- DEBUG LOG
---------------------------------------------------------------------
print("ClientInit Loaded Successfully for:", player.Name)

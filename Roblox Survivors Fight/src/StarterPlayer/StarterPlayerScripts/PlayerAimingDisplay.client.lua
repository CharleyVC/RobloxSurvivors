local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local Targeting = require(ReplicatedStorage.Controllers:WaitForChild("Targeting"))
local InputController = require(ReplicatedStorage.Controllers:WaitForChild("InputController"))
local WeaponClient = require(ReplicatedStorage:WaitForChild("WeaponClient"))
local EquipEvent = ReplicatedStorage.RemoteEvents:WaitForChild("EquipEvent")
local GroundResolver = require(ReplicatedStorage:WaitForChild("GroundResolver"))



------------------------------------------------------------
-- Reticle part
------------------------------------------------------------



local aoe = Instance.new("Part")
aoe.Name = "AOEPreview"
aoe.Shape = Enum.PartType.Cylinder
aoe.Material = Enum.Material.ForceField
aoe.Color = Color3.fromRGB(120, 180, 255)
aoe.Size = Vector3.new(0.1, 8, 8)
aoe.Anchored = true
aoe.CanCollide = false
aoe.Transparency = 1
aoe.Parent = workspace
aoe.CollisionGroup = "VFX"

------------------------------------------------------------
-- PERFORMANCE: throttle updates
------------------------------------------------------------
local lastUpdate = 0
local updateRate = 1/30 -- update 30 times per second (mobile-safe)

RunService.RenderStepped:Connect(function(dt)
	lastUpdate += dt
	if lastUpdate < updateRate then return end
	lastUpdate = 0

	local tool = WeaponClient.GetEquippedWeapon()
	if not tool then
		aoe.Transparency = 1
		return
	end

	local isTouchMode = (Targeting.InputMode == "Touch")
	local primaryAiming = InputController.IsPrimaryAiming
	local secondaryAiming = InputController.IsSecondaryAiming

	-- Only show reticle while aiming on mobile
	if isTouchMode and not (primaryAiming or secondaryAiming) then
		aoe.Transparency = 1
		return
	end

	-- WHICH ACTION ARE WE AIMING FOR?
	local baseAction = secondaryAiming and "Secondary" or "Primary"

	-----------------------------------------------
	-- READ CACHED WEAPON PROPERTIES
	-----------------------------------------------
	local stats = WeaponClient.CurrentWeaponStats
	if not stats then
		aoe.Transparency = 1
		return
	end
	
	local actionStats = stats[baseAction]
	if not actionStats then
		aoe.Transparency = 1
		return
	end

	local maxRange = actionStats.Range
	local radius = actionStats.Radius
	if not maxRange or not radius then
		aoe.Transparency = 1
		return
	end
	
	local maxRange = stats[baseAction].Range
	local radius = stats[baseAction].Radius

	if not maxRange or not radius then
		-- weapon properties not yet cached
		aoe.Transparency = 1
		return
	end

	-----------------------------------------------
	-- CALCULATE AIM
	-----------------------------------------------
	local hitPos, inst, dir = Targeting:GetAim(maxRange)
	local ground = GroundResolver.resolve(hitPos)
	local pos = ground.Position
	local posNormal = ground.Normal
	local Cf = GroundResolver.buildAlignedCFrame(pos + Vector3.new(0, 0.1, 0), posNormal)
	if not hitPos then
		aoe.Transparency = 1
		return
	end


	-----------------------------------------------
	-- AOE PREVIEW UPDATE
	-----------------------------------------------
	aoe.Size = Vector3.new(0.1, radius * 2, radius * 2)
	aoe.CFrame = Cf	* CFrame.Angles(0, 0, math.rad(90))
	aoe.Transparency = 0
end)

local GeneralSpawnLogic = {}
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local npcPoolManager = require(game.ServerScriptService.Scripts:WaitForChild("NpcPoolManager"))
local collisionGroupManager = require(game.ServerScriptService.Scripts:WaitForChild("CollisionGroupManager"))

local DEBUG = false
local DEBUG_LIFETIME = 2
local spawnCooldowns = {} -- [player] = time

local MIN_DISTANCE = 22
local MAX_DISTANCE = 35
local MAX_ATTEMPTS = 40
local DOWNCAST_HEIGHT = 60
local DOWNCAST_LENGTH = 200
local grassTopY = -1

-----------------------------------------------------------
-- Correct SpawnBoundary Interpretation
-----------------------------------------------------------
local spawnBoundary = Workspace.Invisible:WaitForChild("SpawnBoundary")
local boundaryCenter = spawnBoundary.Position
local boundaryRadius = spawnBoundary.Size.Y / 2  -- ✔ Y is the diameter axis

local boundaryDome = Workspace.Invisible:WaitForChild("BoundaryDome")

-----------------------------------------------------------
-- Debug helpers
-----------------------------------------------------------
local function debugSphere(position, color, size)
	if not DEBUG then return end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size,size,size)
	p.Color = color
	p.Anchored = true
	p.Transparency = 0.8
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Position = position
	p.Parent = Workspace.DebugLines
	game:GetService("Debris"):AddItem(p, DEBUG_LIFETIME)
end

local function debugLine(a, b, color)
	if not DEBUG then return end
	local dist = (b - a).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 0.8
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = Vector3.new(0.2, 0.2, dist)
	p.CFrame = CFrame.new(a, b) * CFrame.new(0, 0, -dist/2)
	p.Parent = Workspace.DebugLines
	game:GetService("Debris"):AddItem(p, DEBUG_LIFETIME)
end

-----------------------------------------------------------
-- Compute spawn ring position around player
-----------------------------------------------------------
local function getSpawnPosAroundPlayer(player)
	local char = player.Character
	if not char or not char.PrimaryPart then return nil end

	local rootPos = char.PrimaryPart.Position

	for attempt = 1, MAX_ATTEMPTS do

		-- 1. Angle + distance
		local theta = math.random() * math.pi * 2
		local dist = math.random(MIN_DISTANCE, MAX_DISTANCE)

		-- 2. Raw ring spawn in X/Z
		local rawPos = rootPos + Vector3.new(
			math.cos(theta) * dist,
			0,
			math.sin(theta) * dist
		)

		debugSphere(rawPos, Color3.fromRGB(255,255,0), 1.5)
		debugLine(rootPos, rawPos, Color3.fromRGB(50,50,255))

		-----------------------------------------------------------
		-- 3. Cylinder boundary check (correct: X/Z plane)
		-----------------------------------------------------------
		local dx = rawPos.X - boundaryCenter.Y
		local dz = rawPos.Z - boundaryCenter.Z
		local distXZ = math.sqrt(dx*dx + dz*dz)

		if distXZ > (boundaryRadius - 2) then
			debugSphere(rawPos, Color3.fromRGB(255,140,0), 2)
			continue
		end

		-----------------------------------------------------------
		-- 4. Obstacle check
		-----------------------------------------------------------
		local blocked = false
		
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {
			spawnBoundary,
			boundaryDome,
			Workspace.DebugLines,
		}

		Workspace:GetPartBoundsInRadius(rawPos, 3, params)
		
		local blocked = false
		local parts = Workspace:GetPartBoundsInRadius(rawPos, 3, params)

		if #parts > 0 then
			blocked = true
		end


		-----------------------------------------------------------
		-- 5. Raycast for ground
		-----------------------------------------------------------
		local downOrigin = rawPos + Vector3.new(0, DOWNCAST_HEIGHT, 0)
		local DebugLinesFodler = Workspace:WaitForChild("DebugLines")
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {
			player.Character,
			boundaryDome,
			table.unpack(DebugLinesFodler:GetChildren())
		}

		local result = Workspace:Raycast(downOrigin, Vector3.new(0,-DOWNCAST_LENGTH,0), params)

		local finalY = result and result.Position.Y or grassTopY

		-----------------------------------------------------------
		-- 6. Final spawn
		-----------------------------------------------------------
		local finalPos = Vector3.new(rawPos.X, finalY, rawPos.Z)

		debugSphere(finalPos, Color3.fromRGB(0,255,0), 2.2)

		return finalPos
	end

	spawnCooldowns[player] = tick() + 0.5 -- short, per-player cooldown
	return nil

end

-----------------------------------------------------------
-- Spawn API
-----------------------------------------------------------
function GeneralSpawnLogic.spawn(player, category, parentFolder, specificType)
	local cooldown = spawnCooldowns[player]
	if cooldown and tick() < cooldown then
		return
	end

	
	local spawnPos = getSpawnPosAroundPlayer(player)
	if not spawnPos then
	--	warn("No valid spawn point found.")
		return
	end

	local npc = npcPoolManager.getNpc(parentFolder, specificType)
	if not npc then return end

	npc:PivotTo(CFrame.new(spawnPos))
	collisionGroupManager.setCollisionGroup(npc, parentFolder)

	return npc
end

return GeneralSpawnLogic

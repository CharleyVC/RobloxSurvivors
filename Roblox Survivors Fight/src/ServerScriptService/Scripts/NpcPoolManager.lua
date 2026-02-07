-- NpcPoolManager ModuleScript

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local collisionGroupManager = require(game.ServerScriptService.Scripts:WaitForChild("CollisionGroupManager"))

local NpcPoolManager = {}

-- NPC Pools for different enemy types
local npcPools = {}


-- Initialize the pool for a specific enemy type
function NpcPoolManager.initializePool(enemyType, npcModel, poolSize)
	if not npcPools[enemyType] then
		npcPools[enemyType] = {}
	end

	for i = 1, poolSize do
		local npc = npcModel:Clone()
		npc.Parent = ServerStorage -- Store inactive NPCs in ServerStorage
		table.insert(npcPools[enemyType], npc)
	end
end

function NpcPoolManager.getNpc(enemyType, selectedNPC)
	if not npcPools[enemyType] or #npcPools[enemyType] == 0 then
		warn("NPC pool for type '" .. enemyType .. "' is empty! Consider increasing the pool size.")
		return nil
	end

	-- Find the correct NPC in the pool based on selectedNPC attributes
	for i, npc in ipairs(npcPools[enemyType]) do
		if npc.Name == selectedNPC then
			table.remove(npcPools[enemyType], i) -- Remove from pool
			npc.Parent = Workspace.Enemies -- Move NPC to the Workspace
			collisionGroupManager.setCollisionGroup(npc, "Enemies")
			
			return npc
		end
	end

	warn("No matching NPC found in the pool for selected NPC:", selectedNPC)
	return nil
end

-- Reset an NPC before returning it to the pool
function NpcPoolManager.resetNpcForReuse(npc)
	-- Ensure the PrimaryPart exists
	local primaryPart = npc:WaitForChild("HumanoidRootPart")
	if primaryPart then
		npc.PrimaryPart = primaryPart -- Set the PrimaryPart
	else
		warn("NPC model is missing a PrimaryPart. Cannot reset!")
		return
	end
	npc:SetPrimaryPartCFrame(CFrame.new(Vector3.new(0, -1000, 0))) -- Move out of visible range
	-- Reset NPC properties
	for _, descendant in ipairs(npc:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = true
			descendant.Velocity = Vector3.zero
		elseif descendant:IsA("Humanoid") then
			descendant.Health = descendant.MaxHealth -- Reset health
		end
	end

	npc.Parent = ServerStorage -- Store it back in ServerStorage
end

-- Return an NPC to the pool
function NpcPoolManager.returnNpc(enemyType, npc)
	if not npcPools[enemyType] then
		warn("No pool exists for enemy type '" .. enemyType .. "'. NPC will not be recycled.")
		return
	end

	-- Ensure the NPC is no longer active
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		warn("Attempted to return an NPC that is still alive.")
		return
	end

	-- Reset NPC for reuse
	NpcPoolManager.resetNpcForReuse(npc)
	table.insert(npcPools[enemyType], npc)
end
return NpcPoolManager

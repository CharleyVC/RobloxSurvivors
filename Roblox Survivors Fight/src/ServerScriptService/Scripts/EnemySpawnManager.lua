local EnemySpawnManager = {}
local players = game:GetService("Players") -- Manages players in the game
local runService = game:GetService("RunService")
local npcPoolManager = require(game.ServerScriptService.Scripts:WaitForChild("NpcPoolManager"))
local playerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))
local generalSpawnLogic = require(game.ServerScriptService.Scripts:WaitForChild("GeneralSpawnLogic"))
local collisionGroupManager = require(game.ServerScriptService.Scripts:WaitForChild("CollisionGroupManager"))
local difficultyManager = require(game.ServerScriptService.Scripts:WaitForChild("DifficultyManager"))
local npcAnimMonitor = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("MonitorMovement")
local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")
local deathAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("DeathAnim")
local goldSpawn = require(game.ReplicatedStorage:WaitForChild("GoldSpawn"))

EnemySpawnManager._started = EnemySpawnManager._started or false
EnemySpawnManager._conns = EnemySpawnManager._conns or {}


local function getTables(npc)
	local propertiesScript = npc:FindFirstChild("Properties")
	if propertiesScript and propertiesScript:IsA("ModuleScript") then
		local _table = require(propertiesScript)
		local animTable = _table.animTable
		local propTable = _table.propTable
		return animTable, propTable
	end
	return nil -- Return nil if the script is not found or invalid
end

local spawnConfig = {
	BasicEnemy = {BaseRate = 2.0, TargetRate = 0.5, BaseMax = 30, TargetMax = 300, SpawnChance = 0.8},
	RangedEnemy = {BaseRate = 2.0, TargetRate = 0.5, BaseMax = 1, TargetMax = 5, SpawnChance = 0.5},
	EliteEnemy = {BaseRate = 5.0, TargetRate = 1.0, BaseMax = 1, TargetMax = 5, SpawnChance = 0.5},
	BossEnemy = {BaseRate = 10.0, TargetRate = 2.0, BaseMax = 1, TargetMax = 5, SpawnChance = 0.05},
}

local activeEnemies = {} -- Track currently active enemies
local activeRanged = {}
local activeElites = {}
local activeBosses = {}

-- Mapping table for prefixes to active tables
local activeTables = {
	Basic = activeEnemies,
	Ranged = activeRanged,
	Elite = activeElites,
	Boss = activeBosses
}
-- Map all suffixes to Actor
local actorMapping = {
	Zombie = "ActorZombie", 
	-- Add more mappings if needed
}

-----------------------------------------------------------
-- ACTIVE ENEMY CLEANUP (INDUSTRY SAFETY NET)
-----------------------------------------------------------
local function cleanupActiveTable(t)
	for i = #t, 1, -1 do
		local data = t[i]
		if not data
			or not data.enemy
			or not data.enemy.Parent
			or not data.humanoid
			or data.humanoid.Health <= 0 then
			table.remove(t, i)
		end
	end
end



local function iKDestroy(enemy)
	-- Get the IKControl object from the enemy
	local ikArm = enemy:FindFirstChild("ikArm")
	local ikHead = enemy:FindFirstChild("ikHead")
	if ikArm then
		ikArm:Destroy()
	end
	if ikHead then
		ikHead:Destroy()
	end
end

local function iKCreate(enemy)
	if not enemy then return end

	local humanoid = enemy:FindFirstChild("Humanoid")
	if not humanoid then return end

	local arms = {
		Left = {
			ChainRoot = enemy:FindFirstChild("LeftUpperArm"),
			EndEffector = enemy:FindFirstChild("LeftHand"),
		},
		Right = {
			ChainRoot = enemy:FindFirstChild("RightUpperArm"),
			EndEffector = enemy:FindFirstChild("RightHand"),
		},
	}

	local body = {
		Head = {
			ChainRoot = enemy:FindFirstChild("Head"),
			EndEffector = enemy:FindFirstChild("Head"),
		},
		Torso = {
			ChainRoot = enemy:FindFirstChild("UpperTorso"),
			EndEffector = enemy:FindFirstChild("Head"),
		},
	}

	local selectedArm = math.random(1, 2) == 1 and arms.Left or arms.Right
	if not selectedArm.ChainRoot or not selectedArm.EndEffector then return end

	-- Create IKControl for the arm (no Target yet – client will set it)
	local ikArm = Instance.new("IKControl")
	ikArm.Type = Enum.IKControlType.Position
	ikArm.ChainRoot = selectedArm.ChainRoot
	ikArm.EndEffector = selectedArm.EndEffector
	ikArm.Target = nil
	ikArm.Weight = 0.8
	ikArm.Parent = humanoid
	ikArm.Name = "ikArm"

	local selectedBody = math.random(1, 2) == 1 and body.Head or body.Torso
	if not selectedBody.ChainRoot or not selectedArm.EndEffector then return end

	local ikHead = Instance.new("IKControl")
	ikHead.Type = Enum.IKControlType.Position
	ikHead.ChainRoot = selectedBody.ChainRoot
	ikHead.EndEffector = selectedBody.EndEffector
	ikHead.Target = nil
	ikHead.Weight = 0.1
	ikHead.Parent = humanoid
	ikHead.Name = "ikHead"
end



local npcDeathCount = 0 -- Track the number of NPCs that have died
local maxDeathsPerRound = 20 -- Number of NPC deaths required to increase the round

local function calculateSpawnRate(baseRate, targetRate, currentRound, maxRound)
	-- Calculate the scaling factor
	local scalingFactor = (targetRate / baseRate) ^ (1 / (maxRound - 1))
	-- Calculate the spawn rate for the current round
	return baseRate * (scalingFactor ^ (currentRound - 1))
end

local function calculateMaxEnemies(baseMax, targetMax, currentRound, maxRound)
	-- Calculate the scaling factor
	local scalingFactor = (targetMax / baseMax) ^ (1 / (maxRound - 1))
	-- Calculate the max enemies for the current round
	return math.ceil(baseMax * (scalingFactor ^ (currentRound - 1)))
end

local function assignActorToEnemy(enemy, specificObject)
	-- Get the enemy's suffix by finding the last word (e.g., "Zombie" in "RegZombie")
	local suffix = enemy.Name:match(".(%u%a+)")
	if not suffix then
		warn("No suffix found for enemy:", enemy.Name)
		return
	end

	-- Find the matching Actor name from the mapping
	local actorName = actorMapping[suffix]
	if not actorName then
		warn("No Actor mapping found for suffix:", suffix)
		return
	end

	-- Get the Actor template from ServerStorage
	local actorTemplate = game.ReplicatedStorage.Data.EnemyActors[specificObject]:FindFirstChild(actorName)
	if not actorTemplate then
		warn("Actor template not found:", actorName)
		return
	end

	-- Duplicate the Actor and parent it to the enemy
	local newActor = actorTemplate:Clone()
	newActor.Parent = enemy
end

-- Set death logic
function EnemySpawnManager.death(player, humanoid, specificObject, enemy)
	local goldDropped = false -- Flag to prevent multiple gold drops
	humanoid.Died:Connect(function()
		if goldDropped then return end -- Prevent duplicate calls
		goldDropped = true
		-- Capture the NPC's position before it's returned to the pool
		local npcPosition = nil
		if enemy.PrimaryPart then
			npcPosition = enemy.PrimaryPart.Position
		else
			npcPosition = enemy:GetModelCFrame().Position -- Fallback if no PrimaryPart
		end

		if npcPosition then
			if math.random(1, 100) <= 30 then
				goldSpawn.dropGold(npcPosition)
			end
		else
			warn("Failed to determine NPC position for gold drop.")
		end
		-- Remove from activeEnemies

		if specificObject then
			local prefix = specificObject:match("(.*)Enemy")
			if prefix and activeTables[prefix] then
				for i, data in ipairs(activeTables[prefix]) do
					if data.enemy == enemy then
						activeTables[prefix][i] = activeTables[prefix][#activeTables[prefix]]
						activeTables[prefix][#activeTables[prefix]] = nil
						break
					end
				end
			end
		end

		local animTable, propTable = getTables(enemy)
		local exp = propTable.exp

		playerStats.add(player,"RunExperience", exp)
		deathAnimEvent:FireAllClients(enemy)
		iKDestroy(enemy)
		npcPoolManager.returnNpc(specificObject, enemy)
		npcDeathCount +=1
		if npcDeathCount >= maxDeathsPerRound then
			difficultyManager.incrementRound()
			npcDeathCount = 0
		end
	end)
end




-- Function to spawn an enemy at a given position
function EnemySpawnManager.spawnEnemy(player, category, parentFolder, specificType)
	if workspace:GetAttribute("IsPaused") == true then return end
	
	local enemy, character = generalSpawnLogic.spawn(player, category, parentFolder, specificType)
	if not enemy then
		return -- or continue, depending on loop
	end

	local humanoid = enemy:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	local animTable, propTable = getTables(enemy)
	animTable.target = nil


	vfxEvent:FireAllClients("SpawnVFX", enemy.PrimaryPart.Position)

	local baseStats = {
		health = propTable.health,
		walkSpeed = propTable.walkSpeed,
		damage = propTable.damage,
		exp = propTable.exp
	}

	-- Adjust stats based on difficulty
	local adjustedStats = difficultyManager.difficultyStatMuliplier(baseStats)

	-- Apply adjusted stats to NPC
	local humanoid = enemy:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.MaxHealth = adjustedStats.health
		humanoid.Health = humanoid.MaxHealth
		humanoid.WalkSpeed = adjustedStats.walkSpeed
	end
	propTable.health = adjustedStats.health
	propTable.damage = adjustedStats.damage
	propTable.walkSpeed = adjustedStats.walkSpeed
	propTable.exp = adjustedStats.exp

	if parentFolder then
		local prefix = parentFolder:match("(.*)Enemy")
		if prefix and activeTables[prefix] then
			table.insert(activeTables[prefix], {enemy = enemy, humanoid = humanoid})
			EnemySpawnManager.MonitorMovement(enemy, animTable)
		end
	end

	if enemy.Name then
		local suffix = enemy.Name:match(".(%u%a+)")
		if suffix == "Zombie" then
			iKCreate(enemy)
			collisionGroupManager.setCollisionGroup(enemy, "Enemies")
		end
		
	end


	assignActorToEnemy(enemy, parentFolder)
	EnemySpawnManager.death(player, humanoid, parentFolder, enemy)

	for i, v in enemy:GetChildren() do
		if v:IsA("BasePart") then
			v.Anchored = true
		end
	end

	for i, v in enemy:GetChildren() do
		if v:IsA("BasePart") then
			v.Anchored = false
		end
	end


	return enemy
end

function EnemySpawnManager.startSpawning(config)
	-- HARD GUARD: prevents double loops + duplicate connections
	if EnemySpawnManager._started then
		warn("[EnemySpawnManager] startSpawning ignored (already started)")
		return
	end
	EnemySpawnManager._started = true

	config = config or spawnConfig

	local MAX_SPAWNS_PER_TICK = 3
	local shouldSpawn = true

	-- Ensure we don't stack connections if something ever toggles start/stop
	for _, c in pairs(EnemySpawnManager._conns) do
		if c then c:Disconnect() end
	end
	table.clear(EnemySpawnManager._conns)

	-- Stop spawning on server shutdown (bind once per start)
	game:BindToClose(function()
		shouldSpawn = false
		EnemySpawnManager._started = false
	end)

	-- Stop spawning when all players leave (store connection so it can't stack)
	EnemySpawnManager._conns.playerRemoving = players.PlayerRemoving:Connect(function(_player)
		if #players:GetPlayers() == 0 then
			shouldSpawn = false
			EnemySpawnManager._started = false
		end
	end)

	-- Spawn loop
	task.spawn(function()
		while shouldSpawn do
			local currentRound = difficultyManager.getRound()

			-- Budget is per tick, so decrement it when we actually spawn
			local spawnBudget = MAX_SPAWNS_PER_TICK

			for enemyType, settings in pairs(config) do
				if spawnBudget <= 0 then break end

				-- Skip Elite/Boss based on difficulty
				local diff = difficultyManager.getDifficulty()
				if enemyType == "EliteEnemy" and diff < 3 then
					continue
				end
				if enemyType == "BossEnemy" and diff < 5 then
					continue
				end

				local maxEnemies = calculateMaxEnemies(settings.BaseMax, settings.TargetMax, currentRound, 30)
				local prefix = enemyType:match("(.*)Enemy")

				cleanupActiveTable(activeTables[prefix])

				-- If we're at cap, don't bother rolling chance
				if #activeTables[prefix] >= maxEnemies then
					continue
				end

				-- One roll per enemyType per tick (not per player)
				if math.random() <= settings.SpawnChance then
					for _, player in ipairs(players:GetPlayers()) do
						if spawnBudget <= 0 then break end
						if player.Character and player.Character.PrimaryPart then
							local npc = difficultyManager.selectNPCByType(enemyType)
							if npc then
								EnemySpawnManager.spawnEnemy(player, "Enemy", enemyType, npc.Name)
								spawnBudget -= 1
							end
						end
					end
				end
			end

			task.wait(0.2)
		end

		-- loop ended
		EnemySpawnManager._started = false
	end)
end


-- Handle spawner event for boss spawning
game.ReplicatedStorage.BindableEvents.SpawnerEvent.Event:Connect(function(npcList)
	local bossNPC = difficultyManager.selectBoss()
	if bossNPC then
		for _, player in ipairs(players:GetPlayers()) do
			if player.Character and player.Character.PrimaryPart then
				local newBoss = EnemySpawnManager.spawnEnemy(player, "Enemy", "BossEnemy", bossNPC.Name)
			end
		end
	end
end)

function EnemySpawnManager.MonitorMovement(npcModel, animTable)
	npcAnimMonitor:FireAllClients(npcModel, animTable)
end

return EnemySpawnManager
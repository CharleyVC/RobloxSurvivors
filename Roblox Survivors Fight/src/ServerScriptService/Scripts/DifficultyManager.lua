local DifficultyManager = {}

local spawnerEvent = game.ReplicatedStorage.BindableEvents:WaitForChild("SpawnerEvent")
local difficultyIncrement = game.ReplicatedStorage.RemoteEvents:WaitForChild("DifficultyIncrement")
local players = game:GetService("Players") -- Manages players in the game

local basicNpcList = game.ReplicatedStorage.Data.Enemies.BasicEnemy:GetChildren()
local rangedNpcLit = game.ReplicatedStorage.Data.Enemies.RangedEnemy:GetChildren()
local eliteNpcs = game.ReplicatedStorage.Data.Enemies.EliteEnemy:GetChildren()
local bossNpcList = game.ReplicatedStorage.Data.Enemies.BossEnemy:GetChildren()

local difficulty = 1 -- Current difficulty level
local round = 1 -- Start at round 1
local difficultyRange = 3 -- Randomization range for difficulty scaling

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

function DifficultyManager.getRound()
	return round
end

function DifficultyManager.getDifficulty()
	return difficulty
end

-- Sort NPCs based on difficulty (health and walk speed)
local function initializeNPCList(list)
	table.sort(list, function(a, b)
		local aAnim, aProps = getTables(a)
		local bAnim, bProps = getTables(b)
		if aProps and bProps then
			return (aProps.health * 2 + aProps.walkSpeed + aProps.damage * 1.25) <
				(bProps.health * 2 + bProps.walkSpeed + bProps.damage * 1.25)
		end
		return false
	end)
	return list
end

local basicNpcs = initializeNPCList(basicNpcList)
local rangedNpcs = initializeNPCList(rangedNpcLit)
local eliteNpcs = initializeNPCList(eliteNpcs)
local bossNpcs = initializeNPCList(bossNpcList)

function DifficultyManager.initialize()
	local basicNpcs = initializeNPCList(basicNpcList)
	local rangedNpcs = initializeNPCList(rangedNpcLit)
	local eliteNpcs = initializeNPCList(eliteNpcs)
	local bossNpcs = initializeNPCList(bossNpcList)
end



function DifficultyManager.selectNPCByType(enemyType)
	local npcPool

	-- Select the correct pool based on the enemy type
	if enemyType == "BasicEnemy" then
		npcPool = basicNpcs
	elseif enemyType == "EliteEnemy" then
		npcPool = eliteNpcs
	elseif enemyType == "RangedEnemy" then
		npcPool = rangedNpcs
	elseif enemyType == "BossEnemy" then
		if difficulty < 5 then -- Replace 10 with the required difficulty level for bosses
			return nil -- Skip boss spawning if difficulty is not high enough
		end
		npcPool = bossNpcs
	else
		warn("Invalid enemy type:", enemyType)
		return nil
	end

	-- Randomize selection within a difficulty range
	local randomValue = math.random(-difficultyRange, difficultyRange)
	local difficultyIndex = math.clamp(difficulty + randomValue, 1, #npcPool)

	-- Return the selected NPC
	return npcPool[difficultyIndex]
end

---- Update the GUI for all players
--local function updateDifficultyGui(difficulty)
--	for _, player in ipairs(players:GetPlayers()) do
--		local playerGui = player:FindFirstChild("PlayerGui")
--		if playerGui then
--			local difficultyLabel = playerGui:FindFirstChild("DifficultyGui") and playerGui.DifficultyGui:FindFirstChild("DifficultyLabel")
--			if difficultyLabel then
--				difficultyLabel.Text = "Difficulty: " .. difficulty
--			end
--		end
--	end
--end

-- Function to increment round
function DifficultyManager.incrementRound()
	round += 1
	print("Round incremented! Current round:", round)

	-- Every 5 rounds, spawn a boss
	if round % 2 == 0 then
		spawnerEvent:Fire(bossNpcs)
		difficulty += 1
		difficultyIncrement:FireAllClients(difficulty)
		print("Boss round! Spawning boss enemy.")
	end
end

-- Adjust NPC stats based on difficulty
function DifficultyManager.difficultyStatMuliplier(baseStats)

	-- Scaling multipliers
	local healthMultiplier = 1 + (difficulty - 1) * 0.04
	local damageMultiplier = 1 + (difficulty - 1) * 0.02
	local speedMultiplier = 1 + (difficulty - 1) * 0.01
	local expMultiplier = 1  + (difficulty - 1) * 0.05

	return {
		health = baseStats.health * healthMultiplier,
		walkSpeed = baseStats.walkSpeed * speedMultiplier,
		damage = baseStats.damage * damageMultiplier,
		exp = baseStats.exp * expMultiplier
	}
end

-- NPC selection logic
function DifficultyManager.selectNPC()
	local randomValue = math.random(-difficultyRange, difficultyRange)
	local difficultyIndex = math.clamp(difficulty + randomValue, 1, #basicNpcs)
	return basicNpcs[difficultyIndex]
end

-- Boss NPC selection logic
function DifficultyManager.selectBoss()
	local randomValue = math.random(-difficultyRange, difficultyRange)
	local difficultyIndex = math.clamp(difficulty + randomValue, 1, #bossNpcs)
	return bossNpcs[difficultyIndex]
end

-- Stop the DifficultyManager
function DifficultyManager:Stop()
	-- Implement logic to stop tasks if needed
	print("Stopping DifficultyManager")
end

return DifficultyManager
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local TeleportService = game:GetService("TeleportService")


-- Require modules
local NpcPoolManager = require(game.ServerScriptService.Scripts:WaitForChild("NpcPoolManager"))
local MagnetManager = require(game.ServerScriptService.Scripts:WaitForChild("MagnetManager"))
local ProfileManager = require(game.ServerScriptService.Scripts:WaitForChild("ProfileManager"))
local collisionGroupManager = require(game.ServerScriptService.Scripts:WaitForChild("CollisionGroupManager"))
local DifficultyManager = require(game.ServerScriptService.Scripts:WaitForChild("DifficultyManager"))
local enemySpawnManager = require(game.ServerScriptService.Scripts:WaitForChild("EnemySpawnManager"))
local visibilityMap = require(game.ServerScriptService.Scripts.PathfindingModules:WaitForChild("VisibilityMap"))
local PlayerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))
local teleportData = game:GetService("TeleportService"):GetLocalPlayerTeleportData()


-- Optional safety check


local DataStoreService = game:GetService("DataStoreService")
local visibilityStore = DataStoreService:GetDataStore("VisibilityMap")

local function initializeGame()
	-- Setup collision groups when the game starts
	collisionGroupManager.setupCollisionGroups()
	

	-- Initialize NPC Pools
	NpcPoolManager.initializePool("BasicEnemy", game.ReplicatedStorage.Data.Enemies.BasicEnemy.RegZombie, 300)
	NpcPoolManager.initializePool("BasicEnemy", game.ReplicatedStorage.Data.Enemies.BasicEnemy.SlowZombie, 300)
	NpcPoolManager.initializePool("BasicEnemy", game.ReplicatedStorage.Data.Enemies.BasicEnemy.StrongZombie, 300)
	NpcPoolManager.initializePool("EliteEnemy", game.ReplicatedStorage.Data.Enemies.EliteEnemy.FastZombie, 30)
	NpcPoolManager.initializePool("RangedEnemy", game.ReplicatedStorage.Data.Enemies.RangedEnemy.ArcherSkeleton, 20)
	NpcPoolManager.initializePool("BossEnemy", game.ReplicatedStorage.Data.Enemies.BossEnemy.BossZombie, 20)

	-- Add existing tagged objects
	for _, obj in ipairs(CollectionService:GetTagged("Invisible")) do
		collisionGroupManager.setCollisionGroup(obj, "InvisibleObjects")
	end
	
	-- Add existing tagged objects
	for _, obj in ipairs(CollectionService:GetTagged("World")) do
		collisionGroupManager.setCollisionGroup(obj, "World")
	end
	
	for _, part in ipairs(workspace.Map:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "World"
		end
	end
	

	---- Preload assets
	--for _, asset in ipairs(game.ReplicatedStorage:GetChildren()) do
	--	if asset:IsA("ModuleScript") then
	--		require(asset) -- Load assets like animations, tools, etc.
	--	end
	--end
	
	--for _, asset in ipairs(game.ServerScriptService.Scripts:GetChildren()) do
	--	if asset:IsA("ModuleScript") then
	--		require(asset) -- Load assets like animations, tools, etc.
	--	end
	--end

	
	
	-- Configure game settings
	Workspace.Gravity = 196.2 -- Default gravity
	local PlayersFolder = Instance.new("Folder", Workspace)
	PlayersFolder.Name = "Players"

	local Remains = Instance.new("Folder", Workspace)
	Remains.Name = "Remains"
	
	local Objects = Instance.new("Folder", Workspace)
	Objects.Name = "Objects"
	
	local collectiblesFolder = Instance.new("Folder", workspace)
	collectiblesFolder.Name = "Collectibles"
	
	--visibilityMap.load()
	local mapGrid = {}
	local map = workspace.Map:FindFirstChild("Baseplate")
	visibilityMap.precompute(map)
	---- If mapGrid is empty, recompute and save
	--if next(mapGrid) == nil then
	--	visibilityMap.precompute(map)
	--	visibilityMap.save()
	--end
	debug.profilebegin("Magnet")
	-- Run the magnet system for gold coins
	MagnetManager.listenForMagnet()
	
	debug.profileend()
	Players.PlayerAdded:Connect(function(player)
		-- Wait for profile
		local profile = ProfileManager.GetProfile(player)
		if not profile then
			for _ = 1, 40 do
				task.wait(0.05)
				profile = ProfileManager.GetProfile(player)
				if profile then break end
			end
		end

		if not profile then
			player:Kick("Profile not loaded")
			return
		end

		-- ✅ CORRECT teleport data access
		local joinData = player:GetJoinData()
		local teleportData = joinData and joinData.TeleportData

		if teleportData and teleportData.EquippedWeapon then
			print("[TeleportData] EquippedWeapon:", teleportData.EquippedWeapon)
		end

		player.CharacterAdded:Connect(function(character)
			local spawnPosition = workspace.Map:FindFirstChild("SpawnLocation")
			if spawnPosition then
				local hrp = character:WaitForChild("HumanoidRootPart")
				character:SetAttribute("IsInvulnerable", true)
				hrp.CFrame = spawnPosition.CFrame
				task.delay(5, function()
					if character.Parent then
						character:SetAttribute("IsInvulnerable", false)
					end
				end)
			end

			-- Reset run stats + equip weapon
			PlayerStats.initializeStats(player, profile)
		end)

		player:LoadCharacter()
		
		
		task.delay(10, function()
			if player.Parent then
				enemySpawnManager.startSpawning(nil)
			end
		end)
	end)


		

end

-- Run the initialization
initializeGame()


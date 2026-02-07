local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local MagnetManager = require(game.ServerScriptService.Scripts:WaitForChild("MagnetManager"))
local ProfileManager = require(game.ServerScriptService.Scripts:WaitForChild("ProfileManager"))
local SessionService = require(game.ServerScriptService.Session:WaitForChild("SessionService"))
local PlayerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))


local function initializeGame()
	-- Preload assets
	for _, asset in ipairs(ReplicatedStorage:GetChildren()) do
		if asset:IsA("ModuleScript") then
			require(asset) -- Load assets like animations, tools, etc.
		end
	end
	-- Configure game settings
	Workspace.Gravity = 196.2 -- Default gravity
	
	local Objects = Instance.new("Folder", Workspace)
	Objects.Name = "Objects"

	local collectiblesFolder = Instance.new("Folder", workspace)
	collectiblesFolder.Name = "Collectibles"

	-- Run the magnet system for gold coins
	MagnetManager.listenForMagnet()
	Players.PlayerAdded:Connect(function(player)
		-- Connect CharacterAdded FIRST so we never miss the first spawn
		player.CharacterAdded:Connect(function(character)
			-- Move to spawn
			local spawnPosition = workspace.Map:FindFirstChild("SpawnLocation")
			if spawnPosition then
				local hrp = character:WaitForChild("HumanoidRootPart")
				hrp.CFrame = spawnPosition.CFrame
			else
				warn("SpawnLocation not found in the workspace!")
			end

			-- Get profile and initialize run stats (THIS is the missing reset)
			local profile = ProfileManager.GetProfile(player)
			if not profile then
				warn("[Initializer] Profile not loaded yet for", player.Name)
				return
			end

			PlayerStats.initializeStats(player, profile)
		end)

		-- Now load the character
		player:LoadCharacter()
	end)

end

-- Run the initialization
initializeGame()


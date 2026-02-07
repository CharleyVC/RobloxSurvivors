local playerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))
local profileManager = require(game.ServerScriptService.Scripts:WaitForChild("ProfileManager"))
local PlayerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))
local teleportService = game:GetService("TeleportService")
local deathGuiHandler = require(game.ServerScriptService.Scripts:WaitForChild("DeathGuiHandler"))
local marketplaceService = game:GetService("MarketplaceService")

-- Destination Place ID
local destinationPlaceId = 18524434708

-- Developer Product ID for revive
local reviveProductId = 1234567890 -- Replace with your Developer Product ID

-- Retry logic to get the player's profile
local function getPlayerProfile(player)
	for _ = 1, 10 do -- Retry up to 10 times
		local profile = profileManager.GetProfile(player)
		if profile then
			return profile
		end
		task.wait(0.1) -- Wait 0.1 seconds before retrying
	end
	warn("Profile not found for player:", player.Name)
	return nil
end

-- Function to handle player death
local function handlePlayerDeath(player, character, profile)
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		print(player.Name .. " has died!")

		-- Add run-specific Coins to persistent Coins
		local runCoins = character:GetAttribute("Coins") or 0
		profile.Data.Coins = (profile.Data.Coins or 0) + runCoins -- Add to banked coins

		-- Save best run score
		local runScore = character:GetAttribute("RunScore") or 0
		profile.Data.BestRunScore = math.max(profile.Data.BestRunScore, runScore)
		
		-- Respawn logic
		task.wait(3) -- Wait 5 seconds before respawning 
		
		-- Trigger GUI to offer revive or teleport
		deathGuiHandler.showDeathGui(player, function(action)
			if action == "revive" then
				-- Prompt player to purchase revive
				marketplaceService:PromptProductPurchase(player, reviveProductId)
			elseif action == "teleport" then
				local success, errorMessage = pcall(function()
					teleportService:TeleportAsync(destinationPlaceId, {player})
				end)
				if not success then
					warn("Teleport failed: " .. errorMessage)
				end
			end
		end)
	end)
end

-- Function to initialize player stats and respawn logic
local function initializePlayer(player)
	player.CharacterAdded:Connect(function(character)
		player.Character.Parent = game.Workspace:WaitForChild("Players")
		local profile = getPlayerProfile(player)
		if not profile then return end
		-- Initialize stats
		playerStats.initializeStats(player, profile)
		-- Handle death and respawn logic
		handlePlayerDeath(player, character, profile)
	end)
end


-- Connect PlayerAdded event
game.Players.PlayerAdded:Connect(function(player)
	initializePlayer(player)
end)

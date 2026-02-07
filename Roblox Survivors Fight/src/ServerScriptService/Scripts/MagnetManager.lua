local ReplicatedStorage = game:GetService("ReplicatedStorage")
local magnetEvent = ReplicatedStorage.RemoteEvents:WaitForChild("Magnet")
local playerStats = require(game.ServerScriptService.Scripts:WaitForChild("PlayerStats"))

local activeCollectibles = {} -- Track active collectibles to prevent duplication

-- Find magnet script in StarterPlayerScripts

local MagnetManager = {}

-- Generalized collection handler
function MagnetManager.handleCollection(player, collectible)
	if not player or not collectible or not collectible:IsA("Model") or not collectible.PrimaryPart then
		warn("Invalid player or collectible passed to handleCollection.")
		return
	end

	-- Check if the collectible is already owned
	if activeCollectibles[collectible] and activeCollectibles[collectible] ~= player then
		warn("Collectible is already being collected by another player.")
		return
	end

	activeCollectibles[collectible] = player -- Assign ownership

	-- Execute collection logic based on collectible type
	if collectible:GetAttribute("CollectibleType") == "Coin" then
		playerStats.add(player, "RunCoins", 1)
		
	elseif collectible:GetAttribute("CollectibleType") == "PowerUp" then
		print(player.Name .. " collected a PowerUp:", collectible:GetAttribute("EffectType"))
		-- Add logic to apply power-up effects
	else
		print(player.Name .. " collected an unknown collectible:", collectible.Name)
	end

	-- Destroy the collectible
	if collectible.Parent then
		collectible:Destroy()
	end

	activeCollectibles[collectible] = nil -- Remove from active list
end

-- Listens for MagnetEvent from clients
function MagnetManager.listenForMagnet()
	magnetEvent.OnServerEvent:Connect(function(player, collectible)
		MagnetManager.handleCollection(player, collectible)
	end)
end

return MagnetManager
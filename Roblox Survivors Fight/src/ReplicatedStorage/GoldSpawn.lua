local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinSpawnEvent = ReplicatedStorage.RemoteEvents:WaitForChild("GoldSpawn")

local goldSpawn = {}

function goldSpawn.dropGold(position)
	local dampingFactor = 0.9 -- Adjust for smoother deceleration
	local physicalProperties = PhysicalProperties.new(1, dampingFactor, 0.5)
	local collectiblesFolder = workspace:FindFirstChild("Collectibles") or Instance.new("Folder", workspace)
	collectiblesFolder.Name = "Collectibles"

	local goldCoin = game.ServerStorage.Meshes.Gold:WaitForChild("Gold Coin"):Clone()

	if not goldCoin.PrimaryPart then
		warn("Gold Coin is missing PrimaryPart.")
		return
	end

	-- Set the initial position and parent to the Collectibles folder
	goldCoin.PrimaryPart.Anchored = true
	goldCoin.PrimaryPart.Position = position
	goldCoin.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
	goldCoin.Parent = collectiblesFolder
	goldCoin.PrimaryPart.CustomPhysicalProperties = physicalProperties
	
	-- Add the "Collectible" attribute to identify it as a target
	goldCoin:SetAttribute("CollectibleType", "Coin")


	-- Notify clients for visual effects
	CoinSpawnEvent:FireAllClients(goldCoin)
	-- Use precise timing for item removal
	local spawnTime = tick()
	task.spawn(function()
		while tick() - spawnTime < 15 do
			task.wait(1) -- Check periodically
		end

		if goldCoin and goldCoin.Parent then
			goldCoin:Destroy()
		end
	end)
end
return goldSpawn

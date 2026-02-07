local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MAX_PLAYER_SPEED = 100 -- Maximum allowed player speed (studs/second)
local MAX_NPC_SPEED = 30 -- Maximum allowed NPC speed (studs/second)
local CHECK_INTERVAL = 0.5 -- Time between checks in seconds

local playerPositions = {}
local npcPositions = {}

-- Helper function to calculate distance
local function calculateDistance(pos1, pos2)
	return (pos1 - pos2).Magnitude
end

-- Helper function to log violations
local function logViolation(entity, reason)
	warn("[Anti-Teleport] Violation detected for " .. (entity.Name or "Unknown") .. ": " .. reason)
end

-- Track player movement
local function trackPlayer(player)
	player.CharacterAdded:Connect(function(character)
		local rootPart = character:WaitForChild("HumanoidRootPart", 10)
		if not rootPart then
			warn("[Anti-Teleport] HumanoidRootPart missing for player: " .. player.Name)
			return
		end

		playerPositions[player] = {lastPosition = rootPart.Position, lastCheck = tick()}

		local connection
		connection = RunService.Heartbeat:Connect(function()
			if not character.Parent then
				playerPositions[player] = nil -- Clean up player entry
				connection:Disconnect() -- Stop tracking when player leaves or dies
				return
			end

			local lastCheckData = playerPositions[player]
			if not lastCheckData then return end -- Ensure data exists before accessing

			local currentTick = tick()
			local timeDelta = currentTick - lastCheckData.lastCheck

			if timeDelta >= CHECK_INTERVAL then
				local currentPosition = rootPart.Position
				local distance = calculateDistance(lastCheckData.lastPosition, currentPosition)
				local speed = distance / timeDelta

				if speed > MAX_PLAYER_SPEED then
					logViolation(player, "Unrealistic speed detected (" .. speed .. " studs/second).")
				end

				-- Update player's position and time
				playerPositions[player] = {lastPosition = currentPosition, lastCheck = currentTick}
			end
		end)
	end)
end

-- Track NPC movement
local function trackNPC(npc)
	local rootPart = npc:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("[Anti-Teleport] HumanoidRootPart missing for NPC: " .. npc.Name)
		return
	end

	npcPositions[npc] = {lastPosition = rootPart.Position, lastCheck = tick()}

	local connection
	connection =    RunService.Heartbeat:Connect(function()
		if not npc.Parent then
			npcPositions[npc] = nil -- Clean up NPC entry
			connection:Disconnect() -- Stop tracking when NPC is removed
			return
		end

		local lastCheckData = npcPositions[npc]
		if not lastCheckData then return end -- Ensure data exists before accessing

		local currentTick = tick()
		local timeDelta = currentTick - lastCheckData.lastCheck

		if timeDelta >= CHECK_INTERVAL then
			local currentPosition = rootPart.Position
			local distance = calculateDistance(lastCheckData.lastPosition, currentPosition)
			local speed = distance / timeDelta

			if speed > MAX_NPC_SPEED then
				logViolation(npc, "Unrealistic speed detected (" .. speed .. " studs/second).")
				-- Optional: Reset NPC position
				--npc.PrimaryPart.Position = (lastCheckData.lastPosition)
			end

			-- Update NPC's position and time
			npcPositions[npc] = {lastPosition = currentPosition, lastCheck = currentTick}
		end
	end)
end

-- Monitor NPCs
local function monitorNPCs()
	local npcFolder = Workspace:FindFirstChild("Enemies")
	if not npcFolder then return end

	for _, npc in ipairs(npcFolder:GetChildren()) do
		if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then
			trackNPC(npc)
		end
	end

	npcFolder.ChildAdded:Connect(function(npc)
		if npc:IsA("Model") and npc:FindFirstChild("HumanoidRootPart") then
			trackNPC(npc)
		end
	end)

	npcFolder.ChildRemoved:Connect(function(npc)
		npcPositions[npc] = nil -- Clean up when NPC is removed
	end)
end

-- Monitor players
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(player)
	playerPositions[player] = nil -- Clean up when player leaves
end)

-- Start monitoring NPCs
monitorNPCs()

Workspace.ChildAdded:Connect(function(child)
	if child.Name == "Enemies" then
		monitorNPCs()
	end
end)

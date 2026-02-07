-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local portal = game.Workspace.Map.Portal.PortalField.Negativepart1
local openMenuEvent = ReplicatedStorage.RemoteEvents:WaitForChild("OpenRunMenu")
local closeMenuEvent = ReplicatedStorage.RemoteEvents:WaitForChild("CloseRunMenu")

-- Tunables
local PORTAL_RADIUS = 8          -- studs
local CHECK_INTERVAL = 0.25      -- seconds

local activePlayers = {} -- [player] = connection

local function startTracking(player, character)
	if activePlayers[player] then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	openMenuEvent:FireClient(player)

	local lastCheck = 0
	activePlayers[player] = RunService.Heartbeat:Connect(function(dt)
		lastCheck += dt
		if lastCheck < CHECK_INTERVAL then return end
		lastCheck = 0

		if not character.Parent or not hrp.Parent then
			closeMenuEvent:FireClient(player)
			activePlayers[player]:Disconnect()
			activePlayers[player] = nil
			return
		end

		local distance = (hrp.Position - portal.Position).Magnitude
		if distance > PORTAL_RADIUS then
			closeMenuEvent:FireClient(player)
			activePlayers[player]:Disconnect()
			activePlayers[player] = nil
		end
	end)
end

portal.Touched:Connect(function(otherPart)
	local character = otherPart.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	startTracking(player, character)
end)

-- Cleanup safety
Players.PlayerRemoving:Connect(function(player)
	if activePlayers[player] then
		activePlayers[player]:Disconnect()
		activePlayers[player] = nil
	end
end)

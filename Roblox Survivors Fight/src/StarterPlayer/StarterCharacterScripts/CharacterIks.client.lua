local runService = game:GetService("RunService")
local targeting = require(game.ReplicatedStorage.Controllers.Targeting)
local lookEvent = game.ReplicatedStorage.BindableEvents:WaitForChild("LookEvent")
local parts = {}

local function CharacterAdded(character)
	local ik = Instance.new("IKControl")
	ik.Type = Enum.IKControlType.LookAt
	ik.ChainRoot = character.UpperTorso
	ik.EndEffector = character.Head
	ik.Weight = 0
	ik.Parent = character.Humanoid
end

local function ikTarget(character,instance)
	local ik = character.Humanoid.IKControl
	ik.Target = instance
end

local function PlayerAdded(player)
	if player.Character ~= nil then CharacterAdded(player.Character) end
	player.CharacterAdded:Connect(CharacterAdded)
end

local function PlayerRemoving(player)
	parts[player] = nil
end

-- Detect when players are added and removed to create and destroy IK controls
for i, player in game.Players:GetPlayers() do PlayerAdded(player) end
game.Players.PlayerAdded:Connect(PlayerAdded)
game.Players.PlayerRemoving:Connect(PlayerRemoving)


for i, player in game.Players:GetPlayers() do
	local character = player.Character
	if character then
		lookEvent.Event:Connect(function(instance, direction)
			ikTarget(character, instance)
		end)
	end
end
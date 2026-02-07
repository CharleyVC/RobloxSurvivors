local Players = game:GetService("Players")

-- Create the leaderboard
Players.PlayerAdded:Connect(function(player)
	-- Add a leaderstats folder
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Add the HighestSessionScore stat
	local highestScore = Instance.new("IntValue")
	highestScore.Name = "High Score"
	highestScore.Value = 0
	highestScore.Parent = leaderstats

	-- Add the runScore stat
	local runScore = Instance.new("IntValue")
	runScore.Name = "Run Score"
	runScore.Value = 0
	runScore.Parent = leaderstats


end)

local highestSessionScore = {score = 0, playerName = ""}

-- Function to update the global leaderboard
local function updateGlobalLeaderboard(player, newScore)
	if newScore > highestSessionScore.score then
		highestSessionScore.score = newScore
		highestSessionScore.playerName = player.Name
		print(string.format("New highest session score: %d by %s", newScore, player.Name))
	end
end

-- Hook into player stats
game.Players.PlayerAdded:Connect(function(player)
	local leaderstats = player:WaitForChild("leaderstats")
	local highestScore = leaderstats:WaitForChild("High Score")

	-- Track changes to the player's highest score
	highestScore:GetPropertyChangedSignal("Value"):Connect(function()
		updateGlobalLeaderboard(player, highestScore.Value)
	end)
end)
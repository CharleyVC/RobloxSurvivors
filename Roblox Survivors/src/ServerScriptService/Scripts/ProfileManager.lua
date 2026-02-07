local Players = game:GetService("Players")
local ProfileStore = require(game.ServerScriptService.Scripts:WaitForChild("ProfileStore"))

local PLAYER_DATA_TEMPLATE = {
	Coins = 0,
	Experience = 0,
	Level = 1,
	Gems = 0,
	ReviveToken = 0,

	EquippedWeapon = "Fireball",

	UnlockedWeapons = {
		Fireball = true, -- default starter weapon
	},

	MetaUpgrades = {
		MagnetRange = 10,
		MaxStamina = 100,
		BaseAttackSpeed = 1,
		HealthRegen = 0,
	},

	BestRunScore = 0,
	
	ActiveRun = nil,
	SessionLockouts = {},
}



-- Initialize ProfileStore
local PlayerProfileStore = ProfileStore.New("PlayerDataStore", PLAYER_DATA_TEMPLATE)

-- Profiles storage
local Profiles = {}

-- Add this function in ProfileManager
local function ResetMetaUpgrades(player)
	local profile = Profiles[player]
	if profile and profile.Data then
		-- Reset MetaUpgrades to default values
		profile.Data.MetaUpgrades = {
			MagnetRange = 10, -- Default value
			MaxStamina = 100, -- Default value
			BaseAttackSpeed = 1, -- Default value
			HealthRegen = 0
		}
		-- Save the profile after resetting
		profile:Save()
		print(player.Name .. "'s MetaUpgrades have been reset.")
	else
		warn("Unable to reset MetaUpgrades for " .. player.Name .. ". Profile not found.")
	end
end




local function onPlayerAdded(player)
	local profile = PlayerProfileStore:StartSessionAsync("Player_" .. player.UserId)
	profile:AddUserId(player.UserId)
	if profile then
		profile:Reconcile() -- Ensure the profile matches the template
		Profiles[player] = profile
	else
		warn("Failed to initialize profile for:", player.Name)
		player:Kick("Failed to load your profile. Please rejoin.")
	end
end

local function onPlayerRemoving(player)
	local profile = Profiles[player]
	if profile then
		-- Cleanup stats at the end of the run
		profile:Save()
		profile:EndSession()
		Profiles[player] = nil
	end
end

-- Game closing function
local function onGameClosing()
	for _, profile in pairs(Profiles) do
		profile:Save()
		profile:EndSession()
	end
end

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
game:BindToClose(onGameClosing)

-- Return functions for other scripts
return {
	GetProfile = function(player)
		return Profiles[player]
	end,
}
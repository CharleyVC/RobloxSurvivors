-- ServerScriptService/Premium/PremiumRewards.lua
local ProfileManager = require(game.ServerScriptService.Scripts:WaitForChild("ProfileManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game.ServerScriptService
local ReviveManager = require(ServerScriptService.Revive.ReviveManager)

local PremiumRewards = {}

-- Helper: get profile safely
local function getProfile(player)
	return ProfileManager.GetProfile(player)
end

function PremiumRewards.GrantReviveToken(player, amount)
	local profile = getProfile(player)
	if not profile then return false end

	profile.Data.ReviveTokens = (profile.Data.ReviveTokens or 0) + amount
	return true
end

function PremiumRewards.GrantGems(player, amount)
	local profile = getProfile(player)
	if not profile then return false end

	profile.Data.Gems = (profile.Data.Gems or 0) + amount
	return true
end

function PremiumRewards.GrantWeaponPack(player, weaponId, amount)
	local profile = getProfile(player)
	if not profile then return false end

	profile.Data.UnlockedWeapons[weaponId] = true
	-- You can also grant coins, upgrades, etc as part of the pack.
	return true
end

-- Dispatcher: given a config and player, apply it
function PremiumRewards.ApplyProduct(player, productConfig)
	if not productConfig then return false end

	if productConfig.Type == "ReviveToken" then
		return PremiumRewards.GrantReviveToken(player, productConfig.Amount)

	elseif productConfig.Type == "Gems" then
		return PremiumRewards.GrantGems(player, productConfig.Amount)

	elseif productConfig.Type == "WeaponPack" then
		return PremiumRewards.GrantWeaponPack(player, productConfig.WeaponId, productConfig.Amount)
	end
	
	elseif productConfig.Type == "ReviveToken" then
	PremiumRewards.GrantReviveToken(player, productConfig.Amount)

	-- If player is in revive pending state → auto revive
	ReviveManager.OnTokenGranted(player)

	return true

	warn("Unknown premium product type:", productConfig.Type)
	return false
end

return PremiumRewards end

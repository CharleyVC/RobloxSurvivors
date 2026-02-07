local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local ProfileManager = require(game.ServerScriptService.Scripts.ProfileManager)
local PremiumProducts = require(game.ServerScriptService.Premium.PremiumProducts)

local ReviveManager = {}

local DEATH_UI_EVENT = ReplicatedStorage.RemoteEvents:WaitForChild("DeathUIEvent")
local REVIVE_PRODUCT_ID = 123456789  -- update to your actual revive token dev product

-- Track player revive states
local ReviveState = {}
-- Example:
-- ReviveState[player] = {
--     Waiting = true,
--     Revived = false,
--     Timer = 10,
-- }

-------------------------------------------------------
-- Utilities
-------------------------------------------------------
local function getTokens(player)
	local profile = ProfileManager.GetProfile(player)
	if not profile then return 0 end
	return profile.Data.ReviveTokens or 0
end

local function spendToken(player)
	local profile = ProfileManager.GetProfile(player)
	if not profile then return false end

	if profile.Data.ReviveTokens > 0 then
		profile.Data.ReviveTokens -= 1
		return true
	end
	return false
end

-------------------------------------------------------
-- Called when a player dies
-------------------------------------------------------
function ReviveManager.StartReviveFlow(player)
	-- Create revive state
	ReviveState[player] = {
		Waiting = true,
		Revived = false,
		Timer = 10,
	}

	-- Show UI on client
	DEATH_UI_EVENT:FireClient(player, {
		Tokens = getTokens(player),
		Timer = ReviveState[player].Timer,
	})

	-- Start revive countdown
	task.spawn(function()
		for t = 10, 0, -1 do
			local state = ReviveState[player]
			if not state or state.Revived then return end

			-- Update timer
			state.Timer = t
			DEATH_UI_EVENT:FireClient(player, { Timer = t })

			task.wait(1)
		end

		-- TIMEOUT — no revive purchased
		if ReviveState[player] and not ReviveState[player].Revived then
			ReviveManager.FailRevive(player)
		end
	end)
end

-------------------------------------------------------
-- When the player clicks "Use Token"
-------------------------------------------------------
function ReviveManager.UseToken(player)
	local state = ReviveState[player]
	if not state or not state.Waiting then return end

	if spendToken(player) then
		ReviveManager.FinishRevive(player)
	else
		-- No tokens → prompt purchase
		MarketplaceService:PromptProductPurchase(player, REVIVE_PRODUCT_ID)
	end
end

-------------------------------------------------------
-- When a revive token is purchased through PremiumService
-------------------------------------------------------
function ReviveManager.OnTokenGranted(player)
	local state = ReviveState[player]
	if state and state.Waiting then
		ReviveManager.FinishRevive(player)
	end
end

-------------------------------------------------------
-- Successful revive
-------------------------------------------------------
function ReviveManager.FinishRevive(player)
	local state = ReviveState[player]
	if not state then return end

	state.Revived = true
	state.Waiting = false

	-- Respawn the player
	player:LoadCharacter()

	ReviveState[player] = nil
end

-------------------------------------------------------
-- Failed revive (timer ran out)
-------------------------------------------------------
function ReviveManager.FailRevive(player)
	-- End run, teleport them out, or spectate
	-- For now: respawn without revive bonuses
	player:LoadCharacter()

	ReviveState[player] = nil
end


return ReviveManager

-- ServerScriptService/Premium/PremiumService.lua
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local PremiumProducts = require(script.Parent:WaitForChild("PremiumProducts"))
local PremiumRewards = require(script.Parent:WaitForChild("PremiumRewards"))

local PremiumService = {}

-- Optional: event to notify systems / UI when purchase applied
PremiumService.PurchaseGranted = Instance.new("BindableEvent")

local function getPlayerFromUserId(userId)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.UserId == userId then
			return plr
		end
	end
end

local function processDevProduct(receiptInfo)
	local player = getPlayerFromUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left; tell Roblox to try again later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productConfig = PremiumProducts[receiptInfo.ProductId]
	if not productConfig then
		warn("Unknown dev product bought:", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success = PremiumRewards.ApplyProduct(player, productConfig)
	if success then
		PremiumService.PurchaseGranted:Fire(player, productConfig)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		-- Data not ready yet etc. Try again.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

-- Hook ProcessReceipt ONCE for the whole game
MarketplaceService.ProcessReceipt = function(receiptInfo)
	return processDevProduct(receiptInfo)
end

return PremiumService

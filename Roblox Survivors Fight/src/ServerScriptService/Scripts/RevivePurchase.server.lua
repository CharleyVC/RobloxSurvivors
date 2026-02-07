local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Developer Product ID for revive
local reviveProductId = 2689814356 -- Replace with your Developer Product ID

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if receiptInfo.ProductId == reviveProductId then
		-- Revive the player by respawning their character
		player:LoadCharacter()
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	
	
	
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

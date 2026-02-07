local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MagnetEvent = ReplicatedStorage.RemoteEvents:WaitForChild("Magnet")
local CoinMagnetEvent = ReplicatedStorage.RemoteEvents:WaitForChild("StopTweenEvent")

local collectionRange = 2 -- Collection range in studs

RunService.RenderStepped:Connect(function()
	local player = game.Players.LocalPlayer
	local character = player.Character
	if not character or not character.PrimaryPart then return end

	local magnetRange = character:GetAttribute("MagnetRange") or 10 -- Default range if attribute is missing

	for _, collectible in pairs(workspace.Collectibles:GetChildren()) do
		if collectible:IsA("Model") and collectible.PrimaryPart then
			local distance = (character.PrimaryPart.Position - collectible.PrimaryPart.Position).Magnitude

			-- Magnet effect: Move collectible toward the player
			if distance <= magnetRange then
				-- Smoothly move collectible toward the player
				CoinMagnetEvent:Fire(collectible)
				collectible.PrimaryPart.Anchored = false
				collectible:SetPrimaryPartCFrame(
					collectible.PrimaryPart.CFrame:Lerp(
						CFrame.new(character.PrimaryPart.Position),
						0.3 -- Adjust speed
					)
				)

				-- Notify server if collectible is within collection range
				if distance < collectionRange then
					MagnetEvent:FireServer(collectible) -- Notify server
					collectible:Destroy() -- Remove locally
				end
			end
		end
	end
end)
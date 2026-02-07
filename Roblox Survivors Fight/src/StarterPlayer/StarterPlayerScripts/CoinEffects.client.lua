local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinSpawnEvent = ReplicatedStorage.RemoteEvents:WaitForChild("GoldSpawn")
local CoinMagnetEvent = ReplicatedStorage.BindableEvents:WaitForChild("StopTweenEvent")
local TweenService = game:GetService("TweenService")

CoinSpawnEvent.OnClientEvent:Connect(function(coin)
	if not coin or not coin:IsA("Model") then
		warn("Invalid coin received.")
		return
	end

	if not coin.PrimaryPart then
		local potentialPrimaryPart = coin:WaitForChild("Coin")
		if potentialPrimaryPart then
			coin.PrimaryPart = potentialPrimaryPart
		else
			warn("No valid PrimaryPart found for coin.")
			return
		end
	end
	
	local coinRoot = coin.PrimaryPart
	-- Create a floating effect
	local startPosition = coinRoot.Position
	local endPosition = startPosition + Vector3.new(0, 2, 0)

	local tweenInfo = TweenInfo.new(
		1,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.InOut,
		-1,
		true
	)
	local properties = {
		Position = coinRoot.Position + Vector3.new(0, 1, 0),
		Rotation = coinRoot.Rotation + Vector3.new(90, 180, -90)
	}
	local tween = TweenService:Create(coinRoot, tweenInfo, properties)
	
	tween:Play()
	
	-- Add glowing effect
	local light = Instance.new("PointLight", coinRoot)
	light.Color = Color3.new(1, 1, 0)
	light.Brightness = 2
	light.Range = 4
	
	CoinMagnetEvent.Event:Connect(function(collectible)
		if collectible == coin then
			
			tween:Cancel() -- Stop floating
		end
	end)
end)
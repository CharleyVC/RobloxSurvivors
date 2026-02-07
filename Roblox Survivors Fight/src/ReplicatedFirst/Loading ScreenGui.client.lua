game.ReplicatedFirst:RemoveDefaultLoadingScreen()

local screenGui = Instance.new("ScreenGui")
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 1000
screenGui.Parent = game.Players.LocalPlayer.PlayerGui

local textLabel = Instance.new("TextLabel")
textLabel.Active = true
textLabel.Size = UDim2.new(1,0,1,0)
textLabel.BackgroundColor3 = Color3.fromRGB(45,45,45)
textLabel.Font = Enum.Font.Arimo
textLabel.TextColor3 = Color3.fromRGB(255,255,255)
textLabel. Text = "Loading"
textLabel.TextSize = 40
textLabel.Parent = screenGui

if game:IsLoaded() == false then game.Loaded:Wait() end

screenGui:Destroy()

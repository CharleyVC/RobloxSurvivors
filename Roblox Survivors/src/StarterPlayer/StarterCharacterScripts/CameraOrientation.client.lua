local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Camera = workspace.CurrentCamera

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local PrimaryPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

-- Camera settings
local BaseHeight = 40 -- Base camera height above the character
local CameraDistance = 50 -- Distance of the camera from the character
local Smoothness = 0.1 -- Smooth transition for camera movement
local FoV = 7
local Zoom = 200
local IsometricAngle = math.rad(30) -- Vertical tilt angle for isometric view
local HorizontalAngle = math.rad(45) -- Horizontal rotation angle for isometric view

-- State to track the last grounded elevation
local LastGroundedElevation = PrimaryPart.Position.Y

-- Function to update the camera position
local function UpdateCamera()
	-- Maintain stable height if in the air
	local currentElevation = Humanoid.FloorMaterial ~= Enum.Material.Air and PrimaryPart.Position.Y or LastGroundedElevation
	if Humanoid.FloorMaterial ~= Enum.Material.Air then
		LastGroundedElevation = currentElevation -- Update last grounded elevation
	end

	local adjustedHeight = BaseHeight + currentElevation

	-- Calculate the camera's position and focus
	local targetFocus = PrimaryPart.CFrame
	local offset = CFrame.Angles(0, HorizontalAngle, 0) -- Horizontal rotation
		* CFrame.Angles(-IsometricAngle, 0, 0) -- Vertical tilt
		* CFrame.new(0, 0, CameraDistance) -- Distance from the character

	local targetCFrame = CFrame.new(Vector3.new(PrimaryPart.Position.X + Zoom, PrimaryPart.Position.Y + Zoom, PrimaryPart.Position.Z + Zoom), PrimaryPart.Position)

	-- Smoothly transition the camera position
	Camera.FieldOfView = FoV
	--Camera.Zoom = 100
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.Focus = targetFocus
	Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, Smoothness)
end

-- Enable the camera
local function EnableIsometricCamera()
	RunService.RenderStepped:Connect(function()
		UpdateCamera()
	end)
end

-- Initialize the camera
EnableIsometricCamera()

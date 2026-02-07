local PhysicsService = game:GetService("PhysicsService")

local CollisionGroupManager = {}

local PhysicsService = game:GetService("PhysicsService")

local CollisionGroupManager = {}
local REGISTERED = false

function CollisionGroupManager.setupCollisionGroups()
	if REGISTERED then return end
	REGISTERED = true

	local function safeRegister(name)
		pcall(function()
			PhysicsService:RegisterCollisionGroup(name)
		end)
	end

	safeRegister("Players")
	safeRegister("Enemies")
	safeRegister("InvisibleObjects")
	safeRegister("VFX")
	safeRegister("World")
	safeRegister("Raycast")
	safeRegister("GroundOnlyRay")
	safeRegister("PlayerGhost")
	
	
	-- Collision matrix
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Enemies", true)
	PhysicsService:CollisionGroupSetCollidable("Players", "World", true)
	PhysicsService:CollisionGroupSetCollidable("Players", "VFX", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Raycast", false)
	
	PhysicsService:CollisionGroupSetCollidable("Enemies", "Enemies", false)
	PhysicsService:CollisionGroupSetCollidable("Enemies", "World", true)
	PhysicsService:CollisionGroupSetCollidable("Enemies", "VFX", false)
	PhysicsService:CollisionGroupSetCollidable("Enemies", "Raycast", true)
	
	PhysicsService:CollisionGroupSetCollidable("Raycast", "VFX", false)
	PhysicsService:CollisionGroupSetCollidable("Raycast", "World", true)
	PhysicsService:CollisionGroupSetCollidable("Raycast", "InvisibleObjects", false)
	PhysicsService:CollisionGroupSetCollidable("InvisibleObjects", "InvisibleObjects", false)
	
	PhysicsService:CollisionGroupSetCollidable("GroundOnlyRay", "InvisibleObjects", false)
	PhysicsService:CollisionGroupSetCollidable("GroundOnlyRay", "Enemies", false)
	PhysicsService:CollisionGroupSetCollidable("GroundOnlyRay", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("GroundOnlyRay", "VFX", false)
	PhysicsService:CollisionGroupSetCollidable("GroundOnlyRay", "World", true)
	
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "World", true)
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "VFX", false)
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "Raycast", false)
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "GroundOnlyRay", false)
	PhysicsService:CollisionGroupSetCollidable("PlayerGhost", "Enemies", false)
end


function CollisionGroupManager.setCollisionGroup(model, groupName)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = groupName
		end
	end
end

return CollisionGroupManager
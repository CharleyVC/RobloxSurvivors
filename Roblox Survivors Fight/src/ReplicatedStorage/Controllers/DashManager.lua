--!strict
-- DashManager.lua
-- Client-side dash executor + server request (NO spam)

local DashManager = {}

---------------------------------------------------------------------
-- Services
---------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

---------------------------------------------------------------------
-- Player refs
---------------------------------------------------------------------
local player = Players.LocalPlayer

local character: Model
local humanoid: Humanoid
local hrp: BasePart

---------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------
local AnimationHandler = require(ReplicatedStorage:WaitForChild("AnimationHandler"))
local CapsuleHitDetection = require(ReplicatedStorage.Controllers:WaitForChild("CapsuleHitDetection"))

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")

local DashRequest   = RemoteEvents:WaitForChild("DashRequest")     -- Client → Server
local DashHit		= RemoteEvents:WaitForChild("DashHit")	       -- Client → Server
local DashImpulse   = RemoteEvents:WaitForChild("DashImpulse")     -- Server → Client
local DashLifecycle = RemoteEvents:WaitForChild("DashLifecycle")   -- Server → Client




local enemies = Workspace:FindFirstChild("Enemies")

local lastDashPos: Vector3? = nil
local dashHitCache: {[Model]: boolean} = {}

---------------------------------------------------------------------
-- Dash FSM State
---------------------------------------------------------------------
local State = {
	Active = false,
	Velocity = Vector3.zero,
	EndTime = 0,
}

---------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------
local animationData = {
	humanoid = nil,
	category = "Ability",
	specificType = "BasicDash",
	animations = nil,
	state = nil,
	weight = 1,
	target = nil,
}

---------------------------------------------------------------------
-- Utilities
---------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function sanitizeDirection(dir: Vector3): Vector3?
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		return nil
	end
	return flat.Unit
end

local function getDashDirection(): Vector3?
	-- Prefer move direction (keyboard / joystick)
	local move = humanoid and humanoid.MoveDirection or Vector3.zero
	local dir = flat(move)

	if dir.Magnitude > 0.1 then
		return dir.Unit
	end

	-- Fallback to camera forward
	local cam = Workspace.CurrentCamera
	if cam then
		local look = flat(cam.CFrame.LookVector)
		if look.Magnitude > 0.1 then
			return look.Unit
		end
	end

	return nil
end

local function resetState()
	State.Active = false
	State.Velocity = Vector3.zero
	State.EndTime = 0
end

---------------------------------------------------------------------
-- PUBLIC: Request Dash (called by InputController)
---------------------------------------------------------------------
function DashManager.RequestDash()
	if State.Active then return end
	if not humanoid or not hrp then return end

	local raw = getDashDirection()
	if not raw then return end

	local dir = sanitizeDirection(raw)
	if not dir then return end

	DashRequest:FireServer(dir)
end

---------------------------------------------------------------------
-- SERVER → CLIENT: Dash approved (impulse)
---------------------------------------------------------------------
DashImpulse.OnClientEvent:Connect(function(impulse: Vector3, duration: number)
	if not hrp or typeof(impulse) ~= "Vector3" then return end
	if typeof(duration) ~= "number" then return end

	State.Active = true
	State.EndTime = os.clock() + duration
	local vel = hrp.AssemblyLinearVelocity
	lastDashPos = hrp.Position
	dashHitCache = {}


	-- Reset horizontal only
	hrp.AssemblyLinearVelocity =
		Vector3.new(0, vel.Y, 0)
	-- Apply impulse ONCE
	hrp:ApplyImpulse(impulse)

	-- Play animation
	if animationData.animations then
		animationData.state = "Forward"
		AnimationHandler.playAnimation(animationData)
	end
end)

---------------------------------------------------------------------
-- SERVER → CLIENT: Dash End
---------------------------------------------------------------------
DashLifecycle.OnClientEvent:Connect(function(phase: string)
	if phase ~= "End" then return end
	DashManager.EndDash()
end)



RunService.Heartbeat:Connect(function(dt)
	if not State.Active or not hrp then return end

	-- End condition
	if os.clock() >= State.EndTime then
		DashManager.EndDash()
		return
	end

	-----------------------------------------------------------------
	-- DASH HIT SWEEP (player as projectile)
	-----------------------------------------------------------------
	if enemies and lastDashPos then
		local currentPos = hrp.Position
		local enemy = CapsuleHitDetection.CheckProjectileHit(
			lastDashPos,
			currentPos,
			4, -- or synced DashProperties.SweepRadius
			enemies
		)
		if enemy and not dashHitCache[enemy] then
			dashHitCache[enemy] = true
			RemoteEvents.DashHit:FireServer(enemy)
		end
		lastDashPos = currentPos
	end

	-----------------------------------------------------------------
	-- EXISTING VELOCITY MAINTENANCE (unchanged)
	-----------------------------------------------------------------
	local vel = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity =
		Vector3.new(
			vel.X,
			math.max(vel.Y, -50),
			vel.Z
		)
end)





---------------------------------------------------------------------
-- End Dash (FULL RESET)
---------------------------------------------------------------------
function DashManager.EndDash()
	if not State.Active or not hrp then return end
	State.Active = false
	lastDashPos = nil
	dashHitCache = {}
	-- Let physics decay naturally
	-- Optional: mild damping
	local vel = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity =
		Vector3.new(vel.X * 0.8, vel.Y, vel.Z)
end

---------------------------------------------------------------------
-- Character lifecycle safety
---------------------------------------------------------------------
local function onCharacter(char: Model)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")

	animationData.humanoid = humanoid
	animationData.animations = AnimationHandler.loadAnimations(
		character,
		animationData.category,
		animationData.specificType
	)

	resetState()
end

if player.Character then
	onCharacter(player.Character)
end

player.CharacterAdded:Connect(onCharacter)

return DashManager

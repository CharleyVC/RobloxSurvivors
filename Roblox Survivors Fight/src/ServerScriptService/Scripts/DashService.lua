--!strict
-- DashService.lua
-- Server-side dash orchestration (mirrors WeaponService pattern)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

---------------------------------------------------------------------
-- Combat framework
---------------------------------------------------------------------
local ActionContext = require(ReplicatedStorage.Combat.ActionContext)
local ActionModifierService = require(ReplicatedStorage.Combat.ActionModifierService)
local ActionPhases = require(ReplicatedStorage.Combat.ActionPhases)

---------------------------------------------------------------------
-- Ability data (NEW – mirrors WeaponProperties)
---------------------------------------------------------------------
local AbilityProperties = require(game.ServerScriptService.Scripts:WaitForChild("AbilityProperties"))
local SlotContext =	require(game.ServerScriptService.Scripts.SlotContext)
local DashProperties = AbilityProperties.Dash

---------------------------------------------------------------------
-- Remotes
---------------------------------------------------------------------
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local DashRequest   = RemoteEvents:WaitForChild("DashRequest")
local DashImpulse   = RemoteEvents:WaitForChild("DashImpulse")
local DashLifecycle = RemoteEvents:WaitForChild("DashLifecycle")
local vfxEvent = RemoteEvents:WaitForChild("VFXEvent")
local RateLimiter = require(game.ServerScriptService.Scripts:WaitForChild("RateLimiter"))

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local Active: {[any]: ActionContext} = {}
local Cooldowns: {[Player]: number} = {}
local DashState: {[Player]: {lastPos: Vector3, hitCache: {[Model]: boolean}}} = {}
local enemiesFolder = Workspace:WaitForChild("Enemies")
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = { enemiesFolder }

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function now(): number
	return os.clock()
end

local function flatUnit(v: Vector3): Vector3?
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 1e-3 then return nil end
	return f.Unit
end

---------------------------------------------------------------------
-- Core dash execution
---------------------------------------------------------------------
local function startDash(player: Player, direction: Vector3)

	if Active[player] then return end
	if typeof(direction) ~= "Vector3" then return end
	if not RateLimiter.Allow(player, "DashStart", 0.1) then return end

	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local dir = flatUnit(direction)
	if not dir then return end

	-----------------------------------------------------------------
	-- Build ActionContext (IDENTICAL role to WeaponService)
	-----------------------------------------------------------------
	local context = ActionContext.new(
	{	Actor = character,
		Action = "Dash",
		BaseType = "BasicDash",
		Source = "Ability",
		Speed = DashProperties.Speed,
	})
	

	
	-----------------------------------------------------------------
	-- Seed context from AbilityProperties (NOT modifiers)
	-----------------------------------------------------------------
	context.Tags = DashProperties.Tags

	context.Duration = DashProperties.Duration
	context.Cooldown = DashProperties.Cooldown

	context.DashDirection = dir
	context.HorizontalImpulse = DashProperties.Movement.HorizontalImpulse
	context.GravityScale = DashProperties.Movement.GravityScale

	-- Effect payloads (generic, modifier-driven)
	context.Invulnerability = DashProperties.Invulnerability
	context.NoCollision = DashProperties.NoCollision
	context.SweepRadius = DashProperties.SweepRadius
	context.Phase = ActionPhases.OnActionStart
	
	SlotContext.Apply(character, context.Action, context) -- Apply Boon Specific Context like "Bomb" etc.
	
	-----------------------------------------------------------------
	-- Dispatch modifiers (augment, not define)
	-----------------------------------------------------------------
	ActionModifierService.DispatchPhase(
		character,
		ActionPhases.OnActionStart,
		context
	)

	-----------------------------------------------------------------
	-- Cooldown gate (post-modifier, like weapons)
	-----------------------------------------------------------------
	local cd = context.Cooldown
	if cd then
		local last = Cooldowns[player]
		if last and now() - last < cd then
			return
		end
	end

	Active[player] = context
	DashState[player] = { lastPos = hrp.Position, hitCache = {} }

	-----------------------------------------------------------------
	-- Authoritative impulse (movement stays here)
	-----------------------------------------------------------------
	local horiz =
		context.DashDirection
		* context.Speed
		* context.HorizontalImpulse

	local vertical =
		Vector3.new(
			0,
			Workspace.Gravity
			* context.Duration
			* context.GravityScale,
			0
		)

	local impulse =
		(horiz + vertical)
		* hrp.AssemblyMass
	DashImpulse:FireClient(player, impulse, context.Duration)

	-----------------------------------------------------------------
	-- End dash
	-----------------------------------------------------------------
	task.delay(context.Duration, function()
		if Active[player] ~= context then return end

		Active[player] = nil
		DashState[player] = nil
		Cooldowns[player] = now()
		context.Phase = ActionPhases.OnExpire
		ActionModifierService.DispatchPhase(
			character,
			ActionPhases.OnExpire,
			context
		)

		DashLifecycle:FireClient(player, "End")
	end)
end

local function checkDashHits(player: Player, context: ActionContext, hrp: BasePart, sweepRadius: number)
	local state = DashState[player]
	if not state then return end

	local lastPos = state.lastPos
	local currentPos = hrp.Position
	local midPos = (lastPos + currentPos) * 0.5

	local positions = { lastPos, midPos, currentPos }
	for _, pos in ipairs(positions) do
		local parts = Workspace:GetPartBoundsInRadius(pos, sweepRadius, overlapParams)
		for _, part in ipairs(parts) do
			local model = part:FindFirstAncestorOfClass("Model")
			if model and model:IsDescendantOf(enemiesFolder) and not state.hitCache[model] then
				state.hitCache[model] = true
				context.HitTarget = model
				context.Phase = ActionPhases.OnTravel
				ActionModifierService.DispatchPhase(
					context.Actor,
					ActionPhases.OnTravel,
					context
				)
				vfxEvent:FireAllClients("HitNPC", model)
			end
		end
	end

	state.lastPos = currentPos
end

---------------------------------------------------------------------
-- ENTRYPOINT (mirrors WeaponService exactly)
---------------------------------------------------------------------
DashRequest.OnServerEvent:Connect(startDash)

RunService.Heartbeat:Connect(function()
	for player, context in pairs(Active) do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			DashState[player] = nil
			Active[player] = nil
		else
			local radius = (context.SweepRadius and context.SweepRadius > 0) and context.SweepRadius or 4
			checkDashHits(player, context, hrp, radius)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	Active[player] = nil
	Cooldowns[player] = nil
	DashState[player] = nil
	RateLimiter.Clear(player)
end)

return {}

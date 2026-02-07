--!strict
-- DashService.lua
-- Server-side dash orchestration (mirrors WeaponService pattern)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
local DashHit		= RemoteEvents:WaitForChild("DashHit")	       -- Client → Server
local DashImpulse   = RemoteEvents:WaitForChild("DashImpulse")
local DashLifecycle = RemoteEvents:WaitForChild("DashLifecycle")

---------------------------------------------------------------------
-- State
---------------------------------------------------------------------
local Active: {[any]: ActionContext} = {}
local Cooldowns: {[Player]: number} = {}

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

DashHit.OnServerEvent:Connect(function(player, enemy)
	
	local context = Active[player]
	if not context then return end
	if not enemy or not enemy:IsDescendantOf(workspace.Enemies) then return end

	context.HitTarget = enemy
	context.Phase = ActionPhases.OnTravel
	ActionModifierService.DispatchPhase(
		context.Actor,
		ActionPhases.OnTravel,
		context
	)
end)

---------------------------------------------------------------------
-- ENTRYPOINT (mirrors WeaponService exactly)
---------------------------------------------------------------------
DashRequest.OnServerEvent:Connect(startDash)

Players.PlayerRemoving:Connect(function(player)
	Active[player] = nil
	Cooldowns[player] = nil
end)

return {}

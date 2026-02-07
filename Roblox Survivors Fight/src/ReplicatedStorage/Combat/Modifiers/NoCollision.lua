--!strict
-- NoCollision.lua
-- Temporarily disables collision with enemies during an action

local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local ActionPhases =
	require(game.ReplicatedStorage.Combat.ActionPhases)

local NoCollision = {
	Id = "NoCollision",
	AppliesTo = "All",
	Phases = {
		ActionPhases.OnActionStart,
		ActionPhases.OnExpire,
	},
	RequiredTags = "NoCollide",
	Priority = 90,
}

---------------------------------------------------------------------
-- Collision groups (must exist at boot)
---------------------------------------------------------------------
local PLAYER_GROUP = "Players"
local PLAYER_GHOST_GROUP = "PlayerGhost"

local function setCharacterCollisionGroup(
	character: Model,
	groupName: string
)
	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.CollisionGroup = groupName
		end
	end
end

---------------------------------------------------------------------
-- Server execution
---------------------------------------------------------------------
if RunService:IsServer() then
	function NoCollision.Execute(context)
		local character = context.Actor
		if not character then return end
		-- Opt-in gate (AbilityProperties driven)
		--local collisionData = context.NoCollision
		--if not collisionData
		--	or not collisionData.Enabled
		--then
		--	return
		--end
		
		if context.Phase == ActionPhases.OnActionStart then
			
			-- Become ghost: pass through enemies
			setCharacterCollisionGroup(
				character,
				PLAYER_GHOST_GROUP
			)

		elseif context.Phase == ActionPhases.OnExpire then
			-- Restore normal collision
			setCharacterCollisionGroup(
				character,
				PLAYER_GROUP
			)
		end
	end
end

return NoCollision

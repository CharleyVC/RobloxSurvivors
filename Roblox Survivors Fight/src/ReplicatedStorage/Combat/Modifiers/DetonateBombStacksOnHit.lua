--!strict
-- DetonateBombStacksOnHit.lua
-- Consumes bomb stacks and applies explosion damage when a BombDetonation hit occurs

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionPhases = require(ReplicatedStorage.Combat.ActionPhases)

local DetonateBombStacksOnHit = {
	Id = "DetonateBombStacksOnHit",
	AppliesTo = "BombDetonation",
	Phases = { ActionPhases.OnHit },
	Priority = 80,
}

--------------------------------------------------------
-- SERVER
--------------------------------------------------------
if RunService:IsServer() then
	local EffectsAuthority =
		require(game.ServerScriptService.Scripts.EffectsAuthority)

	function DetonateBombStacksOnHit.Execute(context)
		local HitTarget = context.HitTarget
		local bomb = context.Flags.Bomb

		if not HitTarget then return end
		if not bomb then return end

		EffectsAuthority.detonateBombStacks(
			HitTarget,
			bomb.DamagePerStack,
			bomb.Radius,
			bomb.Knockback
		)
	end
end

return DetonateBombStacksOnHit

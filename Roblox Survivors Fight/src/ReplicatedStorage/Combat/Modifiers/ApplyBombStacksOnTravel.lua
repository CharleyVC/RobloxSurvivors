--!strict
local RunService = game:GetService("RunService")
local ActionPhases = require(game.ReplicatedStorage.Combat.ActionPhases)

local Mod = {
	Id = "ApplyBombStacksOnTravel",
	AppliesTo = "All",
	Phases = { ActionPhases.OnTravel },
	RequiredTags = {"Bomb"},
	Priority = 60,
}

if RunService:IsServer() then
	local EffectsAuthority =
		require(game.ServerScriptService.Scripts.EffectsAuthority)

	function Mod.Execute(context)
		local HitTarget = context.HitTarget
		local bomb = context:GetFlag("Bomb")
		if not HitTarget or not bomb then return end

		EffectsAuthority.addBombStacks(
			HitTarget,
			bomb.Stacks or 1,
			bomb.MaxStacks,
			bomb.DamagePerStack,
			bomb.Radius,
			bomb.Knockback
		)

	end
end

return Mod

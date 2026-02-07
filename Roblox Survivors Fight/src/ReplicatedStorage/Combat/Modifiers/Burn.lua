-- ReplicatedStorage/Combat/Modifiers/Burn.lua

local RunService = game:GetService("RunService")
local ActionPhases = require(game.ReplicatedStorage.Combat.ActionPhases)

local Burn = {
	Id = "Burn",
	Phases = { ActionPhases.OnHit },
	Priority = 40,
	AppliesTo = "Secondary",
	RequiredTags = { "Fire" },
}

if RunService:IsServer() then
	local EffectsAuthority = require(game.ServerScriptService.Scripts.EffectsAuthority)

	function Burn.Execute(context)
		
		local target = context.HitTarget
		local burn = context.Burn
		if not target or not burn then
			return
		end

		local mode = burn.Mode or "Flat"
		local baseDamage = context.Damage or 0
		
		local dps
		if mode == "Percent" then
			-- Damage is treated as a fraction of base damage
			dps = baseDamage * (burn.Damage or 0)
		else
			-- Flat damage per tick
			dps = burn.Damage or 0
		end

		if dps <= 0 then return end

		EffectsAuthority.applyDot(
			target,
			"Burn",
			{
				Damage = dps,
				Duration = burn.Duration,
				Stacks = burn.Stacks or 1,
				Knockback = burn.Knockback,
				Maxstacks = burn.Maxstacks
			}
		)
	end
end

return Burn

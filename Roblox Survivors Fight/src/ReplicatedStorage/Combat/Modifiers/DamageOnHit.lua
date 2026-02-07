local RunService = game:GetService("RunService")

local ActionPhases = require(game.ReplicatedStorage.Combat.ActionPhases)
local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

local DamageOnHit = {
	Id = "DamageOnHit",
	Phases = { ActionPhases.OnHit },
	Priority = 50,
	AppliesTo = "All",
}

--------------------------------------------------------
-- SERVER: authoritative damage
--------------------------------------------------------
if RunService:IsServer() then
	local EffectsAuthority = require(game.ServerScriptService.Scripts.EffectsAuthority)

	function DamageOnHit.Execute(context)
		local target = context.HitTarget
		if not target then return end

		local damage = context.Damage or 0
		if damage <= 0 then return end

		EffectsAuthority.applyDamage(target, damage, context.Knockback)
		

	end
end



return DamageOnHit

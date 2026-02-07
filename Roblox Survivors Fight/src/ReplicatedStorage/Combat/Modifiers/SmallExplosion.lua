-- ReplicatedStorage/Combat/Modifiers/SmallExplosion.lua

local RunService = game:GetService("RunService")
local ActionPhases = require(game.ReplicatedStorage.Combat.ActionPhases)
local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

local SmallExplosion = {
	Id = "SmallExplosion",

	-- Uses your existing phase
	Phases = { ActionPhases.OnHit },

	-- Runs after base damage has been applied
	Priority = 60,

	-- Applies to primary attacks only (as you set)
	AppliesTo = "Primary",

	-- Only actions that support AoE
	RequiredTags = { "AreaCapable" },
}

--------------------------------------------------------
-- CONFIG
--------------------------------------------------------
local DAMAGE_MULTIPLIER = 0.4 -- 40% of base damage
local VFX_DURATION = .3
--------------------------------------------------------
-- SERVER: authoritative AoE damage
--------------------------------------------------------
if RunService:IsServer() then
	local EffectsAuthority = require(game.ServerScriptService.Scripts.EffectsAuthority)

	function SmallExplosion.Execute(context)
		local position = context.HitPosition
		if not position then return end

		local radius = context.Radius or 0
		local baseDamage = context.Damage or 0
		local color = Color3.new(0.905882, 0.298039, 0.235294)
		if radius <= 0 or baseDamage <= 0 then
			return
		end
		local explosionDamage = baseDamage * DAMAGE_MULTIPLIER
		vfxEvent:FireAllClients("RingVFX", position, radius, VFX_DURATION, color)
		-- Execute AoE via EffectsAuthority (execution only)
		EffectsAuthority.applyInstantAoEDamage(
			position,
			radius,
			explosionDamage,
			context.Actor,
			context.Knockback
		)

		
	end
end

return SmallExplosion

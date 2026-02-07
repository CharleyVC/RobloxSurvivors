--!strict
-- AreaScheduler.lua
-- AoE HIT EXPANSION modifier (weapon-based)

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionPhases =
	require(ReplicatedStorage.Combat.ActionPhases)

local vfxEvent =
	ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

local GroundResolver =
	require(ReplicatedStorage:WaitForChild("GroundResolver"))

local AreaScheduler = {
	Id = "AoE",
	Phases = { ActionPhases.OnHit },
	Priority = 45,
	AppliesTo = "Secondary",
	RequiredTags = { "AreaCapable" },
}

--------------------------------------------------------
-- SERVER
--------------------------------------------------------
if RunService:IsServer() then
	local AreaQuery =
		require(game.ServerScriptService.Scripts.AreaQuery)

	function AreaScheduler.Execute(context)
		------------------------------------------------
		-- Validate AoE config
		------------------------------------------------
		if context.IsAoEChild then
			return
		end
		
		local cfg = context.AoE
		if not cfg then return end

		local hitPos = context.HitPosition
		if not hitPos then return end

		local radius = context.Radius or 0
		if radius <= 0 then return end

		local duration = cfg.Duration or 0
		if duration <= 0 then return end

		local tickRate = cfg.TickRate or 1

		------------------------------------------------
		-- Resolve ground (for VFX + consistency)
		------------------------------------------------
		local ground = GroundResolver.resolve(hitPos)
		local position = ground.Position

		context.GroundPosition = ground.Position
		context.GroundNormal = ground.Normal

		------------------------------------------------
		-- Fire AoE VFX ONCE
		------------------------------------------------
		if context.Burn then
			vfxEvent:FireAllClients("AoeVFX", ground, radius, duration)
		else
			vfxEvent:FireAllClients(
				"RingVFX",
				ground,
				radius,
				duration,
				Color3.fromRGB(231, 76, 60)
			)
		end

		------------------------------------------------
		-- Tick: expand hits via AreaQuery
		------------------------------------------------
		local endTime = os.clock() + duration

		task.spawn(function()
			while os.clock() < endTime do
				AreaQuery.Execute(context, {
					Position = position,
					Radius = radius,
				})

				task.wait(tickRate)
			end
		end)
	end
end

return AreaScheduler

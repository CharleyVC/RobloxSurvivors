--!strict
-- This trigger is On Expire, which creates Action Context "BombDetonation".. AreaQuery Scans and Triggers Dispatch OnHit() where DetonateBombStacksOnHit is listening to apply damage.
local RunService = game:GetService("RunService")
local ActionPhases = require(game.ReplicatedStorage.Combat.ActionPhases)
local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

local DetonateBombsOnExpire = {
	Id = "DetonateBombsOnExpire",
	AppliesTo = "All",                 -- 🔑 generic
	Phases = { ActionPhases.OnExpire },
	RequiredTags = { "Bomb" },         -- 🔑 gated by behavior, not slot
	Priority = 50,
}

if RunService:IsServer() then
	local AreaQuery =
		require(game.ServerScriptService.Scripts.AreaQuery)

	function DetonateBombsOnExpire.Execute(context)
		local actor = context.Actor
		local bomb = context.Flags.Bomb
		if not actor or not bomb then return end

		local hrp = actor:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- Switch action so Dash / ability modifiers do not re-fire
		context.Action = "BombDetonation"
		context.HitPosition = hrp.Position
		vfxEvent:FireAllClients("RingVFX", context.HitPosition, bomb.Radius, 0.3, Color3.new(0.905882, 0.298039, 0.235294))
		AreaQuery.Execute(context, {
			Position = hrp.Position,
			Radius = bomb.Radius or 10,
		})
	end
end

return DetonateBombsOnExpire

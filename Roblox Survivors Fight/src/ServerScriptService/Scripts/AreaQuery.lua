--!strict
-- AreaQuery.lua
-- Spatial utility: expands an ActionContext into multiple OnHit events

local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ActionPhases = require(ReplicatedStorage.Combat.ActionPhases)
local ActionModifierService =require(ReplicatedStorage.Combat.ActionModifierService)

local AreaQuery = {}

---------------------------------------------------------------------
-- Execute an area hit expansion
---------------------------------------------------------------------
-- baseContext : ActionContext (or table shaped like it)
-- params = {
--   Position : Vector3,
--   Radius   : number,
-- }
--
-- This will:
--   • Find targets in radius
--   • Clone the base context per target
--   • Populate HitTarget / HitPosition
--   • Dispatch OnHit for each target
---------------------------------------------------------------------
function AreaQuery.Execute(baseContext: any, params: { Position: Vector3, Radius: number })
	if not baseContext then return end
	if not params or not params.Position or not params.Radius then return end
	if params.Radius <= 0 then return end

	local actor = baseContext.Actor
	if not actor then return end

	------------------------------------------------------------
	-- Spatial query
	------------------------------------------------------------
	local parts = Workspace:GetPartBoundsInRadius(params.Position, params.Radius)
	if #parts == 0 then return end

	local hitModels: {[Model]: boolean} = {}

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= actor and not hitModels[model] then
			hitModels[model] = true

			----------------------------------------------------
			-- Clone context for this target
			----------------------------------------------------
			local ctx = table.clone(baseContext)

			ctx.IsAoEChild = true

			ctx.HitTarget = model

			local hrp = model:FindFirstChild("HumanoidRootPart")
			if hrp then
				ctx.HitPosition = hrp.Position
			else
				ctx.HitPosition = params.Position
			end

			----------------------------------------------------
			-- Dispatch hit event
			----------------------------------------------------
			ActionModifierService.DispatchPhase(
				actor,
				ActionPhases.OnHit,
				ctx
			)
		end
	end
end

return AreaQuery

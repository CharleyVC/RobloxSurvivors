-- ServerScriptService//GroundResolver.lua

local Workspace = game:GetService("Workspace")

local GroundResolver = {}

--------------------------------------------------------
-- Raycast params (collision-group based)
--------------------------------------------------------
local GROUND_RAY_PARAMS = RaycastParams.new()
GROUND_RAY_PARAMS.CollisionGroup = "GroundOnlyRay"
GROUND_RAY_PARAMS.IgnoreWater = true

--------------------------------------------------------
-- CONFIG
--------------------------------------------------------
local RAY_HEIGHT = 3        -- start slightly above hit
local RAY_DISTANCE = 50    -- how far down to search

--------------------------------------------------------
-- Resolve ground position + normal
--------------------------------------------------------
function GroundResolver.resolve(position)
	if not position then return nil end

	local origin = position + Vector3.new(0, RAY_HEIGHT, 0)
	local direction = Vector3.new(0, -RAY_DISTANCE, 0)

	local result = Workspace:Raycast(origin, direction, GROUND_RAY_PARAMS)

	if result then
		return {
			Position = result.Position,
			Normal = result.Normal,
			Instance = result.Instance,
		}
	end

	-- Fallback (no ground found)
	return {
		Position = position,
		Normal = Vector3.new(0, 1, 0),
		Instance = nil,
	}
end

--------------------------------------------------------
-- Build slope-aligned CFrame
--------------------------------------------------------
function GroundResolver.buildAlignedCFrame(position, normal)
	normal = normal or Vector3.new(0, 1, 0)

	-- Pick a stable forward vector
	local referenceForward = Vector3.new(0, 0, -1)
	if math.abs(normal:Dot(referenceForward)) > 0.95 then
		referenceForward = Vector3.new(1, 0, 0)
	end

	local right = referenceForward:Cross(normal).Unit
	local forward = normal:Cross(right).Unit

	return CFrame.fromMatrix(position, right, normal, forward)
end

return GroundResolver

local Pathfinding = {}
local PathfindingService = game:GetService("PathfindingService")

local pathCache = {} -- Store cached paths
local isPathCancelled = false

-- Clear the cache for a specific NPC
function Pathfinding.clearCache(npc)
	if pathCache[npc] then
		pathCache[npc] = nil
		Pathfinding.cancelPath()
	end
end

-- Clear the entire cache
function Pathfinding.clearAllCaches()
	pathCache = {}
end

function Pathfinding.resumePath()
	isPathCancelled = false
end

function Pathfinding.cancelPath()
	isPathCancelled = true
end

-- Helper function to follow the path
local function followPath(npc, path)
	local waypoints = path:GetWaypoints()
	local humanoid = npc.Humanoid

	for i, waypoint in ipairs(waypoints) do
		if isPathCancelled then
			print("Path cancelled.")
			break
		end
		if pathCache[npc] == nil then return end
		humanoid:MoveTo(waypoint.Position)

		-- Wait for the NPC to reach the waypoint
		humanoid.MoveToFinished:Wait()

		-- Optionally handle actions at the waypoint (e.g., jumping)
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid.Jump = true
		end
	end
end

function Pathfinding.path(npc, targetPosition)
	local startPos = npc.PrimaryPart.Position
	local pathparams = {
		["AgentHeight"] = 5,
		["AgentRadius"] = 3,
		["AgentCanJump"] = true,
		["WaypointSpacing"] = math.huge
	}
	local path = PathfindingService:CreatePath(pathparams)

	path:ComputeAsync(startPos, targetPosition)
	
	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		return waypoints
	else
		warn("Pathfinding failed for NPC:", npc.Name)
	end
end

-- Clear cache every 30 seconds to prevent memory bloat
task.spawn(function()
	while true do
		task.wait(30)
		Pathfinding.clearAllCaches()
	end
end)

return Pathfinding

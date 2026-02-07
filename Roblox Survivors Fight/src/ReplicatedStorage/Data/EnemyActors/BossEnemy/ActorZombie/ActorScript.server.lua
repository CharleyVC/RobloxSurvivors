local ZombieActor = {}
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local VisibilityMap = require(game.ServerScriptService.Scripts.PathfindingModules:WaitForChild("VisibilityMap"))
local Pathfinding = require(game.ServerScriptService.Scripts.PathfindingModules:WaitForChild("Pathfinding"))
local playAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("PlayAnimEvent")
--local ikSetEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("IKSet")
local enemiesFolder = game.Workspace:WaitForChild("Enemies")
local playersFolder = game.Workspace:WaitForChild("Players")

local data = {}

local actor = script:GetActor()
local npc = actor.Parent

local statusSheet = {
	Idle = 0,
	Pathfinding = 1,
	Chasing = 2,
}

local ZombieActor = {}
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local VisibilityMap = require(game.ServerScriptService.Scripts.PathfindingModules:WaitForChild("VisibilityMap"))
local Pathfinding = require(game.ServerScriptService.Scripts.PathfindingModules:WaitForChild("Pathfinding"))
local playAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("PlayAnimEvent")
--local ikSetEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("IKSet")
local enemiesFolder = game.Workspace:WaitForChild("Enemies")
local playersFolder = game.Workspace:WaitForChild("Players")

local data = {}

local actor = script:GetActor()
local npc = actor.Parent

local statusSheet = {
	Idle = 0,
	Pathfinding = 1,
	Chasing = 2,
}
------------------------------------------------------------
-- PARALLEL-SAFE SEPARATION CACHE
------------------------------------------------------------
local separationCache = {}
-- separationCache[npc] = {
--     t = lastUpdateTime,
--     ox = offsetX,
--     oz = offsetZ
-- }

local SEPARATION_RADIUS = 6           -- studs (tweak)
local SEPARATION_STRENGTH = 5         -- studs of offset (tweak)
local SEPARATION_MAX_NEIGHBORS = 8    -- cap work per NPC (mobile-safe)
local SEPARATION_UPDATE_RATE = 0.15   -- seconds (throttle)

-- Function to find the nearest player to a given position
local function findNearestPlayer(position)
	local nearestPlayer = nil -- Store the nearest player
	local shortestDistance = math.huge -- Initialize with a very large number
	if #players:GetPlayers() == 0 then return end
	-- Iterate through all players in the game
	for _, player in ipairs(players:GetPlayers()) do
		local character = player.Character -- Get the player's character
		if character and character.PrimaryPart then
			local distance = (character.PrimaryPart.Position - position).Magnitude -- Calculate distance
			if distance < shortestDistance then
				nearestPlayer = player -- Update the nearest player
				shortestDistance = distance -- Update the shortest distance
			end
		end
	end
	return nearestPlayer -- Return the nearest player (or nil if none are nearby)
end

local function getTables(npc)
	local propertiesScript = npc:FindFirstChild("Properties")
	if propertiesScript then
		local _table = require(propertiesScript)
		local animTable = _table.animTable
		local propTable = _table.propTable
		return animTable, propTable
	end
	return nil -- Return nil if the script is not found or invalid
end

local animTable, propTable = getTables(npc)
table.insert(data, {
	npc = npc, 
	animTable = animTable, 
	propTable = propTable,
	target = nil,
	status = 0,
	lastIK = 0
})

local function visualizeRay(startPosition, direction, raycastResult)
	task.synchronize()
	-- Create a part to represent the ray
	local rayPart = Instance.new("Part")
	rayPart.Size = Vector3.new(0.1, 0.1, direction.Magnitude) -- Size the part based on ray length
	rayPart.CFrame = CFrame.new(startPosition, startPosition + direction) * CFrame.new(0, 0, -rayPart.Size.Z / 2)
	rayPart.Anchored = true
	rayPart.CanCollide = false
	rayPart.CanQuery = false
	rayPart.BrickColor = raycastResult and BrickColor.new("Bright red") or BrickColor.new("Bright green")
	rayPart.Material = Enum.Material.Neon
	rayPart.Parent = workspace
	game:GetService("Debris"):AddItem(rayPart, 0.2)
end

-- Function to check line of sight using raycasting
local function hasLineOfSight(startPosition, targetPosition)
	local enemies = enemiesFolder:GetChildren()
	local playerlist = playersFolder:GetChildren()
	local direction = targetPosition - startPosition
	local raycastParams = RaycastParams.new()
	raycastParams:AddToFilter(enemies)
	raycastParams:AddToFilter(playerlist)
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude


	local raycastResult = workspace:Raycast(startPosition, direction, raycastParams)
	-- Visualize the ray
	--visualizeRay(startPosition, direction, raycastResult)
	return raycastResult == nil 
end

local function hasConeOfVision(startPosition, targetPosition, fovAngle, rayCount, maxDistance)
	local enemies = enemiesFolder:GetChildren()
	local playerlist = playersFolder:GetChildren()
	local directionToTarget = (targetPosition - startPosition).Unit
	local success = false
	local raycastParams = RaycastParams.new()
	raycastParams:AddToFilter(enemies)
	raycastParams:AddToFilter(playerlist)
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	for i = 0, rayCount - 1 do
		-- Calculate angle offset for each ray
		local angleOffset = (i - math.floor(rayCount / 2)) * (fovAngle / rayCount)
		local rotationCFrame = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(angleOffset))
		local rayDirection = rotationCFrame:VectorToWorldSpace(directionToTarget) * maxDistance

		-- Cast the ray
		local raycastResult = workspace:Raycast(startPosition, rayDirection, raycastParams)
		--visualizeRay(startPosition, rayDirection, raycastResult)

		if raycastResult == nil then
			success = true
			return success
		end
	end
	success = false
	return success
end

local function calculateDynamicDelay(distance)
	local baseDelay = 0.2 -- Minimum delay in seconds
	local maxDelay = 5 -- Maximum delay in seconds
	local maxDistance = 200 -- Maximum distance (map size)
	local exponent = 2 -- Controls how fast the delay grows

	-- Clamp distance to avoid excessive delays
	distance = math.min(distance, maxDistance)

	-- Calculate exponential delay
	local delayTime = baseDelay + maxDelay * ((distance / maxDistance) ^ exponent)

	return delayTime
end


local function pathFind(path, origin, destination)
	local success, errorMessage = pcall(function()
		path:ComputeAsync(origin, destination)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		return 
	end

	local waypoints = path:GetWaypoints()
	local next_waypoint_index = 2
	local path_not_safe = false 

	local blockedConnection = nil

	blockedConnection = path.Blocked:Connect(function(waypoint_index)
		if waypoint_index >= next_waypoint_index then
			path_not_safe = true
			blockedConnection:Disconnect()
		end
	end)

	return function()
		if path_not_safe then return false end		
		next_waypoint_index += 1

		if not waypoints[next_waypoint_index] then
			blockedConnection:Disconnect()
			return false
		end

		return waypoints[next_waypoint_index].Position
	end
end


local function movePath(data, targetPosition)
	local npc = data.npc
	local origin = npc.PrimaryPart.Position
	local waypoints = {}
	local pathparams = {
		["AgentHeight"] = 5,
		["AgentRadius"] = 3,
		["AgentCanJump"] = true,
	}
	local path = PathfindingService:CreatePath(pathparams)

	local nextWaypointFunction = pathFind(path, origin, targetPosition)
	if not nextWaypointFunction then return end

	while data.status ~= statusSheet.Idle and data.status ~= statusSheet.Chasing do


		local nextWaypoint = nextWaypointFunction()
		if not nextWaypoint then break end

		npc.Humanoid:MoveTo(nextWaypoint)
		npc.Humanoid.MoveToFinished:Wait()
		repeat
			local position = npc.PrimaryPart.Position
			local distance = (position - nextWaypoint).Magnitude
			npc.Humanoid:MoveTo(nextWaypoint)
			npc.Humanoid.MoveToFinished:Wait()
		until distance <= 5 or data.status == statusSheet.Idle or data.status == statusSheet.Chasing
	end
end

-- Start monitoring an NPC's attack behavior
function ZombieActor.attack(data)
	local npc = data.npc
	local propTable = data.propTable
	local target = data.target
	local npcPosition = npc.PrimaryPart.Position
	local attackDistance = propTable.attackDistance
	local attackCooldown = propTable.attackCooldown
	local damage = propTable.damage
	local lastAttackTick = data.lastAttackTick or 0

	if not target.Character then return end

	local distance = (npcPosition - target.Character.PrimaryPart.Position).Magnitude
	if distance <= attackDistance and math.abs(lastAttackTick - tick()) >= attackCooldown then
		if target.Character:FindFirstChild("Humanoid") then
			if target.Character:GetAttribute("IsInvulnerable") == true then
				-- Do not damage player if invulnerable
			else
				task.synchronize()
				target.Character.Humanoid:TakeDamage(damage)
			end
			task.synchronize()
			playAnimEvent:FireAllClients(npc,target, "Attack")
		end
		data.lastAttackTick = tick()
	end
end

local function computeSeparationOffset(npcModel: Model, npcPos: Vector3)
	local now = os.clock()

	local cache = separationCache[npcModel]
	if cache and now - cache.t < SEPARATION_UPDATE_RATE then
		return Vector3.new(cache.ox, 0, cache.oz)
	end

	local r = SEPARATION_RADIUS
	local r2 = r * r
	local pushX, pushZ = 0, 0
	local count = 0

	for _, other in ipairs(enemiesFolder:GetChildren()) do
		if other ~= npcModel then
			local ohrp = other:FindFirstChild("HumanoidRootPart")
			if ohrp then
				local dx = npcPos.X - ohrp.Position.X
				local dz = npcPos.Z - ohrp.Position.Z
				local d2 = dx*dx + dz*dz

				if d2 > 0.0001 and d2 < r2 then
					local inv = 1 / math.sqrt(d2)
					local falloff = 1 - (d2 / r2)

					pushX += dx * inv * falloff
					pushZ += dz * inv * falloff
					count += 1

					if count >= SEPARATION_MAX_NEIGHBORS then
						break
					end
				end
			end
		end
	end

	if count == 0 then
		separationCache[npcModel] = {
			t = now,
			ox = 0,
			oz = 0
		}
		return Vector3.zero
	end

	local mag = math.sqrt(pushX*pushX + pushZ*pushZ)
	if mag > 0.0001 then
		pushX = (pushX / mag) * SEPARATION_STRENGTH
		pushZ = (pushZ / mag) * SEPARATION_STRENGTH
	end

	separationCache[npcModel] = {
		t = now,
		ox = pushX,
		oz = pushZ
	}

	return Vector3.new(pushX, 0, pushZ)
end



debug.profilebegin("Batch")
function ZombieActor.processBatch(data)
	for _, data in ipairs(data) do
		local npc = data.npc
		local animTable = data.animTable
		local propTable = data.propTable
		local target = data.target
		local npcPosition = npc:FindFirstChild("HumanoidRootPart").Position
		local lastTick = data.lastTick or 0
		local stopDistance = propTable.stopDistance

		target = findNearestPlayer(npcPosition)
		task.synchronize()
		playAnimEvent:FireAllClients(npc, target, "FollowTarget")
		task.desynchronize()

		if not target then
			task.synchronize()
			data.status = statusSheet.Idle
			npc.Humanoid:MoveTo(npcPosition)
			task.desynchronize()
			break
		else
			data.target = target
		end

		local targetPosition = target.Character.PrimaryPart.Position
		local sepOffset = computeSeparationOffset(npc, npcPosition)
		targetPosition = targetPosition + sepOffset

		local distance = (npcPosition - targetPosition).Magnitude
		local dynamicDelay = calculateDynamicDelay(distance)

		if distance <= stopDistance then
			task.synchronize()
			data.status = statusSheet.Idle
			npc.Humanoid:MoveTo(npcPosition)
			task.desynchronize()
		else
			if math.abs(lastTick - tick()) >= dynamicDelay then

				local hasVision = hasConeOfVision(npcPosition, targetPosition, 40, 3, 50)
				data.lastTick = tick()

				if hasVision == true then
					task.synchronize()
					data.status = statusSheet.Chasing
					npc.Humanoid:MoveTo(targetPosition)
				else
					task.synchronize()
					data.status = statusSheet.Pathfinding
					movePath(data, targetPosition)
				end
			end
		end

		ZombieActor.attack(data)
	end
end
debug.profileend()

RunService.Heartbeat:ConnectParallel(function()
	ZombieActor.processBatch(data)
end)


return ZombieActor



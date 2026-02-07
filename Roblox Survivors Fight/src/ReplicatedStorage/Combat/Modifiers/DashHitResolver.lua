local ZombieActor = {}
local RunService = game:GetService("RunService")
local players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

-- Folders & Events
local playAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("PlayAnimEvent")
local enemiesFolder = game.Workspace:WaitForChild("Enemies")
local playersFolder = game.Workspace:WaitForChild("Players")

-- NPC Configuration
local actor = script:GetActor()
local npc = actor.Parent
local statusSheet = { Idle = 0, Pathfinding = 1, Chasing = 2 }

-- Logic Tables
local data = {}
local playerPositionsCache = {}
local separationCache = {}

-- Raycast Params (Pre-configured in Serial)
local visionParams = RaycastParams.new()
visionParams.FilterType = Enum.RaycastFilterType.Exclude

-- Settings
local SEPARATION_RADIUS = 6
local SEPARATION_STRENGTH = 5
local SEPARATION_UPDATE_RATE = 0.15

------------------------------------------------------------
-- INITIALIZATION
------------------------------------------------------------

local function getTables(npcModel)
	local propertiesScript = npcModel:FindFirstChild("Properties")
	if propertiesScript then
		local _table = require(propertiesScript)
		return _table.animTable, _table.propTable
	end
	return nil, nil
end

local animTable, propTable = getTables(npc)
if npc.PrimaryPart and propTable then
	table.insert(data, {
		npc = npc, 
		animTable = animTable, 
		propTable = propTable,
		target = nil,
		status = 0,
		waypoints = nil,
		currentWaypointIndex = 2,
		lastPathTarget = nil,
		lastAttackTick = 0
	})
end

------------------------------------------------------------
-- PARALLEL SAFE FUNCTIONS
------------------------------------------------------------

local function findNearestPlayer(npcPosition)
	local nearestPlayer = nil
	local shortestDistance = math.huge

	for _, pData in ipairs(playerPositionsCache) do
		local distance = (pData.Position - npcPosition).Magnitude
		if distance < shortestDistance then
			nearestPlayer = pData.Player
			shortestDistance = distance
		end
	end
	return nearestPlayer
end

local function hasConeOfVision(startPosition, targetPosition, fovAngle, rayCount, maxDistance)
	local directionToTarget = (targetPosition - startPosition).Unit

	for i = 0, rayCount - 1 do
		local angleOffset = (i - math.floor(rayCount / 2)) * (fovAngle / rayCount)
		local rotationCFrame = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(angleOffset))
		local rayDirection = rotationCFrame:VectorToWorldSpace(directionToTarget) * maxDistance

		-- workspace:Raycast is safe in parallel IF params are pre-set
		local raycastResult = workspace:Raycast(startPosition, rayDirection, visionParams)
		if raycastResult == nil then return true end
	end
	return false
end

local function computeSeparationOffset(npcModel, npcPos)
	local now = os.clock()
	local cache = separationCache[npcModel]
	if cache and now - cache.t < SEPARATION_UPDATE_RATE then
		return Vector3.new(cache.ox, 0, cache.oz)
	end

	local r2 = SEPARATION_RADIUS * SEPARATION_RADIUS
	local pushX, pushZ, count = 0, 0, 0

	for _, other in ipairs(enemiesFolder:GetChildren()) do
		if other ~= npcModel and other.PrimaryPart then
			local oPos = other.PrimaryPart.Position
			local dx, dz = npcPos.X - oPos.X, npcPos.Z - oPos.Z
			local d2 = dx*dx + dz*dz
			if d2 > 0.0001 and d2 < r2 then
				local inv = 1 / math.sqrt(d2)
				local falloff = 1 - (d2 / r2)
				pushX += dx * inv * falloff
				pushZ += dz * inv * falloff
				count += 1
				if count >= 8 then break end
			end
		end
	end

	local offset = Vector3.zero
	if count > 0 then
		local mag = math.sqrt(pushX*pushX + pushZ*pushZ)
		if mag > 0.0001 then
			offset = Vector3.new((pushX/mag)*SEPARATION_STRENGTH, 0, (pushZ/mag)*SEPARATION_STRENGTH)
		end
	end

	separationCache[npcModel] = {t = now, ox = offset.X, oz = offset.Z}
	return offset
end

------------------------------------------------------------
-- SERIAL REQUIRED FUNCTIONS (MOVEMENT / API)
------------------------------------------------------------

local function updatePathfinding(npcData, targetPosition)
	local npc = npcData.npc
	local root = npc.PrimaryPart
	if not root then return end

	local shouldRecompute = not npcData.waypoints or 
		(npcData.lastPathTarget and (npcData.lastPathTarget - targetPosition).Magnitude > 8)

	if shouldRecompute then
		local path = PathfindingService:CreatePath({AgentHeight = 5, AgentRadius = 3, AgentCanJump = true})
		path:ComputeAsync(root.Position, targetPosition)

		if path.Status == Enum.PathStatus.Success then
			npcData.waypoints = path:GetWaypoints()
			npcData.currentWaypointIndex = 2
			npcData.lastPathTarget = targetPosition
		end
	end

	if npcData.waypoints and npcData.waypoints[npcData.currentWaypointIndex] then
		local waypoint = npcData.waypoints[npcData.currentWaypointIndex]
		npc.Humanoid:MoveTo(waypoint.Position)
		if (root.Position - waypoint.Position).Magnitude < 4 then
			npcData.currentWaypointIndex += 1
		end
	end
end

function ZombieActor.attack(npcData)
	local target = npcData.target
	if not (target and target.Character and target.Character.PrimaryPart) then return end

	local npc = npcData.npc
	local prop = npcData.propTable
	local distance = (npc.PrimaryPart.Position - target.Character.PrimaryPart.Position).Magnitude

	if distance <= prop.attackDistance and (tick() - npcData.lastAttackTick) >= prop.attackCooldown then
		local hum = target.Character:FindFirstChild("Humanoid")
		if hum and target.Character:GetAttribute("IsInvulnerable") ~= true then
			hum:TakeDamage(prop.damage)
			playAnimEvent:FireAllClients(npc, target, "Attack")
		end
		npcData.lastAttackTick = tick()
	end
end

------------------------------------------------------------
-- BATCH PROCESSING
------------------------------------------------------------

function ZombieActor.processBatch(batchData)
	if #playerPositionsCache == 0 then
		task.synchronize()
		for _, npcData in ipairs(batchData) do
			npcData.status = statusSheet.Idle
		end
		return 
	end

	-- 1. PARALLEL PHASE
	local logicResults = {}
	for i, npcData in ipairs(batchData) do
		local root = npcData.npc.PrimaryPart
		if not root then continue end

		local npcPos = root.Position
		local nearest = findNearestPlayer(npcPos)

		if nearest and nearest.Character and nearest.Character.PrimaryPart then
			local tPos = nearest.Character.PrimaryPart.Position
			logicResults[i] = {
				target = nearest,
				targetPos = tPos + computeSeparationOffset(npcData.npc, npcPos),
				distance = (npcPos - tPos).Magnitude,
				hasVision = hasConeOfVision(npcPos, tPos, 40, 3, 50)
			}
		end
	end

	-- 2. SERIAL PHASE
	task.synchronize()
	for i, npcData in ipairs(batchData) do
		local res = logicResults[i]
		if not res then 
			npcData.target = nil
			continue 
		end

		npcData.target = res.target -- Used for Attack

		if res.distance <= npcData.propTable.stopDistance then
			npcData.status = statusSheet.Idle
			npcData.npc.Humanoid:MoveTo(npcData.npc.PrimaryPart.Position)
		elseif res.hasVision then
			npcData.status = statusSheet.Chasing
			npcData.npc.Humanoid:MoveTo(res.targetPos)
		else
			npcData.status = statusSheet.Pathfinding
			updatePathfinding(npcData, res.targetPos)
		end

		ZombieActor.attack(npcData)
	end
end

------------------------------------------------------------
-- MAIN LOOPS
------------------------------------------------------------

-- Serial Heartbeat: Handles API calls and property writes
RunService.Heartbeat:Connect(function()
	-- 1. Update Player Cache
	local newCache = {}
	for _, player in ipairs(players:GetPlayers()) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			table.insert(newCache, {
				Position = hrp.Position,
				Player = player
			})
		end
	end
	playerPositionsCache = newCache

	-- 2. Update Raycast Filter (Not parallel safe to assign)
	visionParams.FilterDescendantsInstances = {enemiesFolder, playersFolder}
end)

-- Parallel Heartbeat: Heavy Math
RunService.Heartbeat:ConnectParallel(function()
	if workspace:GetAttribute("IsPaused") then return end
	ZombieActor.processBatch(data)
end)

return ZombieActor
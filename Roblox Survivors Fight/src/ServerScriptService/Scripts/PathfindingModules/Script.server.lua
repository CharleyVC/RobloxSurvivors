local PathfindingService = game:GetService("PathfindingService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")


local PathfindingAgent = {}
PathfindingAgent.__index = PathfindingAgent


local function GetAgentPath(path, origin, destination)
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


local function FindRandomWalkVector(pos,range)
	local region_size = Vector3.new(4,4,4)
	local exhausted_count = 0
	local max_iter_count = 10

	repeat
		exhausted_count += 1
		local random_x = math.random(-range,range)	
		local random_z = math.random(-range,range)	

		local ub = pos + Vector3.new(random_x,0,random_z)
		local lb = pos - Vector3.new(random_x,0,random_z) + region_size

		local region = Region3.new(ub,lb)
		local isEmpty = game.Workspace:IsRegion3Empty(region)		
		if isEmpty then return ub end
	until
	exhausted_count >= max_iter_count
end


function PathfindingAgent:CreateAgent(agent, agent_settings)
	local self = setmetatable({}, PathfindingAgent)

	self.Agent = agent
	self.Settings = agent_settings
	self.is_activated = nil

	self.movement_states = {
		InPath = 0,
		WaitingForPath = 1,
		Idling = 2,
		Dead = 3,
		Pathfinding = 4,	
		Chasing = 5,
	}

	self.status_states = {
		Activated = 0,
		DeActivated = 1,
		Contained = 2,
	}

	self.curr_movement_state = self.movement_states.Idling
	self.curr_status_state = self.status_states.DeActivated

	self.update_connection = nil

	self.Humanoid = self.Agent:WaitForChild("Humanoid")
	self.HumanoidRootPart = self.Agent:WaitForChild("HumanoidRootPart")
	self.Torso = self.Agent:WaitForChild("Torso")

	_, self.bounding_box = self.Agent:GetBoundingBox()

	for i, part in pairs(self.Agent:GetChildren()) do 
		if part:IsA("BasePart") then 
			part:SetNetworkOwner(nil) 
		end
	end

	return self
end


function PathfindingAgent:Activate()
	self.update_connection = RunService.Heartbeat:Connect(function(dt)
		self:Update(dt)
	end)

	self.is_activated = true
end


function PathfindingAgent:Disable()
	if not self.is_activated then return end

	self.update_connection:Disconnect()
	self.current_movement_state = self.Movemenet_States.Idle
end


function PathfindingAgent:FindClosestTarget()
	local player_list = Players:GetPlayers()
	local target, smallest_distance = nil, math.huge

	for _, player in ipairs(player_list) do
		local character = player.Character
		if not character then return end

		local position = character.HumanoidRootPart.Position
		local difference = position - self.HumanoidRootPart.Position
		local distance = difference:Dot(difference)

		if smallest_distance > distance then
			smallest_distance = distance
			target = player
		end
	end

	if not target then
		return warn("No Closest Target Found")
	end

	return target.Character, smallest_distance
end


function PathfindingAgent:StraightLineToTarget(target)
	if not target then return end

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {self.Agent}
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist

	local origin = self.HumanoidRootPart.Position
	local target_pos = target.HumanoidRootPart.Position
	local target_cf = target.HumanoidRootPart.CFrame
	local direction = (target_pos - origin)

	local sign = math.sign(direction:Dot(target_cf.RightVector))
	local bounding_box = self.bounding_box
	local scp_off = self.HumanoidRootPart.CFrame * Vector3.new(-sign * bounding_box.X / 2,0, bounding_box.Z/2)

	local rayResults = workspace:Raycast(scp_off, target_pos - scp_off, rayParams)
	if not rayResults then return end	

	if rayResults.Instance.Parent == target then
		return true
	end	

	return false
end


function PathfindingAgent:PathfindToTarget(target)
	--// The difference of this function to PATHFINDTOPOSITION
	--   is that we will not interrupt the state of pathfinding here

	local reachedConnection = nil
	local path_object = PathfindingService:CreatePath({
		AgentRadius = 4,
		AgentHeight = 1,
		AgentCanJump = false,
	})

	local origin = self.HumanoidRootPart.Position
	local destination = target.HumanoidRootPart.Position
	local PATH = GetAgentPath(path_object, origin, destination)
	if not PATH then 
		self.curr_movement_state = self.movement_states.WaitingForPath
		return
	end

	while self.curr_movement_state ~= self.movement_states.Idling or 
		self.curr_movement_state ~= self.movement_states.Chasing
	do
		local next_point = PATH()		
		if not next_point then break end

		self.Humanoid:MoveTo(next_point)

		repeat	
			local org = self.HumanoidRootPart.Position
			local dist = (org - next_point):Dot(org - next_point)
			self.Humanoid:MoveTo(next_point)
			RunService.Heartbeat:Wait()
		until 
		dist <= self.Settings.Waypoint_Threshold * self.Settings.Waypoint_Threshold or 
			self.curr_movement_state == self.movement_states.Idling or 
			self.curr_movement_state == self.movement_states.Chasing
	end

	if self.curr_movement_state == self.movement_states.Pathfinding then
		self.curr_movement_state = self.movement_states.WaitingForPath
	end
end


function PathfindingAgent:PathfindToPosition()

end


function PathfindingAgent:ChaseTarget(target)
	--// Simply just MoveTo the target :-)

	while self.curr_movement_state ~= self.movement_states.Idling do
		if not self:StraightLineToTarget(target) then
			break	
		end

		self.Humanoid:MoveTo(target.HumanoidRootPart.Position)
		RunService.Heartbeat:Wait()
	end

	self.curr_movement_state = self.movement_states.WaitingForPath
end


function PathfindingAgent:Update()	
	if not self.status_states == self.status_states.Activated then
		return 
	end	

	local closest_target, distance_sq = self:FindClosestTarget()
	local target = nil
	if closest_target then
		target = distance_sq < self.Settings.SCP_RANGE * self.Settings.SCP_RANGE and closest_target or nil
	end

	if not target then 
		self.curr_movement_state = self.movement_states.Idling

		local random_walk_bounds = self.Settings.RandomWalkBounds
		local random_walk_vector = nil--FindRandomWalkVector(random_walk_bounds)		

		self:PathfindToPosition(random_walk_vector)

		return
	end

	if self.curr_movement_state == self.movement_states.Pathfinding then
		if self:StraightLineToTarget(target) then
			self.curr_movement_state = self.movement_states.Chasing
			self:ChaseTarget(target)

			return
		end
	elseif self.curr_movement_state == self.movement_states.WaitingForPath then
		--// Start walking in order to reduce possible frames spent stuttering
		self.Humanoid:MoveTo( self.HumanoidRootPart.CFrame * Vector3.new(0,0,-5) )
	elseif self.curr_movement_state == self.movement_states.Chasing then
		--// Else we are chasing, no need to do anything
		return
	end

	self.curr_movement_state = self.movement_states.Pathfinding
	self:PathfindToTarget(target)
end


return PathfindingAgent
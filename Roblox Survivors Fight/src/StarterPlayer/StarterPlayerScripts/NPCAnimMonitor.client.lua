local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local animationHandler = require(game.ReplicatedStorage:WaitForChild("AnimationHandler"))
local enemiesFolder = game.Workspace:WaitForChild("Enemies")
local animMonitor = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("MonitorMovement")
local playAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("PlayAnimEvent")
local deathAnimEvent = game.ReplicatedStorage.RemoteEvents.NPCRemoteEvents:WaitForChild("DeathAnim")
--local playSoundEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundEvent")
--local playSoundDeathEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundDeathEvent")
--local playSoundHitEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundHitEvent")
--local playSoundSwingEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundSwingEvent")
--local playSoundStepEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundStepEvent")
--local playSoundFootstepEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("PlaySoundFootstepEvent")
--local playSoundJumpEvent = game

--MAIN SCRIPT TO MONITOR NPC ANIMATIONS THIS MAKES CLIENT HANDLE ALL ENEMY ANIMATIONS
-- Keyed by specificType (e.g. "RegZombie")
local animDefsCache = {}

npcList = {} 
local lastUpdateTime = 0

npcList = {} 
local lastUpdateTime = 0

-- Optional: legacy helper if you still need random chains; not used by the new system
local function iKSet(enemy, target)
	if not enemy or not target then return end
	local humanoid = enemy:FindFirstChild("Humanoid")
	if not humanoid then return end

	local ikArm = humanoid:FindFirstChild("ikArm")
	local ikHead = humanoid:FindFirstChild("ikHead")
	if not ikArm and not ikHead then return end

	local targetPart = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
	if not targetPart then return end

	if ikArm then
		ikArm.Target = targetPart
	end
	if ikHead then
		ikHead.Target = targetPart
	end
end

local function applyIK(npc, target)
	if not npc or not target then return end

	local humanoid = npc:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Resolve Player → Character or accept Model
	local character
	if typeof(target) == "Instance" then
		if target:IsA("Player") then
			character = target.Character
		elseif target:IsA("Model") then
			character = target
		end
	end
	if not character then return end

	local targetPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
	if not targetPart then return end

	local ikArm = humanoid:FindFirstChild("ikArm")
	local ikHead = humanoid:FindFirstChild("ikHead")

	if ikArm then ikArm.Target = targetPart end
	if ikHead then ikHead.Target = targetPart end
end



playAnimEvent.OnClientEvent:Connect(function(npcModel, target, mode)
	local animTable = npcList[npcModel]
	if not animTable then return end

	animTable.target = target  -- always assign target now
	if mode == "Attack" then
		animTable.state = "Attack"
		animationHandler.playAnimation(animTable)
	else
		animTable.target = target
	end
end)


-- Handle NPC death
deathAnimEvent.OnClientEvent:Connect(function(npcModel)
	if not npcModel or not npcModel:IsA("Model") then return end

	-- Check if the NPC is in npcList
	local animTable = npcList[npcModel]
	if not animTable then return end

	-- Remove any active highlights on death
	for _, descendant in ipairs(npcModel:GetDescendants()) do
		if descendant:IsA("Highlight") then
			descendant:Destroy()
		end
	end

	for npc, _ in pairs(npcList) do
		if npc == npcModel then
			npcList[npc] = npcList[#npcList]
			npcList[#npcList] = nil
			break
		end
	end

	-- Play the death animation
	animationHandler.deathRemains(npcModel)
end)


animMonitor.OnClientEvent:Connect(function(npcModel, animTable)
	if not npcModel or not npcModel:IsDescendantOf(workspace) then return end
	local humanoid = npcModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local runtimeAnim = table.clone(animTable)
	runtimeAnim.humanoid = humanoid

	local category = runtimeAnim.category
	local specificType = runtimeAnim.specificType

	-- 1) cache defs ONCE per type
	if not animDefsCache[specificType] then
		animDefsCache[specificType] = animationHandler.getAnimationDefs(category, specificType)
	end

	-- 2) bind tracks PER NPC (required)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)

	local tracks = {}
	for name, anim in pairs(animDefsCache[specificType]) do
		tracks[name] = animator:LoadAnimation(anim)
	end

	runtimeAnim.animations = tracks
	npcList[npcModel] = runtimeAnim
end)

RunService.RenderStepped:Connect(function()
	if tick() - lastUpdateTime >= 0.2 then
		for npc, animTable in pairs(npcList) do
			if npc.Parent == enemiesFolder then

				animationHandler.monitorMovement(animTable)

				-- NEW: client IK always runs if target exists
				if animTable.target then
					applyIK(npc, animTable.target)
				end

			end
		end
		lastUpdateTime = tick()
	end
end)

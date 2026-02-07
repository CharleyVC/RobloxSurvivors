     -- AnimationHandler ModuleScript

local AnimationHandler = {}
local runService =game:GetService('RunService')
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")
local sfxModule = require(game.ReplicatedStorage:WaitForChild("SFXModule"))
local sprintEvent = game.ReplicatedStorage.BindableEvents:WaitForChild("MobileSprintEvent")

local animationTracks = {} -- Store animation tracks by character and category

local function isActionState(state)
	return state == "Attack" or state == "Death" or state == "Hit"
end

-- Function to load animations from ReplicatedStorage based on the object type and specific enemy/weapon type
function AnimationHandler.getAnimationFolder(category, specificType)
	local animationsFolder
	if category == "Weapon" then 
		animationsFolder = game.ReplicatedStorage.Data.Weapons[specificType]:FindFirstChild("Animations")
		return animationsFolder
	elseif category == "Ability" then
		animationsFolder = game.ReplicatedStorage.Data.Abilities[specificType]:FindFirstChild("Animations")
		return animationsFolder
	else
		animationsFolder = game.ReplicatedStorage.Data.Enemies:FindFirstChild("EnemyAnimations")
	end
	if not animationsFolder then
		warn("Animations folder not found in ReplicatedStorage.")
		return nil
	end
	
	local typeTable = {
		"Zombie",
		"Skeleton"
	}
	
	local specificAnimationsFolder
	if specificType then
		local prefix
		local suffix
		
		for _,i in typeTable do
			if specificType:match(i) then
				prefix = specificType:match(".*"..i) -- catches the prefix
				suffix = specificType:match(i.."$") -- catches the suffix
			end
		end
		if prefix then	
			specificAnimationsFolder = animationsFolder:FindFirstChild(suffix)
		else
			specificAnimationsFolder = animationsFolder:FindFirstChild(specificType)
		end
	end

	if not specificAnimationsFolder then
		warn("No animations found for specific type: " .. specificType)
		return {}
	end

	return specificAnimationsFolder
end

function AnimationHandler.getAnimationDefs(category, specificType)
	local folder = AnimationHandler.getAnimationFolder(category, specificType)
	local defs = {}
	if not folder then return defs end

	for _, anim in ipairs(folder:GetChildren()) do
		if anim:IsA("Animation") then
			defs[anim.Name] = anim -- cache Animation instances (safe to share)
		end
	end
	return defs
end


function AnimationHandler.getAnimations(specificAnimationsFolder)
	local animations = {}
	for _, animation in ipairs(specificAnimationsFolder:GetChildren()) do
		if animation:IsA("Animation") then
			animations[animation.Name] = animation
		end
	end
	return animations
end

function AnimationHandler.loadAnimations(characterOrTool, category, specificType)
	-- Ensure storage for this character and category
	animationTracks[characterOrTool] = animationTracks[characterOrTool] or {}
	animationTracks[characterOrTool][category] = {}

	-- Fetch the appropriate animation folder in ReplicatedStorage based on objectType (NPC or Weapon)
	local humanoid = characterOrTool:WaitForChild("Humanoid")
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local specificAnimationsFolder = AnimationHandler.getAnimationFolder(category, specificType)

	local animations = {}
	
	-- Load animations from the specific subfolder inside the object type folder
	for _, animation in ipairs(specificAnimationsFolder:GetChildren()) do
		if animation:IsA("Animation") then
			local track = animator:LoadAnimation(animation)
			animationTracks[characterOrTool][category][animation.Name] = track
			animations[animation.Name] = track
		end
	end

	return animations
end

-- Function to get a specific animation track
function AnimationHandler.getAnimationTrack(character, category, animationName)
	if animationTracks[character] and animationTracks[character][category] then
		return animationTracks[character][category][animationName]
	else
		warn("Animation track not found:", category, animationName)
		return nil
	end
end


-- Function to play an animation based on the current state (idle, running, attacking, etc.)
function AnimationHandler.playAnimation(animationTable)
	local humanoid = animationTable.humanoid
	local category = animationTable.category
	local animations = animationTable.animations
	local specificType = animationTable.specificType
	local state = animationTable.state
	local weight = animationTable.weight
	local target = animationTable.target
	
	-- Keep track of the currently playing animation
	-- Stop all other animations for a specific state (but not idle or attack animations)
	for name, track in pairs(animations) do
		-- Only stop animations that belong to a conflicting layer
		if name ~= state and track.IsPlaying then
			-- Stop only animations that affect the same parts of the body
			local conflicting = (name == "Idle" or name == "Run" or name == "Walk") and (state == "Idle" or state == "Run" or state == "Walk")
			if conflicting then
				track:Stop()
			end
		end
	end
	
	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
	end

	-- Find a specific attack animation (e.g., AttackL, AttackR)
	local attackAnimations = {}
	for name, track in pairs(animations) do
		if typeof(track) == "Instance" and track:IsA("AnimationTrack") and name:match("^Attack") then
			table.insert(attackAnimations, track)
		end
	end
	

	local animationTrack
	local IKControl = humanoid.Parent:FindFirstChild("IKControl")
	local IKLeft = humanoid.Parent:FindFirstChild("IKLeft")
	local IKRight = humanoid.Parent:FindFirstChild("IKRight")
	
	-- Handle dynamic attack animations
	if state == "Attack" then
		-- Select a random or specific attack animation
		if #attackAnimations > 0 then
			animationTrack = attackAnimations[math.random(1, #attackAnimations)]
			--animationTrack.Looped = true
			if animationTrack  and animationTrack.Name == "Attack L" then
				--IKLeft.Target = target
				--IKLeft.Weight = 0.5
			end
			if animationTrack  and animationTrack.Name == "Attack R" then
				--IKRight.Target = target
				--IKRight.Weight = 0.5
			end
			if IKControl then
				--IKControl.Target = target -- Define desired target position for IK		
				--IKControl.Weight = 0.5
			end
		end
	else

		animationTrack = animations[state]

		if (state == "Walk" or state == "Run") and animationTrack and not animationTrack:GetAttribute("FootstepHooked") then
			animationTrack:SetAttribute("FootstepHooked", true)
			animationTrack:GetMarkerReachedSignal("Footstep"):Connect(function(footSide)
				if footSide == "Left" or footSide == "Right" then
					sfxModule.Footstep(humanoid.Parent, footSide)
				end
			end)
		end
	end
	-- Play the selected animation if not already playing
	if animationTrack and not animationTrack.IsPlaying then
		animationTrack:Play()
		-- Special handling for attack animations
		if state == "Attack" then
			animationTrack:AdjustWeight(1)
			if animationTrack == "Attack L" then
				--IKLeft.Weight = 0
			end
			if animationTrack == "Attack R" then
				--IKRight.Weight = 0
			end
			if IKControl then	
				--IKControl.Weight = 0
			end
		else
			animationTrack:AdjustWeight(weight or 1.0) -- Full weight for movement animations
		end
	end
end

local RunKey = Enum.KeyCode.LeftShift -- Change this to your key
local Duration = 0.2 -- How long it will take to change from the Walk to Run

local setSprint = false
sprintEvent.Event:Connect(function(isSprinting)
	setSprint = isSprinting
end)

-- Function to monitor and update the character's animation state based on movement
function AnimationHandler.monitorMovement(animationTable)
	
	local walkSpeed
	local runSpeed
	
	local humanoid = animationTable.humanoid
	local hrt = 0
	
	
	if animationTable.category == "Enemy" then
		walkSpeed = humanoid.WalkSpeed
		hrt = humanoid.Parent:WaitForChild("HumanoidRootPart").AssemblyLinearVelocity.Magnitude
	else
		runSpeed = humanoid:GetAttribute("RunSpeed") or 25
		walkSpeed = humanoid:GetAttribute("WalkSpeed") or 16
	end
	
	local sprintActivate =
		(animationTable.isSprinting and animationTable.isSprinting())
		or setSprint

	
	if humanoid.MoveDirection.Magnitude > 0 or hrt > 0.001 then
		if sprintActivate and animationTable.category == "Weapon" then
			-- Blend running animation with attack
			animationTable.state = "Run"
			animationTable.weight = .8
			AnimationHandler.playAnimation(animationTable)
			humanoid.WalkSpeed = runSpeed
		else
			-- Blend walking animation with attack
			animationTable.state = "Walk"
			animationTable.weight = .8
			AnimationHandler.playAnimation(animationTable)
			humanoid.WalkSpeed = walkSpeed
		end
	else
		-- Play idle animation if not attacking
		animationTable.state = "Idle"
		animationTable.weight = 1
		AnimationHandler.playAnimation(animationTable)
	end
end

function AnimationHandler.stopAnimation(animationTable)
	local state = animationTable.state
	local animations = animationTable.animations
	animations[state]:Stop()
end

function AnimationHandler.getAllTracksForCharacter(character)
	return animationTracks[character]
end

function AnimationHandler.deathRemains(npc)
	-- Clone the visual parts of the NPC for remains
	if math.random(0,1) <= 0.3 then
		local remains = Instance.new("Model")
		remains.Name = npc.Name .. "_Remains"

		-- Get the primary part of the NPC to use as the reference for positioning
		local primaryPart = npc.PrimaryPart
		if not primaryPart then
			warn("NPC has no PrimaryPart. Remains might not be positioned correctly.")
		end


		for _, part in ipairs(npc:GetDescendants()) do
			if part:IsA("BasePart") then
				local clonePart = part:Clone()
				clonePart.Anchored = false
				clonePart.CanCollide = true
				if primaryPart then
					-- Position the cloned part relative to the NPC's primary part
					clonePart.CFrame = primaryPart.CFrame * (primaryPart.CFrame:Inverse() * part.CFrame)
				end
				clonePart.Parent = remains
			elseif part:IsA("Accessory") then
				-- Clone accessories for visual consistency
				local cloneAccessory = part:Clone()
				cloneAccessory.Parent = remains
			end
		end

		remains.Parent = workspace.Remains
		task.delay(2, function()
			for _, part in ipairs(workspace.Remains:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		end)



		-- Schedule destruction of the remains after a delay
		task.delay(5, function()
			if remains and remains.Parent then
				remains:Destroy()
			end
		end)
	end
end

return AnimationHandler

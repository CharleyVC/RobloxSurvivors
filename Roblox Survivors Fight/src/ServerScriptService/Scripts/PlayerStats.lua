local RunService = game:GetService("RunService")
local CollisionGroupManager = require(game.ServerScriptService.Scripts:WaitForChild("CollisionGroupManager"))
local AnimationHandler = require(game.ReplicatedStorage:WaitForChild("AnimationHandler"))
local WeaponService = require(game.ServerScriptService.Scripts:WaitForChild("WeaponService"))
local DashService = require(game.ServerScriptService.Scripts:WaitForChild("DashService"))
local ModifierRegistrationService =	require(game.ServerScriptService.Scripts:WaitForChild("ModifierRegistrationService"))
local ModifierSetLibrary = require(game.ReplicatedStorage.Combat:WaitForChild("ModifierSetLibrary"))
local SlotContext = require(game.ServerScriptService.Scripts:WaitForChild("SlotContext"))
local BoonService = require(game.ServerScriptService.Scripts:WaitForChild("BoonService"))
local levelUpEvent = game.ReplicatedStorage.BindableEvents:WaitForChild("LevelUpEvent")

local PlayerStats = {}

-- Function to start health regeneration
function PlayerStats.startHealthRegen(player, profile)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end

	-- Start health regeneration loop
	task.spawn(function()
		local alive = true
		humanoid.Died:Once(function()
			alive = false
		end)
		
		while alive do
			-- Get the regen rate from MetaUpgrades
			local healthRegen = profile.Data.MetaUpgrades.HealthRegen or 0
			if healthRegen > 0 then
				-- Increment health
				humanoid.Health = math.clamp(humanoid.Health + healthRegen, 0, humanoid.MaxHealth)
			end

			-- Wait for 1 second before the next regen tick (adjust interval as needed)
			task.wait(3)
		end
	end)
end

function PlayerStats.disableJumping(player)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Disable the Jumping state
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetAttribute("JumpDisabled", true)

		-- Ensure jump power and jump ability are set to 0
		humanoid.JumpPower = 0
		humanoid.UseJumpPower = true
	end
end

local function setCharacterMass(character: Model, targetMass: number)
	local parts = {}
	local totalVolume = 0

	for _, inst in ipairs(character:GetDescendants()) do
		if inst:IsA("BasePart") and inst.CanCollide then
			table.insert(parts, inst)
			totalVolume += inst.Size.X * inst.Size.Y * inst.Size.Z
		end
	end

	if totalVolume <= 0 then return end

	-- Density needed to reach target mass
	local density = targetMass / totalVolume

	for _, part in ipairs(parts) do
		part.Massless = false
		part.CustomPhysicalProperties = PhysicalProperties.new(
			density,  -- Density
			0.5,      -- Friction
			0.2,      -- Elasticity
			1,        -- FrictionWeight
			1         -- ElasticityWeight
		)
	end
end


-- Initialize stats for a new run
function PlayerStats.initializeStats(player, profile)
	local character = player.Character
	if not profile then
		warn("Profile is nil for player:", player.Name)
		return
	end
	if not character then
		return
	end
	local humanoid = character:WaitForChild("Humanoid")
	-- Initialize default stats (existing functionality)

	-- Reset run-specific attributes
	character:SetAttribute("RunCoins", 0) -- Coins specific to the current run
	character:SetAttribute("RunExperience", 0)
	character:SetAttribute("RunLevel", 1)

	local metaUpgrades = profile.Data.MetaUpgrades
	if not profile.Data then
		warn("Profile.Data is nil for player:", player.Name)
		return
	end
	if not metaUpgrades then
		warn("Profile.Data.MetaUpgrades is nil for player:", player.Name)
		return
	end
	
	-- Set additional run-specific attributes
	character:SetAttribute("MagnetRange", metaUpgrades.MagnetRange)
	character:SetAttribute("Stamina", metaUpgrades.MaxStamina)
	character:SetAttribute("AttackSpeed", metaUpgrades.BaseAttackSpeed)
	character:SetAttribute("HealthRegen", metaUpgrades.HealthRegen) -- Set initial regen value
	character:SetAttribute("Defense", 0) -- Reset defense for the run
	character:SetAttribute("RunScore", 0) -- Start a new score for this run
	character:SetAttribute("ExperienceMax", 1)
	character:SetAttribute("IsInvulnerable", false)

	PlayerStats.disableJumping(player)
	PlayerStats.startHealthRegen(player, profile)
	CollisionGroupManager.setCollisionGroup(character, "Players")
	setCharacterMass(character, 45)
	
	SlotContext.InitCharacter(character)
	BoonService.InitCharacter(character)
	WeaponService.initializeFromProfile(player, profile)
	ModifierRegistrationService.RegisterSet(character,ModifierSetLibrary.GetGeneric())
	
	character:SetAttribute("InitializedWeapon", true)
	character:SetAttribute("InitializedAbilities", true)
	
end

local function updateLeaderstats (player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local runScore = leaderstats:FindFirstChild("Run Score")
		local highestScore = leaderstats:FindFirstChild("High Score")
		if runScore then
			runScore.Value = player.Character:GetAttribute("RunScore")
			-- Update the highest session score if needed
			if highestScore and runScore.Value > highestScore.Value then
				highestScore.Value = runScore.Value
			end
		end
	end
end

function PlayerStats.add(player, object, amount)
	local character = player.Character
	if not character then
		return
	end
	
	local storedRunScore = character:GetAttribute("RunScore") or 0
	local storedObjectAmount = character:GetAttribute(object) or 0
	character:SetAttribute(object, storedObjectAmount + amount)
	character:SetAttribute("RunScore", storedRunScore + amount)
	updateLeaderstats(player)
	
	if object == "RunExperience" then
		local level = character:GetAttribute("RunLevel") or 1
		local expThreshold = 100 * level * (level - 1) * 0.5   -- D&D Level Scaling is used for now.
		character:SetAttribute("ExperienceMax", expThreshold)
		if storedObjectAmount >= expThreshold then
			character:SetAttribute("RunExperience", storedObjectAmount - expThreshold) -- Carry over excess experience
			character:SetAttribute("RunLevel", level + 1) -- Level up			
			PlayerStats.levelUp(player, expThreshold)
		end
	end
end

function PlayerStats.levelUp(player)
	local character = player.Character
	local level = character:GetAttribute("RunLevel")
	levelUpEvent:Fire(player)
	print(player.Name.." is now level "..level)
end






return PlayerStats
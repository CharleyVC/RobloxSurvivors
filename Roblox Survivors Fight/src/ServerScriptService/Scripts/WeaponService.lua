local WeaponService = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Modules
local profileManager = require(ServerScriptService.Scripts:WaitForChild("ProfileManager"))
local effectsAuthority = require(ServerScriptService.Scripts:WaitForChild("EffectsAuthority"))
local filtersModule = require(ServerScriptService.Scripts:WaitForChild("FiltersModule"))
local weaponProperties = require(ServerScriptService.Scripts:WaitForChild("WeaponProperties"))


local ActionModifierService = require(ReplicatedStorage.Combat.ActionModifierService)
local ActionContext = require(ReplicatedStorage.Combat.ActionContext)
local ActionPhases = require(ReplicatedStorage.Combat.ActionPhases)

local ModifierSetLibrary = require(game.ReplicatedStorage.Combat:WaitForChild("ModifierSetLibrary"))
local ModifierRegistrationService = require(game.ServerScriptService.Scripts:WaitForChild("ModifierRegistrationService"))

-- Remote / bindable events
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local npcRemoteEvents = remoteEvents:WaitForChild("NPCRemoteEvents")
local weaponAttackEvent = remoteEvents:WaitForChild("WeaponAttack")
local weaponSelectedEvent = remoteEvents:WaitForChild("WeaponSelected")
local equipEvent = remoteEvents:WaitForChild("EquipEvent")
local vfxEvent = remoteEvents:WaitForChild("VFXEvent")
local RateLimiter = require(ServerScriptService.Scripts:WaitForChild("RateLimiter"))


local LastAttackTimes = {} 
-- structure:
-- LastAttackTimes[player] = { Primary = time, Secondary = time }

-- State
local isPaused = false

------------------------------------------------------------
-- Pause handling
------------------------------------------------------------

------------------------------------------------------------
-- Utility: primary vs secondary
------------------------------------------------------------
local function isPrimary(baseAction)
	-- Normalized string input from WeaponClient
	if baseAction == "Primary" then
		return true
	elseif baseAction == "Secondary" then
		return false
	end

	-- Optional: support raw input enums if ever used
	if typeof(baseAction) == "EnumItem" then
		if baseAction == Enum.UserInputType.MouseButton1 then
			return true
		elseif baseAction == Enum.UserInputType.MouseButton2 then
			return false
		end
	end

	return nil
end


------------------------------------------------------------
-- Weapon equip / initialization
------------------------------------------------------------

function WeaponService.initializeFromProfile(player, profile)
	if not profile or not profile.Data then return end

	local weaponName = profile.Data.EquippedWeapon
	if not weaponName or weaponName == "None" then
		warn("No weapon equipped for", player.Name)
		weaponName = "Fireball"
		return
	end
	
	WeaponService.initializeWeapon(player, weaponName)
end

---- Creates the weapon selection GUI and wires it for this player.
--function WeaponService.initializeWeaponSelection(player)
--	if not player or not player:IsDescendantOf(Players) then
--		return
--	end

--	local playerGui = player:WaitForChild("PlayerGui")
--	local selectionGuiTemplate = ReplicatedStorage:WaitForChild("PlayerGui"):WaitForChild("WeaponSelectionGui")
--	local selectionGui = selectionGuiTemplate:Clone()
--	selectionGui.Parent = playerGui

--	local frame = selectionGui:WaitForChild("WeaponSelectionFrame")
--	local layout = frame:WaitForChild("Layout")
--	local confirmButton = layout:WaitForChild("ConfirmButton")

--	-- Show on spawn
--	player.CharacterAdded:Connect(function()
--		frame.Visible = true
--	end)

--	confirmButton.MouseButton1Click:Connect(function()
--		-- NOTE: currently still hard-coded to "Fireball", as in original script.
--		-- Later you can wire this to whichever weapon button the player actually picked.
--		frame.Visible = false
--		WeaponService.initializeWeapon(player, "Fireball")
--	end)
--end

-- Equip / spawn a specific weapon for a player
function WeaponService.initializeWeapon(player, weaponName)
	if not player or not weaponName then
		return
	end

	local weaponsDataFolder = ReplicatedStorage:WaitForChild("Data"):WaitForChild("Weapons")
	local weaponFolder = weaponsDataFolder:FindFirstChild(weaponName)
	if not weaponFolder then
		warn("WeaponService: weapon folder not found for", weaponName)
		return
	end

	local weaponTemplate = weaponFolder:FindFirstChild(weaponName)
	if not weaponTemplate then
		warn("WeaponService: weapon template not found inside folder for", weaponName)
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local profile = profileManager.GetProfile(player)

	local clonedWeapon = weaponTemplate:Clone()
	clonedWeapon.Name = weaponName
	
	
	ModifierRegistrationService.RegisterSet(character,ModifierSetLibrary.GetForWeapon(weaponName))
	WeaponService.attachClientLogic(clonedWeapon, player)

	if profile then
		profile.Data.EquippedWeapon = weaponName
	else
		warn("WeaponService: profile not found for player when equipping", player.Name)
	end
end

-- Simple accessor for weapon properties
function WeaponService.Properties(weapon)
	return weaponProperties[weapon]
end

-- Attach weapon to character and notify client via EquipEvent
function WeaponService.attachClientLogic(weapon, player)
	if not weapon or not player then
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	weapon.Parent = character

	-- Tell this client which weapon is equipped (WeaponClient listens to this)
	equipEvent:FireClient(player, weapon.Name)
end

------------------------------------------------------------
-- Server-authoritative hit resolution (projectiles)
------------------------------------------------------------

local function findEnemyFromHit(hitResult: RaycastResult?): Model?
	if not hitResult or not hitResult.Instance then
		return nil
	end
	local model = hitResult.Instance:FindFirstAncestorOfClass("Model")
	if not model then
		return nil
	end
	if not model:IsDescendantOf(Workspace:WaitForChild("Enemies")) then
		return nil
	end
	return model
end

local function buildHitContext(character: Model, weapon: string, baseAction: string, hitModel: Model?, hitPosition: Vector3)
	local props = weaponProperties[weapon]
	if not props or not props[baseAction] then
		return nil
	end

	local baseType = props[baseAction].Type
	local radius = props[baseAction].Radius or 0
	local damage = props[baseAction].Damage or 0
	local knockBack = props[baseAction].Knockback or 0
	local tags = props[baseAction].Tags

	local context = ActionContext.new({
		Actor = character,
		Action = baseAction,
		BaseType = baseType,
		Source = weapon,
		Tags = tags,
		Damage = damage,
		Radius = radius,
		Knockback = knockBack,
	})

	if props[baseAction].AoE then
		context.AoE = {
			Duration = props[baseAction].AoE.Duration,
			TickRate = props[baseAction].AoE.TickRate
		}
	end

	if props[baseAction].Burn then
		context.Burn = {
			Mode = props[baseAction].Burn.Mode,
			Damage = props[baseAction].Burn.Damage,
			Duration = props[baseAction].Burn.Duration,
			Stacks = props[baseAction].Burn.Stacks,
			Knockback = props[baseAction].Burn.Knockback,
			Maxstacks = props[baseAction].Burn.Maxstacks,
		}
	end

	context.HitTarget = hitModel
	context.HitPosition = hitPosition

	return context
end

local function buildProjectileParams(character: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	local filterList = { character }
	local playersFolder = Workspace:FindFirstChild("Players")
	if playersFolder then
		table.insert(filterList, playersFolder)
	end
	params.FilterDescendantsInstances = filterList
	return params
end

local function simulateProjectileImpact(
	character: Model,
	weapon: string,
	baseAction: string,
	origin: Vector3,
	targetPosition: Vector3,
	aim: Vector3,
	maxRange: number
)
	local props = weaponProperties[weapon]
	if not props or not props[baseAction] then
		return
	end

	local gravity = Workspace.Gravity
	local direction = targetPosition - origin
	if direction.Magnitude < 1 then
		direction = aim.Unit * math.max(1, maxRange * 0.1)
		targetPosition = origin + direction
	end

	local velocityScalar = props[baseAction].Velocity or 0.05
	local duration = math.log(1.001 + direction.Magnitude * velocityScalar)
	duration = math.max(duration, 0.05)
	local maxLifetime = duration + 0.1

	local initialVelocity =
		(direction / duration)
		+ Vector3.new(0, gravity * duration * 0.5, 0)

	local params = buildProjectileParams(character)
	local t = 0
	local lastPos = origin
	local hitType = "Air"
	local hitModel: Model? = nil
	local hitPos = origin + aim.Unit * maxRange
	local hitNormal = Vector3.yAxis

	while t < maxLifetime do
		local dt = RunService.Heartbeat:Wait()
		t += dt

		local nextPos =
			origin
			+ initialVelocity * t
			+ Vector3.new(0, -0.5 * gravity * t * t, 0)

		local rayResult = Workspace:Raycast(lastPos, nextPos - lastPos, params)
		if rayResult then
			local enemy = findEnemyFromHit(rayResult)
			hitPos = rayResult.Position
			hitNormal = rayResult.Normal
			if enemy then
				hitType = "Enemy"
				hitModel = enemy
			else
				hitType = "Ground"
			end
			break
		end

		lastPos = nextPos
	end

	if hitType == "Enemy" and hitModel then
		local context = buildHitContext(character, weapon, baseAction, hitModel, hitPos)
		if context then
			ActionModifierService.DispatchPhase(character, ActionPhases.OnHit, context)
		end
	else
		vfxEvent:FireAllClients("ProjectileImpact", hitPos, hitNormal, weapon, baseAction, hitType)
		if hitType == "Ground" and baseAction == "Secondary" then
			local context = buildHitContext(character, weapon, baseAction, nil, hitPos)
			if context then
				ActionModifierService.DispatchPhase(character, ActionPhases.OnHit, context)
			end
		end
	end
end

------------------------------------------------------------
-- SERVER: receive fire attempts and forward projectile data to client
------------------------------------------------------------

function WeaponService.ArcProjectile(player, attackTable, weapon, baseAction)
--	print("[WeaponService] ArcProjectile called for", weapon, baseAction)

	local serverPosition = attackTable.serverPosition
	local rayInstance = attackTable.rayInstance
	local aimDir = attackTable.aimDir

	if not rayInstance or not rayInstance:IsDescendantOf(Workspace) then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	if not humanoid or humanoid.Health <= 0 or not hrp then
		return
	end

	local props = weaponProperties[weapon]
	if not props then
		return
	end

	local range    = props[baseAction].Range
	local coolDown = props[baseAction].Cooldown
	local radius   = props[baseAction].Radius
	local damage   = props[baseAction].Damage
	local velocity = props[baseAction].Velocity
	local knockBack = props[baseAction].Knockback
	
	
	LastAttackTimes[player] = LastAttackTimes[player] or {
		Primary = 0,
		Secondary = 0
	}

	-- Cooldown check (per-weapon / per-action)
	local now = tick()
	local playerTimes = LastAttackTimes[player]

	if now - playerTimes[baseAction] < coolDown then
		-- OPTIONAL: send rejection so client can unlock
		weaponAttackEvent:FireClient(player, nil, baseAction, nil)
		return
	end

	playerTimes[baseAction] = now



	-- Clamp the target position to range
	local originPosition = hrp.Position
	local aim = (typeof(aimDir) == "Vector3" and aimDir.Magnitude > 0.1) and aimDir.Unit or hrp.CFrame.LookVector
	local distance = (serverPosition - originPosition).Magnitude
	local targetPosition = serverPosition

	if distance > range then
		local dir = (serverPosition - originPosition).Unit
		targetPosition = originPosition + dir * range
	end

	task.spawn(function()
		simulateProjectileImpact(character, weapon, baseAction, originPosition, targetPosition, aim, range)
	end)

	-- Package everything the client needs to simulate the projectile
	local projectileData = {
		weapon         = weapon,
		baseAction     = baseAction,
		origin         = originPosition,
		targetPosition = targetPosition,
		range          = range,
		radius         = radius,
		damage         = damage,
		velocity       = velocity,
		knockBack      = knockBack,
		instance       = rayInstance
	}
--	print("[WeaponService] Sending projectile to client")

	-- Tell this client to play attack animation + spawn projectile locally.
	weaponAttackEvent:FireClient(player, rayInstance, baseAction, projectileData)
end

------------------------------------------------------------
-- ENTRYPOINT: WeaponAttack remote from client
------------------------------------------------------------

weaponAttackEvent.OnServerEvent:Connect(function(player, attackTable, weapon, baseAction)
	-- Prevent attacking while the game is paused
	if Workspace:GetAttribute("IsPaused") == true then
		warn(player.Name .. " attempted to attack while the game is paused.")
		return
	end

	if not weapon or not baseAction or not attackTable then
		return
	end

	local props = weaponProperties[weapon]
	if not props then
		return
	end

	if not RateLimiter.Allow(player, "WeaponAttack", 0.05) then
		return
	end


	if props[baseAction].Type == "Projectile" then
		WeaponService.ArcProjectile(player, attackTable, weapon, baseAction)
	else
		-- Future: add other primary attack types (slash, beam, etc.)
	end
end)

return WeaponService

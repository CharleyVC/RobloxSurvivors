local WeaponService = {}

-- Services
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

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

local weaponHitEvent = remoteEvents:WaitForChild("WeaponHit")


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
-- CLIENT → SERVER: hit confirmation for client-driven projectiles
------------------------------------------------------------

weaponHitEvent.OnServerEvent:Connect(function(player, hitData)
--	print("[WeaponService] Hit received:", hitData.baseAction, hitData.weapon)

	if Workspace:GetAttribute("IsPaused") == true then
		return
	end

	if typeof(hitData) ~= "table" then
		return
	end

	local weapon = hitData.weapon
	local baseAction = hitData.baseAction
	local hitPosition = hitData.hitPosition
	local enemyModel = hitData.enemy

	if not weapon or not baseAction then
		return
	end

	local props = weaponProperties[weapon]
	if not props then
		return
	end

	-- Make sure the player is actually holding this weapon
	local character = player.Character
	local equippedToolName
	if character then
		local tool = character:FindFirstChildWhichIsA("Tool")
		if tool then
			equippedToolName = tool.Name
		end
	end

	if equippedToolName ~= weapon then
		-- Client claims hit with a weapon they don't have equipped.
		return
	end

	-- Optional basic anti-cheat: range check
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hitPosition then
		local maxRange = props[baseAction].Range or 0
		if maxRange > 0 then
			local dist = (hitPosition - hrp.Position).Magnitude
			if dist > maxRange * 2 then
				-- Hit is too far away to be plausible
				return
			end
		end
	end
	
	local baseType 	 = props[baseAction].Type
	local radius     = props[baseAction].Radius or 0
	local damage     = props[baseAction].Damage or 0
	local knockBack  = props[baseAction].Knockback or 0
	local tags = props[baseAction].Tags

	local character = player.Character
	if not character or not character.Parent then return end


	-- Build the ActionContext
	local context = ActionContext.new({
		Actor = character,
		Action = baseAction,      -- "Primary" / "Secondary"
		BaseType = baseType,
		Source = weapon,

		Tags = tags,

		-- Default to the weapon's base damage
		Damage = damage,
		Radius = radius,
		Knockback = knockBack,
	})
	

	-- Optional AoE
	if props[baseAction].AoE then
		context.AoE = {
			Duration = props[baseAction].AoE.Duration,
			TickRate = props[baseAction].AoE.TickRate
		}
	end

	-- Optional Burn
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

	context.HitTarget = hitData.enemy
	context.HitPosition = hitData.hitPosition

	if not context.HitPosition and context.HitTarget then
		local hrp = context.HitTarget:FindFirstChild("HumanoidRootPart")
		if hrp then
			context.HitPosition = hrp.Position
		end
	end
	
	-- Dispatch OnHit: DamageOnHit + SmallExplosion (and future boons)
	ActionModifierService.DispatchPhase(character, ActionPhases.OnHit, context)

end)

------------------------------------------------------------
-- SERVER: receive fire attempts and forward projectile data to client
------------------------------------------------------------

function WeaponService.ArcProjectile(player, attackTable, weapon, baseAction)
--	print("[WeaponService] ArcProjectile called for", weapon, baseAction)

	local serverPosition = attackTable.serverPosition
	local rayInstance = attackTable.rayInstance

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
	local distance = (serverPosition - originPosition).Magnitude
	local targetPosition = serverPosition

	if distance > range then
		local dir = (serverPosition - originPosition).Unit
		targetPosition = originPosition + dir * range
	end

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


	if props[baseAction].Type == "Projectile" then
		WeaponService.ArcProjectile(player, attackTable, weapon, baseAction)
	else
		-- Future: add other primary attack types (slash, beam, etc.)
	end
end)

return WeaponService

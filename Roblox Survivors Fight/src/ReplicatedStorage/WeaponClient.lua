-------------------------
-- WeaponClient (Optimized for Client-Side Physics Projectiles)
-------------------------

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Targeting = require(ReplicatedStorage.Controllers:WaitForChild("Targeting"))
local AnimationHandler = require(ReplicatedStorage:WaitForChild("AnimationHandler"))
local CapsuleHitDetection = require(ReplicatedStorage.Controllers:WaitForChild("CapsuleHitDetection"))
local SFXModule = require(ReplicatedStorage:WaitForChild("SFXModule"))

-- REMOTES
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local WeaponAttack = RemoteEvents:WaitForChild("WeaponAttack")
local EquipEvent = RemoteEvents:WaitForChild("EquipEvent")
local WeaponPropertiesRemote = RemoteEvents:WaitForChild("WeaponProperties")

local WeaponClient = {}

------------------------------------------------------------
-- WEAPON STATE
------------------------------------------------------------
WeaponClient.EquippedWeapon = nil
WeaponClient.EquippedToolInstance = nil
WeaponClient.CurrentWeaponStats = {}
WeaponClient.ActionStats = { Primary = nil, Secondary = nil }
WeaponClient.LastAttackTimes = { Primary = 0, Secondary = 0 }
WeaponClient.CurrentAim = { Primary = nil, Secondary = nil }
WeaponClient.FireLoops = {
	
	Primary = { IsFiring = false, Connection = nil },
	Secondary = { IsFiring = false, Connection = nil }
}


WeaponClient.AttackTable = nil
WeaponClient.IsSprinting = false

local DEBUG_PROJECTILE_SWEEP = false -- set false to disable
local DEBUG_PROJECTILE_LOG = false


------------------------------------------------------------
-- PROJECTILE RAYCAST FOR WALL/MAP ONLY
------------------------------------------------------------
local projectileParams = RaycastParams.new()
projectileParams.FilterType = Enum.RaycastFilterType.Include
projectileParams.IgnoreWater = true
projectileParams.FilterDescendantsInstances = {
	workspace:WaitForChild("Map")
}

------------------------------------------------------------
-- BASIC HELPERS
------------------------------------------------------------
local function GetBaseAction(action)
	if action:sub(1,7) == "Primary" then return "Primary" end
	if action:sub(1,9) == "Secondary" then return "Secondary" end
	return nil
end

WeaponClient.SetSprintActive = function(enabled)
	WeaponClient.IsSprinting = enabled
	if WeaponClient.AnimationData then
		AnimationHandler.monitorMovement(WeaponClient.AnimationData)
	end
end

------------------------------------------------------------
-- EQUIPPED WEAPON RESOLUTION
------------------------------------------------------------
function WeaponClient.GetEquippedWeapon()
	local inst = WeaponClient.EquippedToolInstance
	local char = player.Character

	if inst and char and inst.Parent == char then
		return inst
	end

	if char then
		inst = char:FindFirstChildWhichIsA("Tool")
		WeaponClient.EquippedToolInstance = inst
		return inst
	end

	return nil
end

------------------------------------------------------------
-- CACHE WEAPON STATS FROM SERVER
------------------------------------------------------------
local function CacheWeaponStats(weaponName)
	local stats = WeaponPropertiesRemote:InvokeServer(weaponName)
	if not stats then return end

	WeaponClient.CurrentWeaponStats = stats
	WeaponClient.ActionStats.Primary = {
		Range = stats.Primary.Range,
		Cooldown = stats.Primary.Cooldown,
		Radius = stats.Primary.Radius,
		Type = stats.Primary.Type
	}
	WeaponClient.ActionStats.Secondary = {
		Range = stats.Secondary.Range,
		Cooldown = stats.Secondary.Cooldown,
		Radius = stats.Secondary.Radius,
		Type = stats.Secondary.Type
	}
end

------------------------------------------------------------
-- EQUIP EVENT
------------------------------------------------------------

local WeaponScriptsFolder = ReplicatedStorage.Data.Weapons:WaitForChild("WeaponScripts")

EquipEvent.OnClientEvent:Connect(function(weaponName)
	WeaponClient.EquippedWeapon = weaponName
	CacheWeaponStats(weaponName)

	local character = player.Character
	if not character then return end

	WeaponClient.BuildAnimationData(character, weaponName)
	WeaponClient.BindMovementUpdates(character)

	-- Find actual Tool instance in character
	local tool = character:FindFirstChild(weaponName)
	WeaponClient.EquippedToolInstance = tool

	------------------------------------------------------------
	-- LOAD THE MODULE FROM WeaponScriptsFolder
	------------------------------------------------------------
	local moduleScript = WeaponScriptsFolder:FindFirstChild(weaponName)
	if moduleScript then
		local weaponModule = require(moduleScript)

		if weaponModule.OnEquip then
			weaponModule.OnEquip(player, character, tool)
--			print("[" .. weaponName .. "] Successfully attached.")
		end
	else
		warn("Weapon module for " .. weaponName .. " not found in WeaponScripts.")
	end
end)

------------------------------------------------------------
-- ANIMATION SETUP
------------------------------------------------------------
WeaponClient.AnimationData = nil
WeaponClient.PrimaryAttackLength = 0.4
WeaponClient.SecondaryAttackLength = 0.6

function WeaponClient.BuildAnimationData(character, weaponName)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local anims = AnimationHandler.loadAnimations(character, "Weapon", weaponName)

	WeaponClient.AnimationData = {
		humanoid = humanoid,
		category = "Weapon",
		specificType = weaponName,
		animations = anims,
		state = nil,
		weight = nil,
		target = nil,
		isSprinting = function() return WeaponClient.IsSprinting end
	}

	local p = AnimationHandler.getAnimationTrack(character,"Weapon","Attack R")
	if p then WeaponClient.PrimaryAttackLength = p.Length end

	local s = AnimationHandler.getAnimationTrack(character,"Weapon","AlternateAttack")
	if s then WeaponClient.SecondaryAttackLength = s.Length end
end


function WeaponClient.BindMovementUpdates(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	if WeaponClient.MoveConn then WeaponClient.MoveConn:Disconnect() end
	if WeaponClient.SpeedConn then WeaponClient.SpeedConn:Disconnect() end

	local lastUpdate = 0
	local interval = 0.05

	WeaponClient.MoveConn = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if tick() - lastUpdate > interval then
			lastUpdate = tick()
			if WeaponClient.AnimationData then
				AnimationHandler.monitorMovement(WeaponClient.AnimationData)
			end
		end
	end)

	WeaponClient.SpeedConn = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if tick() - lastUpdate > interval then
			lastUpdate = tick()
			if WeaponClient.AnimationData then
				AnimationHandler.monitorMovement(WeaponClient.AnimationData)
			end
		end
	end)
end

------------------------------------------------------------
-- AIM UPDATES
------------------------------------------------------------
function WeaponClient.UpdateAim(baseAction, aimVector)
	WeaponClient.CurrentAim[baseAction] = aimVector
end

function WeaponClient.ClearAim(baseAction)
	WeaponClient.CurrentAim[baseAction] = nil
end

------------------------------------------------------------
-- FIRING CONTROL
------------------------------------------------------------
function WeaponClient.StartFiring(action)
	local tool = WeaponClient.GetEquippedWeapon()
	if not tool then
		return
	end

	local baseAction = GetBaseAction(action)
	if not baseAction then return end

	local loop = WeaponClient.FireLoops[baseAction]


	if loop.IsFiring then
		return
	end

	loop.IsFiring = true
	
	loop.Connection = RunService.Heartbeat:Connect(function()
		WeaponClient.DoLoopFire(baseAction, tool.Name)
	end)
end

function WeaponClient.StopFiring(action)
	local baseAction = GetBaseAction(action)

	
	if not baseAction then return end

	local loop = WeaponClient.FireLoops[baseAction]


	local animData = WeaponClient.AnimationData
	if animData and animData.humanoid then
		animData.humanoid:SetAttribute("IsAttacking", false)
	end


	if loop.Connection then
		loop.Connection:Disconnect()
		loop.Connection = nil
	end

	loop.IsFiring = false
end






------------------------------------------------------------
-- LOOP FIRE: CALLED EVERY HEARTBEAT
------------------------------------------------------------
function WeaponClient.DoLoopFire(baseAction, weaponName)
	
	local stats = WeaponClient.ActionStats[baseAction]
	if not stats then return end
	
	local now = tick()
	if now - WeaponClient.LastAttackTimes[baseAction] < stats.Cooldown then
		return
	end

	WeaponClient.LastAttackTimes[baseAction] = now

	local range = stats.Range
	local aim = WeaponClient.CurrentAim[baseAction]

	local pos, inst, autoDir = Targeting:GetAim(range)

	local t = WeaponClient.AttackTable or {}
	WeaponClient.AttackTable = t

	t.serverPosition = pos
	t.rayInstance = inst
	t.direction = aim or autoDir
	t.aimDir = (aim or autoDir)
	--print("[WeaponClient] Firing weapon:", weaponName, baseAction)
	WeaponAttack:FireServer(t, weaponName, baseAction)
end

------------------------------------------------------------
-- SINGLE SHOT
------------------------------------------------------------
function WeaponClient.FireSingle(baseAction, aimVector)
	
	local tool = WeaponClient.GetEquippedWeapon()
	if not tool then return end

	local stats = WeaponClient.ActionStats[baseAction]
	if not stats then return end

	local now = tick()
	if now - WeaponClient.LastAttackTimes[baseAction] < stats.Cooldown then
		return
	end
	

	local pos, inst, autoDir = Targeting:GetAim(stats.Range)

	local t = WeaponClient.AttackTable or {}
	WeaponClient.AttackTable = t

	t.serverPosition = pos
	t.rayInstance = inst
	t.direction = aimVector or autoDir
	t.aimDir = (aimVector or autoDir)

	WeaponClient.LastAttackTimes[baseAction] = now
	WeaponAttack:FireServer(t, tool.Name, baseAction)
end



local Debris = game:GetService("Debris")

------------------------------------------------------------
-- CAPSULE DEBUG DRAW (client-only)
------------------------------------------------------------

local function drawSphere(pos: Vector3, radius: number, color: Color3, life: number)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.4
	p.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos)
	p.Parent = workspace
	Debris:AddItem(p, life)
end

local function drawLine(a: Vector3, b: Vector3, thickness: number, color: Color3, life: number)
	local dist = (b - a).Magnitude
	if dist <= 0 then return end

	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.4
	p.Size = Vector3.new(thickness, thickness, dist)
	p.CFrame = CFrame.lookAt((a + b) * 0.5, b)
	p.Parent = workspace
	Debris:AddItem(p, life)
end

local function drawCapsuleDebug(
	projA: Vector3,
	projB: Vector3,
	projRadius: number,
	capA: Vector3,
	capB: Vector3,
	capRadius: number
)
	if not DEBUG_PROJECTILE_SWEEP then return end

	local life = 0.1

	-- Projectile path
	drawLine(projA, projB, projRadius * 0.5, Color3.fromRGB(0, 255, 255), life)
	drawSphere(projA, projRadius, Color3.fromRGB(0, 255, 255), life)
	drawSphere(projB, projRadius, Color3.fromRGB(0, 255, 255), life)

	-- Enemy capsule
	drawLine(capA, capB, capRadius * 0.4, Color3.fromRGB(255, 80, 80), life)
	drawSphere(capA, capRadius, Color3.fromRGB(255, 80, 80), life)
	drawSphere(capB, capRadius, Color3.fromRGB(255, 80, 80), life)
end

local function dbg(...)
	if DEBUG_PROJECTILE_LOG then
		print("[ProjectileDebug]", ...)
	end
end

------------------------------------------------------------
------------------------------------------------------------
------------------------------------------------------------
-- FINAL BALLISTIC PROJECTILE (PHYSICS-BASED TERMINATION)
------------------------------------------------------------
------------------------------------------------------------
-- FINAL BALLISTIC PROJECTILE (STABLE VERSION)
------------------------------------------------------------
local function SpawnProjectile(data)
	if not data then return end

	local weaponName = data.weapon
	local targetPos = data.targetPosition
	local velocity = data.velocity or 1
	local baseAction = data.baseAction
	local range = data.range or 200

	-- Use LOCAL HRP as origin if possible (much less desync)
	local originPos
	do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			originPos = hrp.Position
		else
			originPos = data.origin
		end
	end

	if not originPos or not targetPos then return end

	-- Locate projectile asset
	local weaponsFolder = ReplicatedStorage.Data.Weapons
	local weaponFolder = weaponsFolder:FindFirstChild(weaponName)
	if not weaponFolder then return end

	local projectileTemplate = weaponFolder:FindFirstChild("Projectile")
	if not projectileTemplate then return end

	local projectile = projectileTemplate:Clone()
	projectile.Position = originPos
	projectile.Parent = workspace:FindFirstChild("Projectiles") or workspace

	------------------------------------------------------------
	-- 1. RANGE CLAMP (based on local origin)
	------------------------------------------------------------
	local directionToPos = targetPos - originPos
	local flatDistance = directionToPos.Magnitude

	if flatDistance > range then
		local clamped = directionToPos.Unit * range
		targetPos = originPos + clamped
	end

	------------------------------------------------------------
	-- 2. ARC DURATION + TARGET LEADING
	------------------------------------------------------------
	local direction = targetPos - originPos

	-- Minimum distance so duration isn't crazy small
	if direction.Magnitude < 5 then
		direction = direction.Unit * 5
		targetPos = originPos + direction
	end

	local duration = math.log(1.001 + direction.Magnitude * velocity)

	if data.instance and data.instance.AssemblyLinearVelocity then
		targetPos = targetPos + data.instance.AssemblyLinearVelocity * duration
	end

	------------------------------------------------------------
	-- 3. FINAL BALLISTIC FORCE
	------------------------------------------------------------
	direction = targetPos - originPos
	local force =
		(direction / duration)
		+ Vector3.new(0, workspace.Gravity * duration * 0.5, 0)

	local mass = projectile.Mass or projectile.AssemblyMass
	projectile:ApplyImpulse(force * mass)

	------------------------------------------------------------
	-- 4. HIT DETECTION SETUP
	------------------------------------------------------------
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	local hitRadius = projectile.Size.Magnitude * 0.45

	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Include
	groundParams.FilterDescendantsInstances = {
		workspace:WaitForChild("Map"),	}

	local function impact(position)
		SFXModule.Impact(position, WeaponClient.EquippedWeapon)
		projectile:Destroy()
	end

	------------------------------------------------------------
	-- 5. PHYSICS LOOP
	------------------------------------------------------------
	------------------------------------------------------------
	-- 5. PHYSICS LOOP (Capsule sweep, physics-rate)
	------------------------------------------------------------
	task.spawn(function()
		local spawnTime = tick()
		local lastPos = projectile.Position
		local hasCheckedFinalSweep = false


		while projectile.Parent do
			local dt = RunService.Heartbeat:Wait()


			local pos = projectile.Position
			local vel = projectile.AssemblyLinearVelocity
			local extendedPos = pos + vel * dt

			if DEBUG_PROJECTILE_LOG then
				local vel = projectile.AssemblyLinearVelocity
				dbg(
					"Pos:", pos,
					"Vel:", vel,
					"Speed:", vel.Magnitude
				)
			end


			-- DEBUG: show projectile swept segment (optional)
			if DEBUG_PROJECTILE_SWEEP and enemiesFolder then
				for _, enemy in ipairs(enemiesFolder:GetChildren()) do
					local a, b, r = CapsuleHitDetection.GetEnemyCapsule(enemy)
					if a then
						drawCapsuleDebug(
							lastPos,
							pos,
							hitRadius,
							a,
							b,
							r
						)
					end
				end
			end
			if DEBUG_PROJECTILE_LOG and enemiesFolder then
				for _, enemy in ipairs(enemiesFolder:GetChildren()) do
					local hrp = enemy:FindFirstChild("HumanoidRootPart")
					if hrp then
						local dist = (hrp.Position - pos).Magnitude
						if dist < hitRadius * 3 then
							dbg(
								"Near enemy:", enemy.Name,
								"Dist:", dist,
								"HitRadius:", hitRadius
							)
						end
					end
				end
			end


			-- A) Enemy hit (CAPSULE SWEEP FIRST)
			local enemy = CapsuleHitDetection.CheckProjectileHit(
				lastPos,
				extendedPos,
				hitRadius,
				enemiesFolder
			)

			if enemy then
				dbg("HIT enemy:", enemy.Name, "at pos:", pos)
				impact(pos)
				return
			end


			-- B) Ground hit (with final enemy grace sweep)
			local timeAlive = tick() - spawnTime
			local vel = projectile.AssemblyLinearVelocity

			if timeAlive > 0.1 and vel.Y <= 0 then
				-- ONE FINAL ENEMY SWEEP before termination
				if not hasCheckedFinalSweep then
					hasCheckedFinalSweep = true
					local lastPos = projectile.Position - projectile.AssemblyLinearVelocity

					local enemy = CapsuleHitDetection.CheckProjectileHit(
						lastPos,
						extendedPos,
						hitRadius,
						enemiesFolder
					)


					if enemy then
						impact(pos)
						return
					end
				end

				local ground = workspace:Raycast(
					pos,
					(extendedPos - pos),
					groundParams
				)

				if ground then
					dbg(
						"TERMINATE: Ground hit",
						"Pos:", pos,
						"Vel:", projectile.AssemblyLinearVelocity
					)
					impact(ground.Position)
					return
				end

			end


			-- C) Failsafe: out of world
			if pos.Y < -100 then
				dbg(
					"TERMINATE: Out of world",
					"Pos:", pos,
					"Vel:", projectile.AssemblyLinearVelocity
				)
				impact(pos)
				return
			end


			lastPos = pos
		end
	end)

end


------------------------------------------------------------
-- ANIMATION + PROJECTILE SPAWN ENTRY POINT
------------------------------------------------------------
WeaponAttack.OnClientEvent:Connect(function(rayInstance, baseAction, projectileData)


	local animData = WeaponClient.AnimationData
	if not animData then return end

	assert(WeaponClient.EquippedWeapon, "WeaponAttack fired but no equipped weapon")

	animData.state = (baseAction == "Primary") and "Attack" or "AlternateAttack"
	animData.weight = 1
	animData.target = rayInstance

	local humanoid = animData.humanoid
	humanoid:SetAttribute("IsAttacking", true)

	AnimationHandler.playAnimation(animData)
	SFXModule.Attack(humanoid.Parent, WeaponClient.EquippedWeapon)

	-- Only spawn projectile for weapons whose Type is "Projectile"
	local weaponName = WeaponClient.EquippedWeapon

	if WeaponClient.CurrentWeaponStats and WeaponClient.ActionStats[baseAction].Type == "Projectile" then
		if projectileData then
			SpawnProjectile(projectileData)
		end
	end

	-- Maintain movement animations while attacking
	task.spawn(function()
		while humanoid:GetAttribute("IsAttacking") do
			AnimationHandler.monitorMovement(animData)
			task.wait(0.1)
		end
	end)

	-- Reset according to animation length
	local reset = WeaponClient.ActionStats[baseAction].Cooldown

	task.delay(reset, function()
		humanoid:SetAttribute("IsAttacking", false)
	end)
end)

return WeaponClient

 -- ServerScriptService/Combat/EffectsAuthority.lua

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vfxEvent = ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

local EffectsAuthority = {}

-- Cache enemies folder once
local enemiesFolder = Workspace:WaitForChild("Enemies")
local DEBUG_EFFECTS = false
--------------------------------------------------------
-- ACTIVE DOT STATE
--------------------------------------------------------
local activeDots = {}
-- [Model] = {
--   Burn = {
--     stacks = number,
--     dps = number,
--     knockback = number?,
--     expiresAt = number
--   }
-- }

--------------------------------------------------------
-- AOE QUERY PARAMS (DISCOVERY ONLY)
--------------------------------------------------------
local AOE_PARAMS = OverlapParams.new()
AOE_PARAMS.FilterType = Enum.RaycastFilterType.Include
AOE_PARAMS.FilterDescendantsInstances = { enemiesFolder }

--------------------------------------------------------
-- DIRECT DAMAGE
--------------------------------------------------------
function EffectsAuthority.applyDamage(targetModel, damage, knockback)
	if not targetModel then return end

	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if DEBUG_EFFECTS then
		print("[Damage] Target:", targetModel.Name, "Damage:", damage, "KB:", knockback)
	end
	
	humanoid:TakeDamage(damage)

	if knockback then
		local rootPart = targetModel:FindFirstChild("HumanoidRootPart")
		if rootPart then
			if DEBUG_EFFECTS then
				print("  ↳ Applying knockback")
			end
			EffectsAuthority.applyKnockback(rootPart, rootPart.Position, knockback)
		end
	end

	vfxEvent:FireAllClients("HitNPC", targetModel)
end


--------------------------------------------------------
-- KNOCKBACK
--------------------------------------------------------
function EffectsAuthority.applyKnockback(targetPart, origin, force)
	if not (targetPart and targetPart:IsA("BasePart") and force and force > 0) then
		return
	end

	local diff = origin and (targetPart.Position - origin)
	local direction = (diff and diff.Magnitude > 0) and diff.Unit or -targetPart.CFrame.LookVector

	targetPart:ApplyImpulse(direction * force * targetPart.AssemblyMass)
end

--------------------------------------------------------
-- APPLY AOE (TARGET DISCOVERY ONLY)
--------------------------------------------------------
function EffectsAuthority.applyAoE(position, radius, source, applyFn)
	if not position or not radius or radius <= 0 then return end
	if DEBUG_EFFECTS then
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		p.Position = position
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 0.8
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 0, 0)
		p.Parent = workspace

		task.delay(0.5, function()
			p:Destroy()
		end)
	end

	local affected = {}
	local parts = Workspace:GetPartBoundsInRadius(position, radius, AOE_PARAMS)
	
	
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not affected[model] then
			affected[model] = true

			if applyFn then
				applyFn(model)
			end
		end
	end
end


-- EffectsAuthority.applyInstantAoEDamage
function EffectsAuthority.applyInstantAoEDamage(position, radius, damage, source, knockback)
	if not position or radius <= 0 or damage <= 0 then
		return
	end
	EffectsAuthority.applyAoE(position, radius, source, function(model)
		EffectsAuthority.applyDamage(model, damage, knockback)
		-- Fire visuals separately
	end)
end

function EffectsAuthority.applyInvulnerability(actor: Model, enabled: boolean)
	if not actor then return end

	-- Centralized rule for invulnerability
	actor:SetAttribute("IsInvulnerable", enabled)

	-- Future-proofing:
	-- • network replication
	-- • VFX hooks
	-- • stacking rules
end


---------------------------------------------------------------------
-- Bomb stacks (auto AoE detonation on max)
---------------------------------------------------------------------
local BombStates = {}

function EffectsAuthority.addBombStacks(
	HitTarget: Model,
	stacks: number,
	maxStacks: number?,
	damagePerStack: number?,
	explosionRadius: number?,
	knockback: number?
)
	
	if not HitTarget or stacks <= 0 then return end
	
	local state = BombStates[HitTarget]
	if not state then
		state = { Stacks = 0 }
		BombStates[HitTarget] = state
	end

	local max = maxStacks or math.huge
	state.Stacks += stacks
	------------------------------------------------
	-- Auto detonate at max stacks
	------------------------------------------------
	if state.Stacks >= max then
		local hrp = HitTarget:FindFirstChild("HumanoidRootPart")
		if not hrp then
			state.Stacks = 0
			return
		end

		local totalDamage =
			(state.Stacks or 0)
			* (damagePerStack or 0)

		local radius = explosionRadius or 0

		-- Consume stacks BEFORE damage
		state.Stacks = 0

		if totalDamage > 0 and radius > 0 then
			EffectsAuthority.applyInstantAoEDamage(
				hrp.Position,
				radius,
				totalDamage,
				HitTarget,
				knockback or 0
			)
		end
	end
end

---------------------------------------------------------------------
-- Detonate bomb stacks on a single target
-- Called by modifiers reacting to BombDetonation hits
---------------------------------------------------------------------
function EffectsAuthority.detonateBombStacks(
	target: Model,
	damagePerStack: number,
	explosionRadius: number?,
	knockback: number?
)
	if not target then return end

	local state = BombStates[target]
	if not state or state.Stacks <= 0 then
		return
	end

	local hrp = target:FindFirstChild("HumanoidRootPart")
	if not hrp then
		state.Stacks = 0
		return
	end

	------------------------------------------------
	-- Calculate damage
	------------------------------------------------
	local totalDamage = state.Stacks * (damagePerStack or 0)

	------------------------------------------------
	-- Consume stacks BEFORE dealing damage
	------------------------------------------------
	state.Stacks = 0

	------------------------------------------------
	-- Apply explosion damage (SmallExplosion-style)
	------------------------------------------------
	if totalDamage > 0 and (explosionRadius or 0) > 0 then
		EffectsAuthority.applyInstantAoEDamage(
			hrp.Position,
			explosionRadius,
			totalDamage,
			target,                 -- source
			knockback or 0
		)
	end
end


--------------------------------------------------------
-- APPLY DOT STACKS
--------------------------------------------------------
function EffectsAuthority.applyDot(targetModel, dotName, dotData)
	if not targetModel or not dotName or not dotData then return end

	local humanoid = targetModel:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	activeDots[targetModel] = activeDots[targetModel] or {}
	local dots = activeDots[targetModel]

	local dot = dots[dotName]

	if not dot then
		dot = {
			stacks = 0,
			dps = dotData.Damage or 0,
			duration = dotData.Duration or 1,
			knockback = dotData.Knockback,
			Maxstacks = dotData.Maxstacks or 5,
			expiresAt = 0,
		}
		dots[dotName] = dot
	end

	dot.stacks = math.min(dot.stacks + 1, dot.Maxstacks or 5)
	dot.expiresAt = math.max(
		dot.expiresAt,
		os.clock() + (dot.duration or 0)
	)

	if DEBUG_EFFECTS then
		print(
			("[DOT] %s → %s | stacks=%d | expires in %.2fs")
				:format(
					targetModel.Name,
					dotName,
					dot.stacks,
					dot.expiresAt - os.clock()
				)
		)
	end

	vfxEvent:FireAllClients("HitNPC", targetModel)
end


--------------------------------------------------------
-- DOT TICK LOOP (AUTHORITATIVE)
--------------------------------------------------------
task.spawn(function()
	while true do
		
		for model, dots in pairs(activeDots) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local rootPart = model:FindFirstChild("HumanoidRootPart")

			if not humanoid or humanoid.Health <= 0 then
				activeDots[model] = nil
				continue
			end

			local hasAny = false
			
			for name, dot in pairs(dots) do
				if os.clock() < dot.expiresAt then
					hasAny = true

					EffectsAuthority.applyDamage(
						model,
						dot.dps,
						dot.knockback
					)
				else
					dots[name] = nil
				end
			end


			if not hasAny then
				activeDots[model] = nil
			end
		end

		task.wait(1)
	end
end)


return EffectsAuthority

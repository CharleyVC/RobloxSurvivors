-- Targeting.lua (ReplicatedStorage, Client-Only)
local Targeting = {}

---------------------------------------------------------------------
-- Services
---------------------------------------------------------------------
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

---------------------------------------------------------------------
-- Public state
---------------------------------------------------------------------
Targeting.InputMode = "KeyboardMouse"
Targeting.MobileAimDirection = nil -- { dir = Vector3, strength = 0–1 }

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------
Targeting.DebugEnabled = false
Targeting.DebugLifetime = 0.5

local DebugFolder = Workspace:FindFirstChild("DebugLines")
if not DebugFolder then
	DebugFolder = Instance.new("Folder")
	DebugFolder.Name = "DebugLines"
	DebugFolder.Parent = Workspace
end

local function drawDebugLine(from: Vector3, to: Vector3, color: Color3, lifetime: number)
	local dist = (to - from).Magnitude
	if dist <= 0 then return end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.05, 0.05, dist)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	part.CollisionGroup = "InvisibleObjects"
	part.Parent = DebugFolder

	task.delay(lifetime, function()
		if part then part:Destroy() end
	end)
end

---------------------------------------------------------------------
-- Caching
---------------------------------------------------------------------
Targeting._lastPcMousePos = nil :: Vector2?
Targeting._lastPcMaxRange = nil :: number?
Targeting._lastPcResult = nil -- { pos, instance, dir }

Targeting._lastMobileResult = nil
Targeting._pcPixelThreshold = 4

---------------------------------------------------------------------
-- Mobile rate limit
---------------------------------------------------------------------
local MOBILE_RAY_INTERVAL = 1 / 30
local _lastMobileRayTime = 0
---------------------------------------------------------------------
-- Raycast throttle (PC + Touch)
---------------------------------------------------------------------
local MAX_RAYCASTS_PER_SEC = 30
local RAYCAST_INTERVAL = 1 / MAX_RAYCASTS_PER_SEC
local _lastRaycastTime = 0

---------------------------------------------------------------------
-- Raycast params
---------------------------------------------------------------------
local AIM_PARAMS = RaycastParams.new()
AIM_PARAMS.CollisionGroup = "Raycast"
AIM_PARAMS.IgnoreWater = true

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Touch-only ground resolve
local function applyDownwardRay(pos: Vector3)
	local start = pos + Vector3.new(0, 60, 0)
	local finish = start + Vector3.new(0, -200, 0)

	if Targeting.DebugEnabled then
		drawDebugLine(start, finish, Color3.fromRGB(255, 255, 0), Targeting.DebugLifetime)
	end

	local hit = Workspace:Raycast(start, Vector3.new(0, -200, 0), AIM_PARAMS)
	if hit then
		return hit.Position, hit.Instance
	end

	-- Absolute fallback (should basically never happen)
	return pos, Workspace:FindFirstChildWhichIsA("BasePart")
end

---------------------------------------------------------------------
-- Input mode hooks
---------------------------------------------------------------------
function Targeting.SetInputMode(mode)
	Targeting.InputMode = mode
end

function Targeting:SetMobileAim(aimData)
	self.MobileAimDirection = aimData
end


local function canRaycastNow()
	local now = time()
	if now - _lastRaycastTime >= RAYCAST_INTERVAL then
		_lastRaycastTime = now
		return true
	end
	return false
end


---------------------------------------------------------------------
-- Unified Aim
---------------------------------------------------------------------
function Targeting:GetAim(maxRange: number)
	local hrp = getHRP()
	if not hrp then return nil end

	local origin = hrp.Position

	-----------------------------------------------------------------
	-- TOUCH MODE
	-----------------------------------------------------------------
	if Targeting.InputMode == "Touch" and self.MobileAimDirection then
		local now = time()

		if self._lastMobileResult and now - _lastMobileRayTime < MOBILE_RAY_INTERVAL then
			local r = self._lastMobileResult
			return r.pos, r.instance, r.dir
		end
		_lastMobileRayTime = now

		local aim = self.MobileAimDirection
		local dir = Vector3.new(aim.dir.X, 0, aim.dir.Z)
		if dir.Magnitude == 0 then dir = hrp.CFrame.LookVector end
		dir = dir.Unit

		local dist = math.clamp(maxRange * (aim.strength or 1), 6, maxRange)

		if Targeting.DebugEnabled then
			drawDebugLine(origin, origin + dir * dist, Color3.fromRGB(0, 255, 255), Targeting.DebugLifetime)
		end

		local hit = Workspace:Raycast(origin, dir * dist, AIM_PARAMS)
		local pos, inst

		if hit then
			pos = hit.Position
			inst = hit.Instance
		else
			pos, inst = applyDownwardRay(origin + dir * dist)
		end

		self._lastMobileResult = { pos = pos, instance = inst, dir = dir }
		return pos, inst, dir
	end

	-----------------------------------------------------------------
	-- PC MODE (Camera ray, throttled to 30 Hz)
	-----------------------------------------------------------------
	local mousePos = UIS:GetMouseLocation()

	-- If we have a cached result AND we are not allowed to raycast yet,
	-- just reuse it (smooth, zero cost)
	if self._lastPcResult
		and self._lastPcMaxRange == maxRange
		and not canRaycastNow()
	then
		local r = self._lastPcResult
		return r.pos, r.instance, r.dir
	end

	-- If mouse hasn't moved much, reuse cached aim even if budget allows
	if self._lastPcResult
		and self._lastPcMaxRange == maxRange
		and self._lastPcMousePos
		and (mousePos - self._lastPcMousePos).Magnitude < self._pcPixelThreshold
	then
		local r = self._lastPcResult
		return r.pos, r.instance, r.dir
	end

	-- 🔥 CAMERA RAY (ONLY happens ≤ 30/sec)
	local camRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local rayResult = Workspace:Raycast(
		camRay.Origin,
		camRay.Direction * 1000,
		AIM_PARAMS
	)

	if not rayResult then
		return nil
	end

	-- Clamp hit position relative to player
	local hitPos = rayResult.Position
	local offset = hitPos - origin
	local dist = offset.Magnitude

	if dist > maxRange then
		hitPos = origin + offset.Unit * maxRange
	end

	local dir = offset.Magnitude > 0 and offset.Unit or hrp.CFrame.LookVector

	if Targeting.DebugEnabled then
		drawDebugLine(origin, hitPos, Color3.fromRGB(0, 255, 255), Targeting.DebugLifetime)
	end

	-- Cache
	self._lastPcMousePos = mousePos
	self._lastPcMaxRange = maxRange
	self._lastPcResult = {
		pos = hitPos,
		instance = rayResult.Instance,
		dir = dir
	}

	return hitPos, rayResult.Instance, dir



end

return Targeting

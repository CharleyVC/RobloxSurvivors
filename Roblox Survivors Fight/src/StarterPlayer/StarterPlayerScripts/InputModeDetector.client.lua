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
-- Caching (kept from your original)
---------------------------------------------------------------------
Targeting._lastPcMousePos = nil :: Vector2?
Targeting._lastPcMaxRange = nil :: number?
Targeting._lastPcResult = nil   -- { pos, instance, dir }

Targeting._lastMobileDir = nil :: Vector3?
Targeting._lastMobileStrength = nil :: number?
Targeting._lastMobileMaxRange = nil :: number?
Targeting._lastMobileResult = nil -- { pos, instance, dir }

Targeting._pcPixelThreshold = 4
Targeting._mobileDirThreshold = 0.02
Targeting._mobileStrengthThreshold = 0.05

---------------------------------------------------------------------
-- Mobile rate limit
---------------------------------------------------------------------
local MOBILE_RAY_INTERVAL = 1 / 30
local _lastMobileRayTime = 0

---------------------------------------------------------------------
-- Raycast params (NO FILTER TABLES)
---------------------------------------------------------------------
local AIM_PARAMS = RaycastParams.new()
AIM_PARAMS.CollisionGroup = "Raycast"
AIM_PARAMS.IgnoreWater = true

local GROUND_PARAMS = AIM_PARAMS -- same group, same ignores

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getHRP()
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function applyDownwardRay(originPos: Vector3)
	local verticalOrigin = originPos + Vector3.new(0, 60, 0)
	local hit = Workspace:Raycast(
		verticalOrigin,
		Vector3.new(0, -200, 0),
		GROUND_PARAMS
	)

	if hit then
		return hit.Position, hit.Instance
	end

	return originPos, Workspace.Terrain
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

---------------------------------------------------------------------
-- Raw PC camera ray (kept, but simplified)
---------------------------------------------------------------------
function Targeting:Raycast()
	local mousePos = UIS:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, AIM_PARAMS)

	if result then
		return result.Position, result.Instance, ray.Direction
	end

	return ray.Origin + ray.Direction * 1000, nil, ray.Direction
end

---------------------------------------------------------------------
-- Unified Aim (PC + Mobile)
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

		-- Rate limit mobile raycasts
		if self._lastMobileResult and (now - _lastMobileRayTime) < MOBILE_RAY_INTERVAL then
			local r = self._lastMobileResult
			return r.pos, r.instance, r.dir
		end
		_lastMobileRayTime = now

		local aim = self.MobileAimDirection
		local dir = Vector3.new(aim.dir.X, 0, aim.dir.Z)
		if dir.Magnitude == 0 then
			dir = hrp.CFrame.LookVector
		end
		dir = dir.Unit

		local strength = aim.strength or 1
		local desiredDist = math.clamp(maxRange * strength, 6, maxRange)

		local hit = Workspace:Raycast(origin, dir * desiredDist, AIM_PARAMS)

		local finalPos, finalInst
		if hit then
			finalPos = hit.Position
			finalInst = hit.Instance
		else
			local projected = origin + dir * desiredDist
			finalPos, finalInst = applyDownwardRay(projected)
		end

		self._lastMobileDir = dir
		self._lastMobileStrength = strength
		self._lastMobileMaxRange = maxRange
		self._lastMobileResult = {
			pos = finalPos,
			instance = finalInst,
			dir = dir
		}

		return finalPos, finalInst, dir
	end

	-----------------------------------------------------------------
	-- PC MODE
	-----------------------------------------------------------------
	local mousePos = UIS:GetMouseLocation()

	if self._lastPcResult
		and self._lastPcMaxRange == maxRange
		and self._lastPcMousePos
	then
		if (mousePos - self._lastPcMousePos).Magnitude < self._pcPixelThreshold then
			local r = self._lastPcResult
			return r.pos, r.instance, r.dir
		end
	end

	local pos, inst, dir = self:Raycast()

	local rel = pos - origin
	if rel.Magnitude > maxRange then
		pos = origin + rel.Unit * maxRange
		inst = nil
	end

	local finalPos, finalInst
	if inst then
		finalPos = pos
		finalInst = inst
	else
		finalPos, finalInst = applyDownwardRay(pos)
	end

	self._lastPcMousePos = mousePos
	self._lastPcMaxRange = maxRange
	self._lastPcResult = {
		pos = finalPos,
		instance = finalInst,
		dir = dir
	}

	return finalPos, finalInst, dir
end

return Targeting

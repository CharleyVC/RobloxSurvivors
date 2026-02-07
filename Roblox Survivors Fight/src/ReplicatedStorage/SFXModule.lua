local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Data.Sounds:WaitForChild("Sounds"))
local GroundResolver = require(ReplicatedStorage:WaitForChild("GroundResolver"))

local SFXModule = {}

-- Weak-key: last play time per foot part
local debounceTracker = setmetatable({}, { __mode = "k" })
local DEBOUNCE_TIME = 0.2

local FALLBACK_SOUND = "rbxassetid://54009679"

-- -----------------------
-- Helpers
-- -----------------------

local function getFootPart(character: Model, foot: string): BasePart?
	local footPartName =
		(foot == "Left" and "LeftFoot")
		or (foot == "Right" and "RightFoot")
		or nil

	if not footPartName then return nil end

	local part = character:FindFirstChild(footPartName)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

local function isDebounced(part: Instance): boolean
	local t = os.clock()
	local last = debounceTracker[part]
	if last and (t - last) < DEBOUNCE_TIME then
		return true
	end
	debounceTracker[part] = t
	return false
end

local function playSoundAtInstance(parent: Instance, soundId: string, volume: number?, pitchMin: number?, pitchMax: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 0.2

	if pitchMin and pitchMax then
		local pitch = Instance.new("PitchShiftSoundEffect")
		pitch.Octave = math.random(pitchMin, pitchMax) / 100
		pitch.Parent = sound
	end

	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

local function playSoundAtPosition(position: Vector3, soundId: string, volume: number?, pitchMin: number?, pitchMax: number?)
	local p = Instance.new("Part")
	p.Name = "SFX_Attach"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = CFrame.new(position)
	p.Parent = workspace

	playSoundAtInstance(p, soundId, volume, pitchMin, pitchMax)

	task.delay(2, function()
		if p and p.Parent then
			p:Destroy()
		end
	end)
end

local function resolveFootstepSoundId(groundInstance: Instance?): string
	if not groundInstance or not groundInstance:IsA("BasePart") then
		return FALLBACK_SOUND
	end

	-- 1) Prefer custom attribute (string like "Grass" OR Enum.Material)
	local actualMaterial = groundInstance:GetAttribute("Material")

	-- 2) Fallback to Roblox material (Enum.Material)
	if actualMaterial == nil then
		actualMaterial = groundInstance.Material
	end

	-- Normalize to Enum.Material
	local materialKey: Enum.Material? = nil
	if typeof(actualMaterial) == "EnumItem" then
		materialKey = actualMaterial
	elseif type(actualMaterial) == "string" then
		materialKey = Enum.Material[actualMaterial]
	end
	if materialKey == nil then
		materialKey = Enum.Material.Grass
	end

	-- Map material -> table name -> array of soundIds
	local soundTableMap = Sounds.materialMap and Sounds.materialMap[materialKey]
	if not soundTableMap then
		return FALLBACK_SOUND
	end

	local soundTable = Sounds.Footsteps and Sounds.Footsteps[soundTableMap]
	if type(soundTable) ~= "table" or #soundTable == 0 then
		return FALLBACK_SOUND
	end

	return soundTable[math.random(1, #soundTable)]
end

local function resolveProjectileSoundId(soundKeyOrId: any, fallbackId: string): string
	-- Allow direct asset id
	if type(soundKeyOrId) == "string" and soundKeyOrId:find("rbxassetid://") then
		return soundKeyOrId
	end
	-- Allow nil (use fallback)
	if soundKeyOrId == nil then
		return fallbackId
	end
	-- Allow a pre-resolved sound id from Sounds tables
	if type(soundKeyOrId) == "string" then
		return soundKeyOrId
	end
	return fallbackId
end

-- -----------------------
-- Public API
-- -----------------------

function SFXModule.Footstep(character: Model, foot: string)
	local footPart = getFootPart(character, foot)
	if not footPart then
		warn("Foot part not found for foot:", foot)
		return
	end

	if isDebounced(footPart) then
		return
	end

	-- GroundResolver is responsible for raycast; we just consume its result
	local result = GroundResolver.resolve(footPart.Position)
	local groundInstance = result and result.Instance or nil

	local soundId = resolveFootstepSoundId(groundInstance)
	playSoundAtInstance(footPart, soundId, 0.2, 90, 110)
end

function SFXModule.Attack(origin: any, attackName: string, overrideId: string?, opts: any?)
	opts = opts or {}

	-- attackName examples: "Fireball", "Sword", "Dash"
	local soundId =
		(overrideId and overrideId:find("rbxassetid://") and overrideId)
		or (Sounds.Projectiles and Sounds.Projectiles[attackName] and Sounds.Projectiles[attackName].Cast)
		or FALLBACK_SOUND

	local vol = opts.Volume or 0.02
	local pmin = opts.PitchMin or 70
	local pmax = opts.PitchMax or 90

	if typeof(origin) == "Instance" then
		playSoundAtInstance(origin, soundId, vol, pmin, pmax)
	elseif typeof(origin) == "Vector3" then
		playSoundAtPosition(origin, soundId, vol, pmin, pmax)
	else
		warn("SFX.Attack origin must be Instance or Vector3")
	end
end

function SFXModule.Impact(hitAt: any, attackName: string, overrideId: string?, opts: any?)
	opts = opts or {}

	local soundId =
		(overrideId and overrideId:find("rbxassetid://") and overrideId)
		or (Sounds.Projectiles and Sounds.Projectiles[attackName] and Sounds.Projectiles[attackName].Hit)
		or FALLBACK_SOUND

	local vol = opts.Volume or 0.8
	local pmin = opts.PitchMin or 92
	local pmax = opts.PitchMax or 102

	if typeof(hitAt) == "Instance" then
		playSoundAtInstance(hitAt, soundId, vol, pmin, pmax)
	elseif typeof(hitAt) == "Vector3" then
		playSoundAtPosition(hitAt, soundId, vol, pmin, pmax)
	else
		warn("SFX.Impact hitAt must be Instance or Vector3")
	end
end

return SFXModule

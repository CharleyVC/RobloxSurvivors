-- ReplicatedStorage/Controllers/AimAssist.lua
-- Hades-style aim assist that subtly biases toward nearby enemies.

local Workspace = game:GetService("Workspace")

local AimAssist = {}

AimAssist.Settings = {
	ConeAngleDegrees = 30,
	Range = 60,
	Strength = 0.25,
}

local function getEnemiesFolder()
	return Workspace:FindFirstChild("Enemies")
end

local function getForwardBase(baseDirection: Vector3): Vector3?
	if baseDirection.Magnitude <= 0 then
		return nil
	end
	return baseDirection.Unit
end

function AimAssist.GetAdjustedDirection(character: Model?, baseDirection: Vector3, overrideSettings: {[string]: number}?)
	local baseDir = getForwardBase(baseDirection)
	if not baseDir then
		return baseDirection
	end

	local settings = AimAssist.Settings
	if overrideSettings then
		settings = {
			ConeAngleDegrees = overrideSettings.ConeAngleDegrees or AimAssist.Settings.ConeAngleDegrees,
			Range = overrideSettings.Range or AimAssist.Settings.Range,
			Strength = overrideSettings.Strength or AimAssist.Settings.Strength,
		}
	end

	local enemiesFolder = getEnemiesFolder()
	if not enemiesFolder then
		return baseDir
	end

	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return baseDir
	end

	local maxRange = settings.Range
	local coneCos = math.cos(math.rad(settings.ConeAngleDegrees))
	local bestTargetDir: Vector3? = nil
	local bestScore = -1

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local enemyRoot = enemy:FindFirstChild("HumanoidRootPart")
			if enemyRoot then
				local toEnemy = enemyRoot.Position - root.Position
				local dist = toEnemy.Magnitude
				if dist > 0 and dist <= maxRange then
					local dir = toEnemy.Unit
					local dot = baseDir:Dot(dir)
					if dot >= coneCos then
						local score = dot / (dist + 1)
						if score > bestScore then
							bestScore = score
							bestTargetDir = dir
						end
					end
				end
			end
		end
	end

	if not bestTargetDir then
		return baseDir
	end

	local strength = math.clamp(settings.Strength, 0, 0.75)
	local adjusted = baseDir:Lerp(bestTargetDir, strength)
	if adjusted.Magnitude <= 0 then
		return baseDir
	end

	return adjusted.Unit
end

return AimAssist

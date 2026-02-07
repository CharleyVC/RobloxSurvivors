------------------------------------------------------------
-- CapsuleHitDetection
-- Math-based swept capsule collision for projectiles
-- Client-side, mobile-safe, industry-standard
------------------------------------------------------------

local CapsuleHitDetection = {}

------------------------------------------------------------
-- Enemy capsule definition
------------------------------------------------------------
function CapsuleHitDetection.GetEnemyCapsule(enemyModel: Model)
	local humanoid = enemyModel:FindFirstChildOfClass("Humanoid")
	local hrp = enemyModel:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then return nil end

	local halfHeight = humanoid.HipHeight + (hrp.Size.Y * 0.5)
	local up = Vector3.new(0, halfHeight, 0)

	local a = hrp.Position - up
	local b = hrp.Position + up

	local radius = math.max(hrp.Size.X, hrp.Size.Z) * 0.6

	return a, b, radius
end

------------------------------------------------------------
-- Closest points between two segments
------------------------------------------------------------
function CapsuleHitDetection.ClosestPointsOnSegments(p1, q1, p2, q2)
	local d1 = q1 - p1
	local d2 = q2 - p2
	local r = p1 - p2

	local a = d1:Dot(d1)
	local e = d2:Dot(d2)
	local f = d2:Dot(r)

	local s, t

	if a <= 1e-6 and e <= 1e-6 then
		return p1, p2
	end

	if a <= 1e-6 then
		s = 0
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-6 then
			t = 0
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b

			if denom ~= 0 then
				s = math.clamp((b * f - c * e) / denom, 0, 1)
			else
				s = 0
			end

			t = (b * s + f) / e

			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end

	return p1 + d1 * s, p2 + d2 * t
end

------------------------------------------------------------
-- Capsule sweep test
------------------------------------------------------------
function CapsuleHitDetection.CapsuleSweep(
	projA: Vector3,
	projB: Vector3,
	capA: Vector3,
	capB: Vector3,
	totalRadius: number
)
	local c1, c2 = CapsuleHitDetection.ClosestPointsOnSegments(
		projA, projB,
		capA, capB
	)
	return (c1 - c2).Magnitude <= totalRadius
end

------------------------------------------------------------
-- Public helper: projectile vs enemies
------------------------------------------------------------
function CapsuleHitDetection.CheckProjectileHit(
	lastPos: Vector3,
	currentPos: Vector3,
	projectileRadius: number,
	enemiesFolder: Folder
)
	if not enemiesFolder then return nil end

	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		local a, b, r = CapsuleHitDetection.GetEnemyCapsule(enemy)
		if a then
			if CapsuleHitDetection.CapsuleSweep(
				lastPos,
				currentPos,
				a,
				b,
				r + projectileRadius
				) then
				return enemy
			end
		end
	end

	return nil
end

return CapsuleHitDetection

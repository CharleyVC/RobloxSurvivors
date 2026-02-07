--!strict
-- Simple per-player rate limiter utility.

local RateLimiter = {}

local buckets: {[Player]: {[string]: number}} = {}

local function now(): number
	return os.clock()
end

function RateLimiter.Allow(player: Player, key: string, interval: number): boolean
	if not player or typeof(key) ~= "string" or typeof(interval) ~= "number" then
		return false
	end

	local playerBuckets = buckets[player]
	if not playerBuckets then
		playerBuckets = {}
		buckets[player] = playerBuckets
	end

	local last = playerBuckets[key] or 0
	local current = now()
	if current - last < interval then
		return false
	end

	playerBuckets[key] = current
	return true
end

function RateLimiter.Clear(player: Player)
	buckets[player] = nil
end

return RateLimiter

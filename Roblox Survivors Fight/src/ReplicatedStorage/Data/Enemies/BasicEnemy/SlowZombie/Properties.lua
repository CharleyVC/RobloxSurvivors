-- Find the humanoid in the enemy model

local animationTable = {
	humanoid = nil,
	category = "Enemy",
	specificType = "SlowZombie",
	animations = nil,
	state = "Idle",
	weight = 1,
	target = nil
}


local propertiesTable = {
	attackDistance = 5,
	attackCooldown = 1,
	damage = 3,
	exp = 5,
	health = 70,
	stopDistance = 4,
	walkSpeed = 6
}

return {animTable = animationTable, propTable = propertiesTable}
-- Find the humanoid in the enemy model


local animationTable = {
	humanoid = nil,
	category = "Enemy",
	specificType = "StrongZombie",
	animations = nil,
	state = "Idle",
	weight = 1,
	target = nil
}


local propertiesTable = {
	attackDistance = 5,
	attackCooldown = 1,
	damage = 10,
	exp = 7,
	health = 150,
	stopDistance = 4,
	walkSpeed = 8
}


return {animTable = animationTable, propTable = propertiesTable}
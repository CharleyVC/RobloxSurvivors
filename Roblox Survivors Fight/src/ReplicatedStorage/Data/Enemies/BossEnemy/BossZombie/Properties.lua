
local animationTable = {
	humanoid = nil,
	category = "Enemy",
	specificType = "BossZombie",
	animations = nil,
	state = "Idle",
	weight = 1,
	target = nil
}


local propertiesTable = {
	attackDistance = 5,
	attackCooldown = 1,
	damage = 40,
	exp = 50,
	health = 500,
	stopDistance = 4,
	walkSpeed = 5
}

return {animTable = animationTable, propTable = propertiesTable}
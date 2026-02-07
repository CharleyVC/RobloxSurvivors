
local Properties = {}

local animationTable = {
	humanoid = nil,
	category = "Enemy",
	specificType = "ArcherSkeleton",
	animations = nil,
	state = "Idle",
	weight = 1,
	target = nil
}


local propertiesTable = {
	attackDistance = 25,
	attackCooldown = 15,
	damage = 10,
	exp = 10,
	health = 100,
	stopDistance = 20,
	walkSpeed = 8
}

return {animTable = animationTable, propTable = propertiesTable}
local animationHandler = require(game.ReplicatedStorage.AnimationHandler)
local Properties = {}


local animationTable = {
	humanoid = nil,
	category = "Enemy",
	specificType = "RegZombie",
	animations = nil,
	state = "Idle",
	weight = 1,
	target = nil
}


local propertiesTable = {
	attackDistance = 5,
	attackCooldown = 1,
	damage = 5,
	exp = 5,
	health = 100,
	stopDistance = 4,
	walkSpeed = 12
}

return {animTable = animationTable, propTable = propertiesTable}
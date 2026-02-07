-- ServerScriptService/Scripts/AbilityProperties.lua

AbilityProperties = {}

AbilityProperties.Dash = {
	Slot = "Dash",
	
	Tags = {"Ability","Movement","Invulnerable","NoCollide"},
	Cooldown = 0.8,
	Duration = 0.5,
	Speed = 30,
	Movement = {
		HorizontalImpulse = 7,
		GravityScale = .4,
	},
	SweepRadius = 2.5
}


return AbilityProperties

-- ModifierSetLibrary.lua
-- Pure data: source → modifier IDs

local ModifierSetLibrary = {}

ModifierSetLibrary.Weapon = {
	Fireball = {
		"DamageOnHit",
		"SmallExplosion",
		"AreaScheduler",
		"Burn",
		
	},
	
	Sword = {
		"DamageOnHit",
		"SmallExplosion",
	},
	Bow = {
		"DamageOnHit",
		"Pierce",
	},
}

ModifierSetLibrary.Generic = {
	"Invulnerability",
	"NoCollision"
}

ModifierSetLibrary.Ability = {
	--Call = {
	--	"BaseCallCharge",
	--	"BaseCallInvulnerability",
	--},
}

function ModifierSetLibrary.GetForWeapon(weaponName)
	return ModifierSetLibrary.Weapon[weaponName]
end

function ModifierSetLibrary.GetForAbility(abilityName)
	return ModifierSetLibrary.Ability[abilityName]
end

function ModifierSetLibrary.GetGeneric()
	return ModifierSetLibrary.Generic
end

return ModifierSetLibrary

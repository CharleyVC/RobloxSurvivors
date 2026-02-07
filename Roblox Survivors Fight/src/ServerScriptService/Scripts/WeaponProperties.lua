local weaponPropertiesRemote = game.ReplicatedStorage.RemoteEvents:WaitForChild("WeaponProperties")

local WeaponProperties = {
	
	Fireball = {
		
		Projectile = game.ReplicatedStorage.Data.Weapons.Fireball:FindFirstChild("Projectile"),
		
		Primary = {
			Type = "Projectile",
			Slot = "Primary",
			Tags = {"Projectile", "AreaCapable", "Fire"},
			Cooldown = 0.5,
			Velocity = 0.05, --Inserts in the duration function of the ArcProjectile, lower number means projectile has lower arc.
			Damage = 50,
			Range = 25,
			Radius = 5,
			Knockback = 50
		},
		
		Secondary = {
			Type = "Projectile",
			Slot = "Secondary",
			Tags = {"Projectile", "AreaCapable", "Fire"},
			Cooldown = 3,
			Velocity = 0.08,
			Damage = 0,
			Range = 10,
			Radius = 12.5,
			Knockback = 0,
			
			AoE = {
				Duration = 5,
				TickRate = 1,

			},
			
			Burn = {
				Mode = "Flat",        -- "Flat" | "Percent"
				Damage = 5,           -- per tick
				Duration = 5,
				Stacks = 1,
				Knockback = 2,
				Maxstacks = 5
			}
		},		
	},
}

weaponPropertiesRemote.OnServerInvoke = function(player, weaponName, key)
	return WeaponProperties[weaponName]
end

return WeaponProperties

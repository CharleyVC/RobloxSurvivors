return {
	Id = "DashBombs",
	God = "Pyrax",
	Action = "Dash",

	Modifiers = {
		"ApplyBombStacksOnTravel",
		"DetonateBombsOnExpire",
		"DetonateBombStacksOnHit",
	},

	Rarity = {
		Common = {
			Stacks = 1,
			MaxStacks = 5,
			DamagePerStack = 12,
			Radius = 6,
			Knockback = 3
			
		},

		Rare = {
			Stacks = 2,
			MaxStacks = 5,
			DamagePerStack = 14,
			Radius = 7,
			Knockback = 3
		},

		Epic = {
			Stacks = 2,
			MaxStacks = 7,
			DamagePerStack = 16,
			Radius = 8,
			Knockback = 3
		},
	},

	----------------------------------------------------------------
	-- Pom scaling (NO mechanical upgrades)
	----------------------------------------------------------------
	ScaleWithPom = function(baseData, pomLevel)
		return {
			Stacks = baseData.Stacks,
			MaxStacks = math.min(baseData.MaxStacks + pomLevel, 10),
			DamagePerStack = baseData.DamagePerStack + pomLevel * 3,
			Radius = baseData.Radius + pomLevel * 0.5,
		}
	end,

	BuildInjector = function(data)
		return function(context)
			-- Tags must remain a SET
			if context.AddTag then
				context:AddTag("Bomb")
			else
				-- fallback (if context isn't ActionContext for some reason)
				context.Tags = context.Tags or {}
				context.Tags["Bomb"] = true
			end

			-- Payload in Flags
			if context.SetFlag then
				context:SetFlag("Bomb", data)
			else
				context.Flags = context.Flags or {}
				context.Flags.Bomb = data
			end
		end
	end,

	Description = function(data)
		return ("Your Dash applies Bomb stacks on enemies passed OnTravel, Stacks blow up around you on dash end.\nBombs explode for %d damage per stack.\nMaxStacks: %d \nRadius: %d")
			:format(data.DamagePerStack, data.MaxStacks, data.Radius)
	end,
}

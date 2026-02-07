--!strict
-- BoonRarity.lua
-- Handles rarity rolling and data resolution

local BoonRarity = {}

-- Ordered lowest → highest
local RARITIES = {
	{ Name = "Common", Weight = 70 },
	{ Name = "Rare",   Weight = 20 },
	{ Name = "Epic",   Weight = 10 },
}

------------------------------------------------------------
-- Roll rarity
------------------------------------------------------------
function BoonRarity.Roll()
	local totalWeight = 0
	for _, r in ipairs(RARITIES) do
		totalWeight += r.Weight
	end

	local roll = math.random() * totalWeight
	local acc = 0

	for _, r in ipairs(RARITIES) do
		acc += r.Weight
		if roll <= acc then
			return r.Name
		end
	end

	return "Common"
end

------------------------------------------------------------
-- Resolve boon data for rarity
------------------------------------------------------------
function BoonRarity.Resolve(boon: any)
	local rarity = BoonRarity.Roll()
	local data = boon.Rarity and boon.Rarity[rarity]

	if not data then
		error(("Boon '%s' missing rarity data for %s")
			:format(boon.Id, rarity))
	end

	return rarity, table.clone(data)
end

return BoonRarity

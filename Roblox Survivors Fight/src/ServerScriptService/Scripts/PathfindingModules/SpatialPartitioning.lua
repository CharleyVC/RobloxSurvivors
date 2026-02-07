local SpatialPartitioning = {}
local sectors = {}

function SpatialPartitioning.initialize(gridSize)
	for x = 1, gridSize do
		sectors[x] = {}
		for z = 1, gridSize do
			sectors[x][z] = {}
		end
	end
end

function SpatialPartitioning.addNPC(npc)
	local sectorX = math.floor(npc.PrimaryPart.Position.X / 50)
	local sectorZ = math.floor(npc.PrimaryPart.Position.Z / 50)
	table.insert(sectors[sectorX][sectorZ], npc)
end

function SpatialPartitioning.getActiveSectors(player)
	local activeSectors = {}
	local playerSectorX = math.floor(player.Character.PrimaryPart.Position.X / 50)
	local playerSectorZ = math.floor(player.Character.PrimaryPart.Position.Z / 50)

	for x = playerSectorX - 1, playerSectorX + 1 do
		for z = playerSectorZ - 1, playerSectorZ + 1 do
			if sectors[x] and sectors[x][z] then
				for _, npc in ipairs(sectors[x][z]) do
					table.insert(activeSectors, npc)
				end
			end
		end
	end

	return activeSectors
end

return SpatialPartitioning

local VisibilityMap = {}
local DataStoreService = game:GetService("DataStoreService")
local visibilityStore = DataStoreService:GetDataStore("VisibilityMap")
local workspace = game:GetService("Workspace")

local mapGrid = {}
local cellSize = 25 -- Adjust based on performance and resolution
local visibilityRadius = 50 -- Maximum distance for LOS checks

-- Calculate grid size dynamically based on the map
local function calculateGridSize(map)
	local mapSize = map.Size
	local mapPosition = map.Position
	local gridSizeX = math.ceil(mapSize.X / cellSize)
	local gridSizeZ = math.ceil(mapSize.Z / cellSize)

	-- Add 1 to ensure edges are included
	return {
		gridSizeX = gridSizeX + 1,
		gridSizeZ = gridSizeZ + 1,
		startX = mapPosition.X - (mapSize.X / 2),
		startZ = mapPosition.Z - (mapSize.Z / 2)
	}
end

-- Debug the LOS between two cells
local function debugLineOfSight(cellA, cellB, hasLOS)
	local lineColor = hasLOS and BrickColor.new("Bright green") or BrickColor.new("Bright red")
	local line = Instance.new("Part")
	line.Size = Vector3.new(0.2, 0.2, (cellB - cellA).Magnitude)
	line.CFrame = CFrame.new(cellA, cellB) * CFrame.new(0, 0, -line.Size.Z / 2)
	line.Anchored = true
	line.BrickColor = lineColor
	line.CanCollide = false
	line.Parent = workspace.DebugLines
end

-- Precompute the visibility map
function VisibilityMap.precompute(map)
	local gridInfo = calculateGridSize(map)
	local gridSizeX, gridSizeZ = gridInfo.gridSizeX, gridInfo.gridSizeZ
	local startX, startZ = gridInfo.startX, gridInfo.startZ

	for x = 0, gridSizeX do
		for z = 0, gridSizeZ do
			local cellA = Vector3.new(startX + x * cellSize, 5, startZ + z * cellSize)

			if not mapGrid[cellA] then
				mapGrid[cellA] = {}
			end

			for x2 = 0, gridSizeX do
				for z2 = 0, gridSizeZ do
					local cellB = Vector3.new(startX + x2 * cellSize, 5, startZ + z2 * cellSize)
					if cellA ~= cellB and (cellB - cellA).Magnitude <= visibilityRadius then
						local direction = (cellB - cellA).Unit
						local distance = (cellB - cellA).Magnitude
						local rayParams = RaycastParams.new()
						rayParams.FilterType = Enum.RaycastFilterType.Include
						rayParams.FilterDescendantsInstances = {workspace.Obstacles}

						local rayResult = workspace:Raycast(cellA, direction * distance, rayParams)
						if not rayResult then
							table.insert(mapGrid[cellA], cellB)
							--debugLineOfSight(cellA, cellB, true)
						else
							--debugLineOfSight(cellA, cellB, false)
						end
					end
				end
			end
		end
	end
end

-- Check if there's line of sight between two positions
function VisibilityMap.hasLineOfSight(startPos, targetPos)
	local startCell = Vector3.new(math.floor(startPos.X / cellSize) * cellSize, 5, math.floor(startPos.Z / cellSize) * cellSize)
	local targetCell = Vector3.new(math.floor(targetPos.X / cellSize) * cellSize, 5, math.floor(targetPos.Z / cellSize) * cellSize)

	if mapGrid[startCell] then
		return table.find(mapGrid[startCell], targetCell) ~= nil
	else
		return false
	end
end

-- Save the visibility map to a DataStore
function VisibilityMap.save()
	local serializedGrid = {}
	for cellA, visibleCells in pairs(mapGrid) do
		serializedGrid[tostring(cellA)] = {}
		for _, cellB in ipairs(visibleCells) do
			table.insert(serializedGrid[tostring(cellA)], tostring(cellB))
		end
	end

	local success, errorMessage = pcall(function()
		visibilityStore:SetAsync("mapGrid", serializedGrid)
	end)

	if success then
		print("Visibility Map successfully saved!")
	else
		warn("Failed to save Visibility Map:", errorMessage)
	end
end

local function parseVector3(stringValue)
	local components = stringValue:gmatch("[-%d%.]+")
	local x, y, z = tonumber(components()), tonumber(components()), tonumber(components())
	return Vector3.new(x, y, z)
end

function VisibilityMap.load()
	local success, result = pcall(function()
		return visibilityStore:GetAsync("mapGrid")
	end)

	if success and result then
		mapGrid = {}
		for cellAString, visibleCells in pairs(result) do
			local cellA = parseVector3(cellAString)
			mapGrid[cellA] = {}
			for _, cellBString in ipairs(visibleCells) do
				local cellB = parseVector3(cellBString)
				table.insert(mapGrid[cellA], cellB)
			end
		end
		print("Visibility Map successfully loaded!")
	else
		warn("Failed to load Visibility Map:", result or "No data found.")
		mapGrid = {} -- Initialize to avoid nil access
	end
end

return VisibilityMap

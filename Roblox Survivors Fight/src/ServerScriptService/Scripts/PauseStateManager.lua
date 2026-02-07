--!strict
-- ServerScriptService/PauseStateManager.lua
-- Temporary global pause solution:
--   - Anchors all physics
--   - Freezes characters & NPCs
--   - Sets workspace.IsPaused attribute
-- This can later be replaced with a purely declarative pause system.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PauseStateManager = {}

------------------------------------------------------------
-- Internal state
------------------------------------------------------------

local isPaused = false

-- Track original anchored states so we can restore them safely
-- [BasePart] = boolean
local originalAnchored: {[BasePart]: boolean} = {}

------------------------------------------------------------
-- Utilities
------------------------------------------------------------

local function storeAndAnchor(part: BasePart)
	if originalAnchored[part] == nil then
		originalAnchored[part] = part.Anchored
	end
	part.Anchored = true
end

local function restoreAnchor(part: BasePart)
	local prev = originalAnchored[part]
	if prev ~= nil then
		part.Anchored = prev
	end
end

------------------------------------------------------------
-- Anchor logic
------------------------------------------------------------

local function anchorCharacter(model: Model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			storeAndAnchor(inst)
		end
	end
end

local function anchorWorld()
	-- Characters (players)
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			anchorCharacter(char)
		end
	end

	-- NPCs / Enemies
	local enemies = Workspace:FindFirstChild("Enemies")
	if enemies then
		for _, enemy in ipairs(enemies:GetChildren()) do
			if enemy:IsA("Model") then
				anchorCharacter(enemy)
			end
		end
	end

	-- Loose physics parts (projectiles, debris, etc.)
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and not inst:IsDescendantOf(Workspace.Terrain) then
			storeAndAnchor(inst)
		end
	end
end

local function restoreWorld()
	for part, _ in pairs(originalAnchored) do
		if part and part.Parent then
			restoreAnchor(part)
		end
	end

	table.clear(originalAnchored)
end

------------------------------------------------------------
-- Public API
------------------------------------------------------------

function PauseStateManager.Pause()
	if isPaused then
		return
	end
	isPaused = true

	workspace:SetAttribute("IsPaused", true)

	anchorWorld()
end

function PauseStateManager.Resume()
	if not isPaused then
		return
	end
	isPaused = false

	workspace:SetAttribute("IsPaused", false)

	restoreWorld()
end

function PauseStateManager.IsPaused()
	return isPaused
end

------------------------------------------------------------
-- Safety: clean up destroyed parts
------------------------------------------------------------

-- Prevent memory leaks if parts are destroyed while paused
Workspace.DescendantRemoving:Connect(function(inst)
	if inst:IsA("BasePart") then
		originalAnchored[inst] = nil
	end
end)

return PauseStateManager

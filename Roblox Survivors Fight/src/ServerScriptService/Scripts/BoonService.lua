--!strict
-- BoonService.lua
-- Canonical boon application service (injector + modifier dependency resolution)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------
-- Dependencies
------------------------------------------------------------
local SlotContext =	require(game.ServerScriptService.Scripts.SlotContext)

local BoonRarity =	require(game.ServerScriptService.Scripts:WaitForChild("BoonRarity"))

local ModifierRegistrationService =require(game.ServerScriptService.Scripts:WaitForChild("ModifierRegistrationService"))

local ActionModifierService =	require(game.ReplicatedStorage.Combat.ActionModifierService)

------------------------------------------------------------
-- Runtime state (inspectable, pure data)
------------------------------------------------------------
-- [character] -> { [slot] = { Id, God, Rarity, Data } }
local ActiveBoons: { [Instance]: { [string]: any } } = {}
local BoonService = {}
------------------------------------------------------------
-- Internal validation
------------------------------------------------------------
local function validateBoon(boon: any)
	assert(type(boon) == "table", "Boon must be a table")
	assert(type(boon.Id) == "string", "Boon missing Id")
	assert(type(boon.God) == "string", "Boon missing God")
	assert(type(boon.Action) == "string", "Boon missing Action Slot")
	assert(type(boon.Rarity) == "table", "Boon missing Rarity table")
	if boon.BuildInjector then
		assert(type(boon.BuildInjector) == "function", "BuildInjector must be function")
	end
	if boon.Modifiers then
		assert(type(boon.Modifiers) == "table", "Modifiers must be table")
	end
end

------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------
function BoonService.InitCharacter(character: Model)
	ActiveBoons[character] = {}
	SlotContext.InitCharacter(character)
end

function BoonService.ClearCharacter(character: Model)
	ActiveBoons[character] = nil
	SlotContext.ClearCharacter(character)
end

------------------------------------------------------------
-- Core API
------------------------------------------------------------
function BoonService.ApplyBoon(
	character: Model,
	godName: string,
	boonId: string
)
	--------------------------------------------------------
	-- Resolve boon module
	--------------------------------------------------------
	local boonsRoot = ReplicatedStorage.Combat.Boons
	local godFolder = boonsRoot:FindFirstChild(godName)

	if not godFolder then
		error(("God folder not found: %s"):format(godName))
	end

	local boonModule = godFolder:FindFirstChild(boonId)
	if not boonModule then
		error(("Boon not found: %s.%s"):format(godName, boonId))
	end

	local boon = require(boonModule)
	validateBoon(boon)

	--------------------------------------------------------
	-- Roll rarity + resolve data
	--------------------------------------------------------
	local rarity, data = BoonRarity.Resolve(boon)

	--------------------------------------------------------
	-- Register required modifiers (idempotent)
	--------------------------------------------------------
	if boon.Modifiers then
		ModifierRegistrationService.RegisterSet(character, boon.Modifiers)
	end

	--------------------------------------------------------
	-- Replace slot behavior (injectors)
	--------------------------------------------------------
	SlotContext.ClearSlot(character, boon.Action)

	if boon.BuildInjector then
		local injectorFn = boon.BuildInjector(data)

		SlotContext.AddInjector(
			character,
			boon.Action,
			boon.Id,
			injectorFn
		)
	end
	print("[BoonService] Applying boon:", godName, boonId)
	--------------------------------------------------------
	-- Persist runtime state (debug / UI)
	--------------------------------------------------------
	ActiveBoons[character][boon.Action] = {
		Id = boon.Id,
		God = boon.God,
		Rarity = rarity,
		PomLevel = 0,
		Data = data,
	}
end

------------------------------------------------------------
-- Pom application (incremental boon leveling)
------------------------------------------------------------
function BoonService.ApplyPom(character: Model, Action: string)
	local boonState = ActiveBoons[character]
		and ActiveBoons[character][Action]

	if not boonState then
		return
	end

	local boonsRoot = ReplicatedStorage.Combat.Boons
	local godFolder = boonsRoot:FindFirstChild(boonState.God)
	if not godFolder then return end

	local boonModule = godFolder:FindFirstChild(boonState.Id)
	if not boonModule then return end

	local boon = require(boonModule)

	-- Boon does not support Pom scaling
	if not boon.ScaleWithPom then
		return
	end

	--------------------------------------------------------
	-- Increment Pom level
	--------------------------------------------------------
	boonState.PomLevel = (boonState.PomLevel or 0) + 1

	--------------------------------------------------------
	-- Recalculate scaled data
	--------------------------------------------------------
	local scaledData = boon.ScaleWithPom(
		boonState.Data,
		boonState.PomLevel
	)

	--------------------------------------------------------
	-- Rebuild injector with new data
	--------------------------------------------------------
	SlotContext.ClearSlot(character, Action)

	local injectorFn = boon.BuildInjector(scaledData)

	SlotContext.AddInjector(
		character,
		Action,
		boon.Id,
		injectorFn
	)

	--------------------------------------------------------
	-- Persist updated data
	--------------------------------------------------------
	boonState.Data = scaledData
end


------------------------------------------------------------
-- Inspection / Debug
------------------------------------------------------------
function BoonService.DebugGetActiveBoons(character: Model)
	return ActiveBoons[character]
end

function BoonService.DebugGetBoon(character: Model, Action: string)
	return ActiveBoons[character] and ActiveBoons[character][Action]
end

return BoonService

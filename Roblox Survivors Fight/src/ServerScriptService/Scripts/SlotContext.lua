--!strict
-- SlotContext.lua
-- Action slot-based ActionContext decoration with full runtime inspection

local SlotContext = {}

------------------------------------------------------------
-- Internal storage
------------------------------------------------------------
-- [character] -> {
--     [action] = {
--         {
--             Id = string,           -- source (boon / system)
--             Apply = (context) -> () -- injector function
--         }
--     }
-- }
local Injectors: {
	[Instance]: {
		[string]: {
			{
				Id: string,
				Apply: (any) -> ()
			}
		}
	}
} = {}

------------------------------------------------------------
-- Lifecycle
------------------------------------------------------------
function SlotContext.InitCharacter(character: Model)
	Injectors[character] = {}
end

function SlotContext.ClearCharacter(character: Model)
	Injectors[character] = nil
end

------------------------------------------------------------
-- Slot management
------------------------------------------------------------
function SlotContext.ClearSlot(character: Model, action: string)
	local actions = Injectors[character]
	if not actions then return end
	actions[action] = {}
end

function SlotContext.AddInjector(
	character: Model,
	action: string,
	id: string,
	applyFn: (any) -> ()
)
	assert(type(id) == "string", "Injector id must be string")
	assert(type(applyFn) == "function", "Injector Apply must be function")

	if not Injectors[character] then
		Injectors[character] = {}
	end
	if not Injectors[character][action] then
		Injectors[character][action] = {}
	end

	table.insert(Injectors[character][action], {
		Id = id,
		Apply = applyFn,
	})
end

------------------------------------------------------------
-- Apply injectors
------------------------------------------------------------
function SlotContext.Apply(character: Model, action: string, context: any)
	local actions = Injectors[character]
	if not actions then return end

	local list = actions[action]
	if not list then return end

	for _, injector in ipairs(list) do
		injector.Apply(context)
	end
end

------------------------------------------------------------
-- Debug / Inspection
------------------------------------------------------------
function SlotContext.DebugGetSlots(character: Model)
	return Injectors[character]
end

function SlotContext.DebugGetInjectors(character: Model, action: string)
	local actions = Injectors[character]
	return actions and actions[action]
end

function SlotContext.DebugDump(character: Model)
	local dump = {}
	local actions = Injectors[character]
	if not actions then return dump end

	for action, list in pairs(actions) do
		dump[action] = {}
		for _, injector in ipairs(list) do
			table.insert(dump[action], injector.Id)
		end
	end

	return dump
end

return SlotContext

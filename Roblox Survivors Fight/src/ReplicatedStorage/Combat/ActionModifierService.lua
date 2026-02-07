--!strict
-- ReplicatedStorage/Combat/ActionModifierService.lua
-- Shared on Server + Client. Server registers authority modifiers; client registers VFX modifiers.

local ActionModifierService = {}

--// Types (informal; Roblox Luau doesn't enforce fully unless you add type aliases everywhere)
-- Modifier contract:
-- {
--   Id: string,                                   -- required unique id
--   Phases: { [string]: true } | {string},         -- required; set or list of phases
--   Priority: number?,                            -- optional; default 0
--   AppliesTo: "All" | string | { [string]: true } | {string}?,  -- optional; default "All"
--   RequiredTags: { [string]: true } | {string}?, -- optional
--   Replaces: {string}?,                          -- optional; list of modifier ids to remove on add
--   Execute: (context: any) -> (),                -- required
-- }

-- Weak keys so actor registries auto-clean when actor is GC'd (Players/NPC models removed)
local _actors = setmetatable({}, { __mode = "k" }) :: { [Instance]: any }

local _globalInsertCounter = 0

local function _toSet(listOrSet: any): { [string]: true }
	if listOrSet == nil then
		return {}
	end
	if typeof(listOrSet) ~= "table" then
		return {}
	end

	-- Heuristic: if it has non-numeric keys, assume it's already a set
	for k, _ in pairs(listOrSet) do
		if typeof(k) ~= "number" then
			return listOrSet
		end
	end

	-- Otherwise treat as an array/list
	local set = {}
	for _, v in ipairs(listOrSet) do
		if typeof(v) == "string" then
			set[v] = true
		end
	end
	return set
end

local function _normalizeAppliesTo(appliesTo: any): { [string]: true }
	-- Defaults to All actions
	if appliesTo == nil or appliesTo == "All" then
		return { All = true }
	end

	if typeof(appliesTo) == "string" then
		return { [appliesTo] = true }
	end

	return _toSet(appliesTo)
end

local function _ensureActorRegistry(actor: Instance)
	local reg = _actors[actor]
	if reg then
		return reg
	end

	reg = {
		-- ById -> modifierRecord
		ById = {},

		-- ActionSlot -> Phase -> {modifierRecords...}
		ByAction = {},
	}

	_actors[actor] = reg
	return reg
end

local function _getContextAction(context: any): string?
	-- We standardize on context.Action (recommended). If you use ActionSlot, we support that too.
	if context == nil then return nil end
	if typeof(context) ~= "table" then return nil end

	local a = context.Action
	if typeof(a) == "string" then return a end

	local b = context.ActionSlot
	if typeof(b) == "string" then return b end

	return nil
end

local function _contextHasTag(context: any, tag: string): boolean
	if context == nil or typeof(context) ~= "table" then
		return false
	end

	-- If you implement context:HasTag(), we’ll use it.
	local hasTagFn = context.HasTag
	if typeof(hasTagFn) == "function" then
		-- call as method if possible
		local ok, result = pcall(function()
			return (context :: any):HasTag(tag)
		end)
		if ok and typeof(result) == "boolean" then
			return result
		end
	end

	-- Otherwise check Tags as set or list
	local tags = context.Tags
	if typeof(tags) ~= "table" then
		return false
	end

	-- set form
	if tags[tag] == true then
		return true
	end

	-- list form
	for _, v in ipairs(tags) do
		if v == tag then
			return true
		end
	end

	return false
end

local function _passesRequiredTags(context: any, requiredTagsSet: { [string]: true }): boolean
	for tag, _ in pairs(requiredTagsSet) do
		if not _contextHasTag(context, tag) then
			return false
		end
	end
	return true
end

local function _passesAppliesTo(actionSet: { [string]: true }, actionName: string?): boolean
	if actionSet.All then
		return true
	end
	if not actionName then
		return false
	end
	return actionSet[actionName] == true
end

local function _normalizePhases(phases: any): { [string]: true }
	-- phases is required. Accept set or list.
	return _toSet(phases)
end

local function _validateModifier(mod: any): (boolean, string?)
	if typeof(mod) ~= "table" then
		return false, "modifier must be a table"
	end
	if typeof(mod.Id) ~= "string" or mod.Id == "" then
		return false, "modifier.Id must be a non-empty string"
	end
	if mod.Execute == nil or typeof(mod.Execute) ~= "function" then
		return false, ("modifier.Execute must be a function (Id=%s)"):format(mod.Id)
	end
	if mod.Phases == nil then
		return false, ("modifier.Phases is required (Id=%s)"):format(mod.Id)
	end

	local phasesSet = _normalizePhases(mod.Phases)
	local hasAny = false
	for _ in pairs(phasesSet) do
		hasAny = true
		break
	end
	if not hasAny then
		return false, ("modifier.Phases must include at least 1 phase (Id=%s)"):format(mod.Id)
	end

	return true, nil
end

local function _indexRecord(reg: any, rec: any)
	-- rec has: Id, Priority, InsertOrder, PhasesSet, AppliesToSet, RequiredTagsSet, Execute, Source, Tier
	-- Place into reg.ByAction[action][phase] list
	for phase, _ in pairs(rec.PhasesSet) do
		for actionName, _ in pairs(rec.AppliesToSet) do
			-- AppliesToSet may be {All=true} or explicit actions
			local actionKey = actionName
			if actionName == "All" then
				actionKey = "All"
			end

			reg.ByAction[actionKey] = reg.ByAction[actionKey] or {}
			reg.ByAction[actionKey][phase] = reg.ByAction[actionKey][phase] or {}

			table.insert(reg.ByAction[actionKey][phase], rec)
		end
	end
end

local function _deindexRecord(reg: any, rec: any)
	for actionKey, phases in pairs(reg.ByAction) do
		for phase, list in pairs(phases) do
			for i = #list, 1, -1 do
				if list[i] == rec then
					list[i] = list[#list]
					list[#list] = nil
				end
			end
			if #list == 0 then
				phases[phase] = nil
			end
		end
		if next(phases) == nil then
			reg.ByAction[actionKey] = nil
		end
	end
end

-- Public API
-- ===================================================================

-- Register a modifier for an actor.
-- If a modifier with the same Id already exists, it is replaced (removed then added).
function ActionModifierService.RegisterModifier(actor: Instance, mod: any): boolean
	if not actor or not actor:IsA("Instance") then
		warn("[ActionModifierService] RegisterModifier: actor must be an Instance")
		return false
	end

	local ok, err = _validateModifier(mod)
	if not ok then
		warn("[ActionModifierService] RegisterModifier invalid:", err)
		return false
	end

	local reg = _ensureActorRegistry(actor)

	-- Apply replacement rules first
	if typeof(mod.Replaces) == "table" then
		for _, replaceId in ipairs(mod.Replaces) do
			if typeof(replaceId) == "string" then
				ActionModifierService.UnregisterModifier(actor, replaceId)
			end
		end
	end

	-- If same id exists, remove it (explicit update semantics)
	if reg.ById[mod.Id] then
		ActionModifierService.UnregisterModifier(actor, mod.Id)
	end

	_globalInsertCounter += 1

	local rec = {
		Id = mod.Id,
		Source = mod.Source,
		Tier = mod.Tier,
		Priority = (typeof(mod.Priority) == "number") and mod.Priority or 0,
		InsertOrder = _globalInsertCounter,
		PhasesSet = _normalizePhases(mod.Phases),
		AppliesToSet = _normalizeAppliesTo(mod.AppliesTo),
		RequiredTagsSet = _toSet(mod.RequiredTags),
		Execute = mod.Execute,
		__raw = mod, -- for debugging/inspection if you want
	}

	reg.ById[rec.Id] = rec
	_indexRecord(reg, rec)

	return true
end

function ActionModifierService.UnregisterModifier(actor: Instance, modifierId: string): boolean
	if not actor or not actor:IsA("Instance") then
		return false
	end
	if typeof(modifierId) ~= "string" or modifierId == "" then
		return false
	end

	local reg = _actors[actor]
	if not reg then
		return false
	end

	local rec = reg.ById[modifierId]
	if not rec then
		return false
	end

	_deindexRecord(reg, rec)
	reg.ById[modifierId] = nil

	return true
end

function ActionModifierService.ClearActor(actor: Instance)
	if not actor or not actor:IsA("Instance") then
		return
	end
	_actors[actor] = nil
end

-- Dispatch a phase for an actor and context.
-- Returns the number of modifiers executed.
function ActionModifierService.DispatchPhase(actor: Instance, phase: string, context: any): number
	if not actor or not actor:IsA("Instance") then
		return 0
	end
	if typeof(phase) ~= "string" or phase == "" then
		return 0
	end

	local reg = _actors[actor]
	if not reg then
		return 0
	end

	local actionName = _getContextAction(context)

	-- Collect modifiers for action-specific + All
	local collected = {}

	local function collectFrom(actionKey: string)
		local phases = reg.ByAction[actionKey]
		if not phases then return end
		local list = phases[phase]
		if not list then return end
		for _, rec in ipairs(list) do
			table.insert(collected, rec)
		end
	end

	-- Add explicit action group first (if any), then All
	if actionName then
		collectFrom(actionName)
	end
	collectFrom("All")

	if #collected == 0 then
		return 0
	end

	-- Filter + sort deterministic: higher Priority first, then InsertOrder
	local required = {}
	for i = 1, #collected do
		local rec = collected[i]

		-- AppliesTo gating (handles "All" set or explicit)
		if not _passesAppliesTo(rec.AppliesToSet, actionName) then
			continue
		end

		-- RequiredTags gating
		if rec.RequiredTagsSet and next(rec.RequiredTagsSet) ~= nil then
			if not _passesRequiredTags(context, rec.RequiredTagsSet) then
				continue
			end
		end

		table.insert(required, rec)
	end

	if #required == 0 then
		return 0
	end

	table.sort(required, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.InsertOrder < b.InsertOrder
	end)

	local executed = 0
	for _, rec in ipairs(required) do
		local ok, execErr = pcall(rec.Execute, context)
		if not ok then
			warn(("[ActionModifierService] Modifier '%s' failed in phase '%s': %s")
				:format(rec.Id, phase, tostring(execErr)))
		else
			executed += 1
		end
	end
	--print("[Dispatch]", phase, context.Action)
	return executed
end

-- Optional: inspect modifiers (useful for debugging and UI)
function ActionModifierService.GetActorModifierIds(actor: Instance): {string}
	local reg = _actors[actor]
	if not reg then return {} end
	local out = {}
	for id in pairs(reg.ById) do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return ActionModifierService

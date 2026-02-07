-- ReplicatedStorage/Combat/ActionContext.lua

local ActionContext = {}
ActionContext.__index = ActionContext

-- Create a new context
function ActionContext.new(params)
	-- params is just a table you pass in
	local self = setmetatable({}, ActionContext)

	-- === IMMUTABLE / IDENTITY ===
	self.Actor = params.Actor           -- Player or NPC Model
	self.Action = params.Action         -- "Primary", "Secondary", "Dash"
	self.BaseType = params.BaseType     -- "Projectile", "Melee", etc.
	self.Source = params.Source         -- Weapon / Ability name (string or table)

	-- === TAGS ===
	-- Stored as a SET for fast lookup
	self.Tags = {}
	if params.Tags then
		for _, tag in ipairs(params.Tags) do
			self.Tags[tag] = true
		end
	end

	-- === MUTABLE COMBAT DATA ===
	self.Damage = params.Damage or 0
	self.Range = params.Range
	self.Speed = params.Speed
	self.Radius = params.Radius
	self.Knockback = params.Knockback or 0

	-- === RUNTIME DATA (filled later) ===
	self.Projectile = nil
	self.HitTarget = nil
	self.HitPosition = nil
	self.KilledTarget = nil

	-- === FLAGS / SCRATCHPAD ===
	self.Flags = {} -- modifiers can stash info here

	return self
end

-- === TAG HELPERS ===

function ActionContext:AddTag(tag)
	self.Tags[tag] = true
end

function ActionContext:RemoveTag(tag)
	self.Tags[tag] = nil
end

function ActionContext:HasTag(tag)
	return self.Tags[tag] == true
end

-- === FLAG HELPERS ===

function ActionContext:SetFlag(name, value)
	self.Flags[name] = value
end

function ActionContext:GetFlag(name)
	return self.Flags[name]
end

return ActionContext

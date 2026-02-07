-- ModifierRegistrationService.lua

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionModifierService = require(ReplicatedStorage.Combat.ActionModifierService)

local ModifierRegistrationService = {}

local ModifierFolder = game.ReplicatedStorage.Combat.Modifiers

function ModifierRegistrationService.RegisterSet(character, modifierIds)
	if not modifierIds then return end

	for _, id in ipairs(modifierIds) do
		
		
		for _, moduleScript in ipairs(ModifierFolder:GetChildren()) do
			if moduleScript:IsA("ModuleScript") and moduleScript.Name == id then
			local ok, mod = pcall(require, moduleScript)
			if not ok then
				warn("[ModifierRegistry] Failed to require:", id, mod)
				return
			end
			
				ActionModifierService.RegisterModifier(character, mod)
			end
		end
	end
end

return ModifierRegistrationService

local FiltersModule = {}

-- Filter to exclude the source player from being affected
function FiltersModule.avoidSelf(target, source)
	local targetPlayer = game.Players:GetPlayerFromCharacter(target)
	return targetPlayer ~= source -- Affect only if the target is not the source
end

-- Filter to affect only enemies (using Teams service)
function FiltersModule.damageOnlyEnemies(target, source)
	local targetPlayer = game.Players:GetPlayerFromCharacter(target)
	local sourcePlayer = game.Players:GetPlayerFromCharacter(source)
	if targetPlayer and sourcePlayer then
		return targetPlayer.Team ~= sourcePlayer.Team -- Affect only if not on the same team
	end
	return true -- Affect non-player entities like NPCs
end

-- Filter to exclude invulnerable entities
function FiltersModule.excludeInvulnerable(target, source)
	local humanoid = target:FindFirstChild("Humanoid")
	local status = target:FindFirstChild("Status")
	if humanoid and (not status or not status:FindFirstChild("Invulnerable")) then
		return true -- Target is valid if it has a humanoid and is not invulnerable
	end
	return false
end

-- Filter to damage only NPCs in the Enemies folder
function FiltersModule.damageOnlyNPCs(target, source)
	return target.Parent == workspace.Enemies
end

-- Filter to hurt players and protect NPCs
function FiltersModule.hurtPlayersOnly(target, source)
	local targetPlayer = game.Players:GetPlayerFromCharacter(target)

	if targetPlayer then
		return true -- Hurt players
	end

	if target.Parent == workspace.Enemies then
		return false -- Protect NPCs
	end

	return false -- Default: Do not affect other entities
end

return FiltersModule

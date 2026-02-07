--!strict
-- ServerScriptService/LevelUpServer.lua
-- Multiplayer-safe level-up system with Action-based boons + Pom fallback
-- Pause state is driven purely by workspace attribute: IsPaused

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

------------------------------------------------------------
-- Dependencies
------------------------------------------------------------
local BoonService = require(game.ServerScriptService.Scripts.BoonService)
local BoonRarity  = require(game.ServerScriptService.Scripts.BoonRarity)
local PauseStateManager = require(game.ServerScriptService.Scripts:WaitForChild("PauseStateManager"))
------------------------------------------------------------
-- Events
------------------------------------------------------------
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local LevelUpRemote = Remotes:WaitForChild("LevelUpEvent")

local LevelUpEvent =ReplicatedStorage.BindableEvents:WaitForChild("LevelUpEvent")



------------------------------------------------------------
-- Config
------------------------------------------------------------
local OFFER_COUNT = 3
local CHOICE_TIMEOUT = 10

------------------------------------------------------------
-- Internal state
------------------------------------------------------------
-- [player] = { offers }
local ActiveOffers: { [Player]: { any } } = {}

-- players currently choosing
local PendingLevelUps: { [Player]: boolean } = {}

------------------------------------------------------------
-- Pause helpers (single source of truth)
------------------------------------------------------------
local function setPaused(value: boolean)
	PauseStateManager.Pause()
end

local function tryResumeGame()
	PauseStateManager.Resume()
end

------------------------------------------------------------
-- Boon discovery
------------------------------------------------------------
local function getAllBoons()
	local root = ReplicatedStorage.Combat.Boons
	local list = {}

	for _, godFolder in ipairs(root:GetChildren()) do
		if godFolder:IsA("Folder") then
			for _, module in ipairs(godFolder:GetChildren()) do
				if module:IsA("ModuleScript") then
					table.insert(list, {
						God = godFolder.Name,
						Module = module,
					})
				end
			end
		end
	end

	return list
end

------------------------------------------------------------
-- Active actions on character
------------------------------------------------------------
local function getChosenActions(character: Model): { [string]: boolean }
	local active =
		(BoonService.DebugGetActiveBoons and
			BoonService.DebugGetActiveBoons(character))
		or {}

	local used: { [string]: boolean } = {}
	for action in pairs(active) do
		used[action] = true
	end

	return used
end

------------------------------------------------------------
-- Pom offers
------------------------------------------------------------
local function buildPomOffers(character: Model)
	local active =
		(BoonService.DebugGetActiveBoons and
			BoonService.DebugGetActiveBoons(character))
		or {}

	local offers = {}
	local boonsRoot = ReplicatedStorage.Combat.Boons

	for action, state in pairs(active) do
		local godFolder = boonsRoot:FindFirstChild(state.God)
		if not godFolder then
			continue
		end

		local boonModule = godFolder:FindFirstChild(state.Id)
		if not boonModule then
			continue
		end

		local boon = require(boonModule)
		if not boon.ScaleWithPom then
			continue
		end

		local nextPomLevel = (state.PomLevel or 0) + 1
		local nextData = boon.ScaleWithPom(state.Data, nextPomLevel)

		table.insert(offers, {
			Type = "Pom",
			Action = action,
			Id = state.Id,
			God = state.God,

			BaseData = state.Data,
			NextData = nextData,

			Display = {
				Name = state.Id .. " +1",
				Description = "", -- client fills
			},
		})
	end

	while #offers > OFFER_COUNT do
		table.remove(offers, math.random(#offers))
	end

	return offers
end

------------------------------------------------------------
-- Roll offers (Action-based filtering)
------------------------------------------------------------
local function rollOffers(character: Model)
	local chosenActions = getChosenActions(character)
	local pool = getAllBoons()
	local offers = {}

	-- filter by unused Action
	local filtered = {}
	for _, entry in ipairs(pool) do
		local ok, boon = pcall(require, entry.Module)
		if ok and type(boon) == "table" then
			local action = boon.Action or boon.Slot
			if action and not chosenActions[action] then
				table.insert(filtered, entry)
			end
		end
	end

	-- fallback to Pom
	if #filtered == 0 then
		return buildPomOffers(character)
	end

	while #offers < OFFER_COUNT and #filtered > 0 do
		local index = math.random(1, #filtered)
		local entry = table.remove(filtered, index)

		local boon = require(entry.Module)
		local rarity, data = BoonRarity.Resolve(boon)

		local description =
			boon.Description and boon.Description(data)
			or "No description available."

		table.insert(offers, {
			Type = "Boon",
			God = entry.God,
			Id = boon.Id,
			Action = boon.Action or boon.Slot,
			Rarity = rarity,
			Data = data,

			Display = {
				Name = boon.Id,
				Description = description,
			},
		})
	end

	-- if somehow nothing rolled, Pom again
	if #offers == 0 then
		return buildPomOffers(character)
	end

	return offers
end

------------------------------------------------------------
-- Begin level up
------------------------------------------------------------
local function beginLevelUp(player: Player)
	if ActiveOffers[player] then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local offers = rollOffers(character)

	ActiveOffers[player] = offers
	PendingLevelUps[player] = true

	setPaused(true)
	LevelUpRemote:FireClient(player, offers)

	-- timeout resolution
	task.delay(CHOICE_TIMEOUT, function()
		if not PendingLevelUps[player] then
			return
		end

		local current = ActiveOffers[player]
		if not current then
			return
		end

		local index = math.random(1, #current)
		local picked = current[index]

		ActiveOffers[player] = nil
		PendingLevelUps[player] = nil

		local charNow = player.Character
		if charNow and picked then
			if picked.Type == "Pom" then
				BoonService.ApplyPom(charNow, picked.Action)
			else
				BoonService.ApplyBoon(charNow, picked.God, picked.Id)
			end
		end

		-- tell client to close UI
		LevelUpRemote:FireClient(player, {
			Type = "TimeoutResolved",
			Index = index,
		})

		tryResumeGame()
	end)
end

------------------------------------------------------------
-- Client selection
------------------------------------------------------------
LevelUpRemote.OnServerEvent:Connect(function(player: Player, choiceIndex: number)
	local offers = ActiveOffers[player]
	if not offers then
		return
	end

	local picked = offers[choiceIndex]
	if not picked then
		return
	end

	ActiveOffers[player] = nil
	PendingLevelUps[player] = nil

	local character = player.Character
	if character then
		if picked.Type == "Pom" then
			BoonService.ApplyPom(character, picked.Action)
		else
			BoonService.ApplyBoon(character, picked.God, picked.Id)
		end
	end

	tryResumeGame()
end)

------------------------------------------------------------
-- Hooks / cleanup
------------------------------------------------------------
LevelUpEvent.Event:Connect(beginLevelUp)

Players.PlayerRemoving:Connect(function(player: Player)
	ActiveOffers[player] = nil
	PendingLevelUps[player] = nil
	tryResumeGame()
end)

return {}

--!strict
-- Client/LevelUpClient.lua
-- Renders level-up offers + Pom deltas
-- Observes workspace.IsPaused for visibility
-- Uses existing offerUI container

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

------------------------------------------------------------
-- Dependencies
------------------------------------------------------------
local UIService = require(ReplicatedStorage.UIService)

------------------------------------------------------------
-- Events
------------------------------------------------------------
local Remotes = ReplicatedStorage.RemoteEvents
local LevelUpRemote = Remotes:WaitForChild("LevelUpEvent")

------------------------------------------------------------
-- UI references
------------------------------------------------------------
local gui = player.PlayerGui:WaitForChild("LevelUpGui")
local frame = gui:WaitForChild("PickYourUpgradeFrame")
local layout = frame:WaitForChild("Layout")
local template = layout:WaitForChild("ChoiceTemplate")

local descPanel = frame:WaitForChild("DescriptionPanel")

------------------------------------------------------------
-- Offer UI container
------------------------------------------------------------
local offerUI = UIService.CreateOfferContainer({
	Layout = layout,
	Template = template,
	DescriptionPanel = {
		Title = descPanel:WaitForChild("DescTitle"),
		Body  = descPanel:WaitForChild("DescBody"),
	},
})

------------------------------------------------------------
-- Pause observation
------------------------------------------------------------
workspace:GetAttributeChangedSignal("IsPaused"):Connect(function()
	gui.Enabled = workspace:GetAttribute("IsPaused") == true
end)

------------------------------------------------------------
-- Pom description helpers
------------------------------------------------------------
local function fmtNum(x: any): string
	if typeof(x) == "number" then
		if math.abs(x - math.floor(x)) < 1e-6 then
			return tostring(math.floor(x))
		end
		return string.format("%.1f", x)
	end
	return tostring(x)
end

local function buildPomDescription(baseData: any, nextData: any): string
	if type(baseData) ~= "table" or type(nextData) ~= "table" then
		return "Upgrade this boon."
	end

	local lines = {}

	local function diff(label: string, key: string, isFloat: boolean?)
		local a = baseData[key]
		local b = nextData[key]
		if a == nil or b == nil then
			return
		end
		if a ~= b then
			if isFloat then
				table.insert(lines, string.format("%s: %.1f → %.1f", label, a, b))
			else
				table.insert(lines, string.format("%s: %s → %s", label, fmtNum(a), fmtNum(b)))
			end
		end
	end

	diff("Damage / Stack", "DamagePerStack")
	diff("Max Stacks", "MaxStacks")
	diff("Radius", "Radius", true)

	if #lines == 0 then
		return "Upgrade this boon."
	end

	return "Upgrades:\n" .. table.concat(lines, "\n")
end

------------------------------------------------------------
-- Receive offers / timeout
------------------------------------------------------------
LevelUpRemote.OnClientEvent:Connect(function(payload)
	-- timeout resolution
	if payload.Type == "TimeoutResolved" then
		gui.Enabled = false
		return
	end

	local offers = payload

	-- build Pom display data client-side
	for _, offer in ipairs(offers) do
		if offer.Type == "Pom" then
			offer.Display = {
				Name = offer.Id .. " +1",
				Description = buildPomDescription(
					offer.BaseData,
					offer.NextData
				),
			}
		end
	end

	gui.Enabled = true

	offerUI:Show(offers, function(choiceIndex)
		gui.Enabled = false
		LevelUpRemote:FireServer(choiceIndex)
	end)
end)

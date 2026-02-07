
----- < Variables

local PlayerManager = require(script.Parent)
local Player = PlayerManager.Player
local Data = PlayerManager.Data
local UIHandler = PlayerManager.UIHandler
local PlayerGui = PlayerManager.PlayerGui

local API = PlayerManager.APIs
local Helper = API.helper
local Visuals = API.visuals
local UnitAPI = API.units
local ItemAPI = API.items

local Mouse = Player:GetMouse()


----- < Check if a player is on a PC

if Player:GetAttribute("Device") ~= "PC" then
	script:Destroy()
	return
end


----- < Register Tips

local ToolTips = {}
local ToolTip = nil
local Viewing = nil

local function RegisterToolTip(Name, ToolTip, Function)
	ToolTip.Visible = false
	ToolTip.Parent = PlayerGui.ui_manager
	ToolTips[Name] = {ToolTip = ToolTip, Function = Function}
end


----- < Display

function Show(TipName, Frame)	
	local Properties = ToolTips[TipName]
	if not Properties then return end
	
	local NewTip = Properties.ToolTip
	UIHandler.UpdateMouseOffset(NewTip, UDim2.new(0,0,0,0), true)
	
	if Viewing ~= Frame then
		if ToolTip ~= nil then ToolTip.Visible = false end
		ToolTip = NewTip
		Viewing = Frame
		Properties.Function(Frame)
		NewTip.Visible = true
	end
end

function Hide()
	if ToolTip then 
		ToolTip.Visible = false
		ToolTip = nil
		Viewing = nil
	end
end


----- < Run Tips

Helper.heartbeat(function()	
	for _, Frame in pairs(PlayerGui:GetGuiObjectsAtPosition(Mouse.X, Mouse.Y)) do
		local TipName = Frame:GetAttribute("ToolTip")
		if not TipName or not ToolTips[TipName] then continue end
		Show(TipName, Frame)
		return
	end
	
	Hide()
end)


----- < Register Unit

RegisterToolTip("Unit", script.Unit, function(Frame)	
	local Unit = Frame:GetAttribute("Unit");
	if not Unit then return end
	
	local UnitInfo = UnitAPI.Units[Unit]
	if not UnitInfo then return end
		
	local UUID = Frame:GetAttribute("UUID")
	local Health, Damage;
	
	if UUID and Data.Units[UUID] then
		Health, Damage = UnitAPI.Stats(Data.Units[UUID])
	else
		Health, Damage = UnitAPI.Stats({
			Unit = Unit, 
			Level = Frame:GetAttribute("Level"),
			Shiny = Frame:GetAttribute("Shiny"),
		})
	end

	ToolTip.Info.Unit.Text = UnitInfo.DisplayName or Unit
	ToolTip.Info.Tier.Text = UnitInfo.Rarity
	ToolTip.Stats.Damage.Text.Text = Helper.abbreviate(Damage, "K")
	ToolTip.Stats.Health.Text.Text = Helper.abbreviate(Health, "K")
	
	if UnitInfo.Passive then
		ToolTip.Passive.Visible = true
		ToolTip.Passive.Description.Text = UnitInfo.Passive.Description
	else
		ToolTip.Passive.Visible = false
	end
	
	Visuals.EquipRarity(ToolTip.Info.Tier, UnitInfo.Rarity)
	Visuals.EquipRarity(ToolTip.UIStroke, UnitInfo.Rarity)
end)


----- < Register Item

RegisterToolTip("Item", script.Item, function(Frame)
	local ItemId = Frame:GetAttribute("ItemId");
	local Item = ItemAPI.Items[ItemId] or ItemAPI.Currencies[ItemId]
	if not Item then return end
	
	ToolTip.Info.Item.Text = ItemId
	ToolTip.Info.Tier.Text = Item.Rarity
	ToolTip.Description.Text = ItemAPI.Description(ItemId)
	ToolTip.Amount.Text.Text = "Owned: " .. Helper.abbreviate(Data.Items[ItemId] or 0) .. "x"

	Visuals.EquipRarity(ToolTip.Info.Tier, Item.Rarity)
	Visuals.EquipRarity(ToolTip.UIStroke, Item.Rarity)
end)

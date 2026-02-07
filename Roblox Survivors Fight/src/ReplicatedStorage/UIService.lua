--!strict
-- UIService.lua
-- Generic pooled offer list renderer with hover/preview/selection

local UserInputService = game:GetService("UserInputService")

local UIService = {}

------------------------------------------------------------
-- Internal helpers
------------------------------------------------------------
local function disconnectAll(conns)
	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)
end

local function getButton(root: Instance): TextButton
	if root:IsA("TextButton") then
		return root
	end
	local btn = root:FindFirstChild("Button", true)
	assert(btn and btn:IsA("TextButton"), "Template must be TextButton or contain Button")
	return btn
end

------------------------------------------------------------
-- Create an Offer Container
------------------------------------------------------------
-- config = {
--   Layout: Frame,
--   Template: Instance (Visible=false),
--   DescriptionPanel = {
--      Title: TextLabel,
--      Body: TextLabel,
--   },
--   RarityColors = { [string]: Color3 },
-- }
--
-- returns controller with:
--   :Show(offers, onSelect)
--   :Clear()
------------------------------------------------------------
function UIService.CreateOfferContainer(config)
	assert(config.Layout, "Layout required")
	assert(config.Template, "Template required")

	local layout = config.Layout
	local template = config.Template
	local descPanel = config.DescriptionPanel
	local rarityColors = config.RarityColors or {}

	local pool = {}
	local active = {}
	local conns = {}

	template.Visible = false

	local function setDescription(title, body)
		if not descPanel then return end
		descPanel.Title.Text = title or ""
		descPanel.Body.Text = body or ""
	end

	local function clear()
		disconnectAll(conns)
		for _, inst in ipairs(active) do
			inst.Parent = nil
			table.insert(pool, inst)
		end
		table.clear(active)
	end

	local function getCard()
		local inst = table.remove(pool)
		if inst then
			return inst
		end
		return template:Clone()
	end

	local controller = {}

	function controller:Show(offers, onSelect)
		clear()
		setDescription("Select An Upgrade", "")

		for index, offer in ipairs(offers) do
			local card = getCard()
			table.insert(active, card)

			card.Name = "Offer_" .. index
			card.Parent = layout
			card.Visible = true

			-- Title
			local title = card:FindFirstChild("Title", true)
			if title and title:IsA("TextLabel") then
				title.Text = offer.Display and offer.Display.Name or offer.Id or "Unknown"
			end

			-- Rarity label
			local rarityLabel = card:FindFirstChild("Rarity", true)
			if rarityLabel and rarityLabel:IsA("TextLabel") then
				rarityLabel.Text = offer.Rarity or ""
			end

			-- Stroke / color
			local stroke = card:FindFirstChildWhichIsA("UIStroke", true)
			if stroke and offer.Rarity then
				stroke.Color = rarityColors[offer.Rarity] or Color3.new(1,1,1)
			end

			-- Cache description
			card:SetAttribute("DescTitle", offer.Display and offer.Display.Name or offer.Id)
			card:SetAttribute("DescBody", offer.Display and offer.Display.Description or "")

			local btn = getButton(card)

			-- Hover preview (mouse/controller)
			table.insert(conns, btn.MouseEnter:Connect(function()
				setDescription(
					card:GetAttribute("DescTitle"),
					card:GetAttribute("DescBody")
				)
			end))

			-- Selection (touch-safe)
			local previewed = false
			table.insert(conns, btn.Activated:Connect(function()
				if UserInputService.TouchEnabled and not previewed then
					previewed = true
					setDescription(
						card:GetAttribute("DescTitle"),
						card:GetAttribute("DescBody")
					)
					return
				end

				clear()
				onSelect(index)
			end))
		end

		-- Default preview
		local first = active[1]
		if first then
			setDescription(
				first:GetAttribute("DescTitle"),
				first:GetAttribute("DescBody")
			)
		end
	end

	function controller:Clear()
		clear()
	end

	return controller
end

return UIService

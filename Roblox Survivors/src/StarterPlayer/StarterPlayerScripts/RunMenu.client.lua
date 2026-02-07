-- RunMenu.client.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-------------------------------------------------
-- Remotes
-------------------------------------------------
local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local openMenuEvent = remotes:WaitForChild("OpenRunMenu")
local closeMenuEvent = remotes:WaitForChild("CloseRunMenu")
local requestStartRun = remotes:WaitForChild("RequestStartRun")
local getUnlockedWeapons = remotes:WaitForChild("GetUnlockedWeapons")
-------------------------------------------------
-- Data
-------------------------------------------------
local WeaponsFolder = ReplicatedStorage
	:WaitForChild("Data")
	:WaitForChild("Weapons")

-------------------------------------------------
-- GUI Template
-------------------------------------------------
local guiTemplate = ReplicatedStorage.PlayerGui:WaitForChild("RunMenuGui")
local gui

-------------------------------------------------
-- Local State
-------------------------------------------------
local selectedWeapon: string? = nil
local selectedMode: string = "Solo"

-------------------------------------------------
-- Visual Helpers
-------------------------------------------------
local function setSelected(button: TextButton, selected: boolean)
	button.BackgroundTransparency = selected and 0 or 0.35
	button.BorderSizePixel = selected and 2 or 0
end

-------------------------------------------------
-- Weapon Grid Population (Dynamic)
-------------------------------------------------
local function populateWeaponGrid(mainFrame: Frame)
	local grid = mainFrame.WeaponSection.WeaponGrid
	local template = grid:WaitForChild("WeaponTemplate")
	-- Fetch unlock data ONCE per open
	local unlockedWeapons = getUnlockedWeapons:InvokeServer()
	-- Cleanup
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("TextButton") and child ~= template then
			child:Destroy()
		end
	end
	for _, weaponFolder in ipairs(WeaponsFolder:GetChildren()) do
		if not weaponFolder:IsA("Folder") then continue end

		local weaponName = weaponFolder.Name
		local unlocked = unlockedWeapons[weaponName] == true

		local button = template:Clone()
		button.Name = "Weapon_" .. weaponName
		button.Text = weaponName
		button.Visible = true
		button.Parent = grid
		button:SetAttribute("WeaponName", weaponName)

		if not unlocked then
			-- 🔒 LOCKED STATE
			button.Text = weaponName .. "\nLOCKED"
			button.TextTransparency = 0.45
			button.BackgroundTransparency = 0.65
			button.AutoButtonColor = false
			continue
		end
		-- ✅ UNLOCKED
		button.BackgroundTransparency = 0.35
		button.BorderSizePixel = 0

		button.MouseButton1Click:Connect(function()
			selectedWeapon = weaponName

			for _, other in ipairs(grid:GetChildren()) do
				if other:IsA("TextButton") then
					setSelected(other, other == button)
				end
			end
		end)
	end
end

-------------------------------------------------
-- GUI Construction
-------------------------------------------------
local function buildGui()
	gui = guiTemplate:Clone()
	gui.Parent = player:WaitForChild("PlayerGui")

	local main = gui.MainFrame

	-------------------------------------------------
	-- Populate weapons
	-------------------------------------------------
	populateWeaponGrid(main)

	-------------------------------------------------
	-- Mode Buttons
	-------------------------------------------------
	local soloButton = main.ModeSection.SoloButton
	local multiButton = main.ModeSection.MultiButton
	setSelected(soloButton, true)
	setSelected(multiButton, false)

	soloButton.MouseButton1Click:Connect(function()
		selectedMode = "Solo"
		setSelected(soloButton, true)
		setSelected(multiButton, false)
	end)

	-- Multiplayer disabled for now
	multiButton.AutoButtonColor = false
	multiButton.BackgroundTransparency = 0.6

	-------------------------------------------------
	-- Start Run
	-------------------------------------------------
	main.StartRunButton.MouseButton1Click:Connect(function()
		if not selectedWeapon then
			warn("RunMenu: No weapon selected")
			return
		end
		main.StartRunButton.Text = "STARTING..."
		main.StartRunButton.AutoButtonColor = false

		requestStartRun:FireServer({
			Weapon = selectedWeapon,
			Mode = selectedMode,
		})
	end)
end

-------------------------------------------------
-- Open Menu
-------------------------------------------------
openMenuEvent.OnClientEvent:Connect(function()
	--print("[RunMenu] OpenRunMenu received")
	--print("[RunMenu] gui =", gui)

	if not gui then
		--print("[RunMenu] Calling buildGui()")
		buildGui()
	else
		--print("[RunMenu] buildGui skipped (gui already exists)")
	end

	if gui then
		gui.Enabled = true
	else
		warn("[RunMenu] gui is still nil after buildGui")
	end
end)

closeMenuEvent.OnClientEvent:Connect(function()
	if gui then
		gui.Enabled = false
	end
end)
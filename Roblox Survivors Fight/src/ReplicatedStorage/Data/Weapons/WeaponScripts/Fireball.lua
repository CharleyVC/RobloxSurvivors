-- ReplicatedStorage/Data/Weapons/WeaponScripts/Fireball.lua
local Fireball = {}

local AnimationHandler = require(game.ReplicatedStorage:WaitForChild("AnimationHandler"))

function Fireball.OnEquip(player, character, weapon)
	-- Visual parts inside the tool
	local LeftOrb = weapon:WaitForChild("FireL")
	local RightOrb = weapon:WaitForChild("FireR")

	local WeldL = nil
	local WeldR = nil

	-- R15 attachment names
	local LEFT_ATTACH = "LeftGripAttachment"
	local RIGHT_ATTACH = "RightGripAttachment"

	local function attachOrb(orb, limb, attachmentName)
		if not orb or not limb then return end

		local attach = limb:FindFirstChild(attachmentName)
		if not attach then return end

		-- Position orb BEFORE welding
		orb.CFrame = attach.WorldCFrame

		-- Parent orb under character (stable location)
		orb.Parent = character

		-- Create weld AFTER it is positioned
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = orb
		weld.Part1 = limb
		weld.Parent = orb

		-- Disable physics issues
		orb.CanCollide = false
		orb.Massless = true
		orb.Anchored = false

		return weld
	end

	local function onEquipped()
		if not character:FindFirstChild("Humanoid") then return end

		local leftHand = character:FindFirstChild("LeftHand")
		local rightHand = character:FindFirstChild("RightHand")

		-- Attach left orb
		if leftHand then
			WeldL = attachOrb(LeftOrb, leftHand, LEFT_ATTACH)
		end

		-- Attach right orb
		if rightHand then
			WeldR = attachOrb(RightOrb, rightHand, RIGHT_ATTACH)
		end
	end

	-- Load animations
	AnimationHandler.loadAnimations(character, "Weapon", weapon.Name)

--	print("[Fireball] Successfully attached.")
end

return Fireball

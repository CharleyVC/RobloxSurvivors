--!strict
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileManager = require(ServerScriptService.Scripts:WaitForChild("ProfileManager"))

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local requestStartRun = remotes:WaitForChild("RequestStartRun") -- RemoteEvent
local getUnlockedWeapons = remotes:WaitForChild("GetUnlockedWeapons") -- RemoteFunction
local teleportingEvent = remotes:FindFirstChild("Teleporting") -- optional RemoteEvent

local MAIN_GAME_PLACE_ID = 96539679830573

local SessionService = {}

local function ensureTables(profileData: any)
	profileData.SessionLockouts = profileData.SessionLockouts or {}
	-- profileData.ActiveRun can remain nil
end

local function isWeaponUnlocked(profileData: any, weapon: string): boolean
	return (profileData.UnlockedWeapons and profileData.UnlockedWeapons[weapon]) == true
end

local function isLockedOut(profileData: any, sessionId: string): boolean
	return profileData.SessionLockouts and profileData.SessionLockouts[sessionId] == true
end

requestStartRun.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) ~= "table" then return end
	if typeof(payload.Weapon) ~= "string" then return end

	local profile = ProfileManager.GetProfile(player)
	if not profile or not profile.Data then
		player:Kick("Profile not loaded")
		return
	end

	local data = profile.Data
	ensureTables(data)

	local weapon = payload.Weapon
	if not isWeaponUnlocked(data, weapon) then
		warn(("[SessionService] %s attempted locked weapon: %s"):format(player.Name, weapon))
		return
	end

	-- Create a new run session
	local sessionId = HttpService:GenerateGUID(false)
	local accessCode: string
	do
		local ok, res = pcall(function()
			return TeleportService:ReserveServer(MAIN_GAME_PLACE_ID)
		end)
		if not ok then
			warn("[SessionService] ReserveServer failed:", res)
			return
		end
		accessCode = res
	end

	-- Persist equipped weapon + active run info
	data.EquippedWeapon = weapon
	data.ActiveRun = {
		SessionId = sessionId,
		AccessCode = accessCode,
		PlaceId = MAIN_GAME_PLACE_ID,
		StartedAt = os.time(),
		CanRejoin = true, -- future-proof; main game can flip/clear on final death
	}

	-- (Optional sanity) if somehow already locked out of this id (shouldn't happen since new GUID)
	if isLockedOut(data, sessionId) then
		warn("[SessionService] Unexpected lockout for new sessionId, clearing")
		data.SessionLockouts[sessionId] = nil
	end

	profile:Save()

	-- Teleport with ReservedServerAccessCode + TeleportData
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		SessionId = sessionId,
		EquippedWeapon = weapon,
	})

	if teleportingEvent then
		teleportingEvent:FireClient(player)
	end

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(MAIN_GAME_PLACE_ID, { player }, options)
	end)
	if not ok then
		warn("[SessionService] TeleportAsync failed:", err)
		-- If teleport fails, clear ActiveRun so lobby doesn't think they're mid-run
		data.ActiveRun = nil
		profile:Save()
	end
end)

-- RemoteFunction: client pulls unlocked weapon list to render locks
getUnlockedWeapons.OnServerInvoke = function(player)
	local profile = ProfileManager.GetProfile(player)
	if not profile or not profile.Data then
		return {}
	end

	local unlocked: {[string]: boolean} = {}
	for weaponName, isUnlocked in pairs(profile.Data.UnlockedWeapons or {}) do
		if isUnlocked == true then
			unlocked[weaponName] = true
		end
	end
	return unlocked
end

return SessionService

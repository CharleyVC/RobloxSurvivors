local VFXModule = {}

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local vfxLibrary = require(
	game.ReplicatedStorage.Data.VFXTemplates:WaitForChild("VFXLibrary")
)

local vfxTemplates = game.ReplicatedStorage.Data
	:WaitForChild("VFXTemplates")
	:GetChildren()

local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")

----------------------------------------------------
-- CACHE TEMPLATES
----------------------------------------------------
local VFX_CACHE = {}
for _, v in ipairs(vfxTemplates) do
	VFX_CACHE[v.Name] = v
end

----------------------------------------------------
-- DEEP COPY (CRITICAL FIX)
----------------------------------------------------
local function deepCopy(tbl)
	local copy = {}
	for k, v in pairs(tbl) do
		if typeof(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

----------------------------------------------------
-- MERGE UTIL (unchanged)
----------------------------------------------------
local function mergeTables(defaultData, specialProperties)
	for key, value in pairs(specialProperties) do
		if typeof(value) == "table" and typeof(defaultData[key]) == "table" then
			mergeTables(defaultData[key], value)
		else
			defaultData[key] = value
		end
	end
	return defaultData
end

----------------------------------------------------
-- INTERPOLATION HELPERS (unchanged)
----------------------------------------------------
local function interpolateProperty(effect, property, v1, v2, alpha)
	if typeof(v1) == "number" then
		effect[property] = v1 + (v2 - v1) * alpha
	elseif typeof(v1) == "Vector3" then
		effect[property] = v1:Lerp(v2, alpha)
	elseif typeof(v1) == "Color3" then
		effect[property] = v1:Lerp(v2, alpha)
	elseif typeof(v1) == "NumberRange" then
		effect[property] = NumberRange.new(
			v1.Min + (v2.Min - v1.Min) * alpha,
			v1.Max + (v2.Max - v1.Max) * alpha
		)
	elseif typeof(v1) == "UDim2" then
		effect[property] = UDim2.new(
			v1.X.Scale + (v2.X.Scale - v1.X.Scale) * alpha,
			v1.X.Offset + (v2.X.Offset - v1.X.Offset) * alpha,
			v1.Y.Scale + (v2.Y.Scale - v1.Y.Scale) * alpha,
			v1.Y.Offset + (v2.Y.Offset - v1.Y.Offset) * alpha
		)
	end
end

local function handleComponentProperties(effect, componentData, elapsedTime, duration, lerpFraction)
	if not componentData then return end -- Skip if the component is nil

	local componentInstance
	local attachment = componentData.Attachment
	local name = componentData.Name
	
	
	if name == effect.Name then
		componentInstance = effect
	elseif attachment == false then
		componentInstance = effect[name]
	else
		componentInstance = effect[attachment][name]
	end
	-- Ensure the component instance exists
	if not componentInstance then
		warn("Component instance not found for:", name)
		return
	end

	-- Handle properties for the component
	for property, values in pairs(componentData) do
		if property == "Stage" or property == "Attachment" or not values then
			-- Skip irrelevant properties
			continue
		end
		if typeof(values) == "table" and #values == 2 then
			local stage = componentData.Stage or "Both"
			local alpha = math.clamp((elapsedTime / duration) * lerpFraction, 0, 1)
		

			if stage == "Begin" and elapsedTime <= duration / lerpFraction then
				interpolateProperty(componentInstance, property, values[1], values[2], alpha)
			elseif stage == "End" and elapsedTime >= duration * (5 / 6) then
				local fadeAlpha = math.clamp((elapsedTime - (duration * (5 / 6))) / (duration / 6), 0, 1)
				interpolateProperty(componentInstance, property, values[1], values[2], fadeAlpha)
			elseif stage == "Both" then
				interpolateProperty(componentInstance, property, values[1], values[2], alpha)
			elseif stage == "Reverse" then
				if elapsedTime <= duration / 3 then
					local forwardAlpha = math.clamp(elapsedTime / (duration / 3), 0, 1)
					interpolateProperty(componentInstance, property, values[1], values[2], forwardAlpha)
				elseif elapsedTime >= duration * (2 / 3) then
					local reverseAlpha = math.clamp((elapsedTime - (duration * (2 / 3))) / (duration / 3), 0, 1)
					interpolateProperty(componentInstance, property, values[2], values[1], reverseAlpha)
				end
			end
		else
			if typeof(values) == "NumberSequence" then
				componentInstance[property] = values -- Assign NumberSequence
			else
				componentInstance[property] = values -- Assign static properties
			end
		end
	end
end

----------------------------------------------------
-- RENDER
----------------------------------------------------
function VFXModule.render(effect, vfxData)
	local fx = vfxData.Fx
	local duration = fx.Duration or 1
	local lerpFraction = fx.LerpFraction or 1
	local startTime = os.clock()
	effect.Parent = workspace.VFX
	effect.CollisionGroup = "InvisibleObjects"
	local baseCf = fx.CFrame or CFrame.new()
	local offset = fx.Offset or Vector3.zero

	-- Multiply the base CFrame by a new CFrame created from the offset vector
	effect.CFrame = baseCf * CFrame.new(offset)

	local conn
	conn = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		handleComponentProperties(effect, vfxData.Part, elapsed, duration, lerpFraction)
		handleComponentProperties(effect, vfxData.PointLight, elapsed, duration, lerpFraction)
		
		-- 2. Dynamically handle all keys that contain "Emiter"
		for key, data in pairs(vfxData) do
			
			-- This checks if the key string contains "Emiter" (handles Emiter, Emiter2, FireEmiter, etc.)
			if typeof(key) == "string" and string.find(key, "Emit") and typeof(data) == "table" then
				handleComponentProperties(effect, data, elapsed, duration, lerpFraction)
			end
		end

		if elapsed >= duration then
			Debris:AddItem(effect, 0.5)
			conn:Disconnect()
		end
	end)
end

----------------------------------------------------
-- PLAY (FIXED)
----------------------------------------------------
function VFXModule.play(effectName, Cf, specialProperties)
	local template = VFX_CACHE[effectName]
	if not template then
		warn("VFX template not found:", effectName)
		return
	end

	local rawData = vfxLibrary.getAbility(effectName)
	if not rawData then
		warn("VFX data not found:", effectName)
		return
	end

	-- 🔒 CRITICAL: deep copy per play call
	local vfxData = deepCopy(rawData)

		--for _, data in pairs(vfxData) do
		--	data.Fx.CFrame = Cf
		--	if specialProperties then
		--		mergeTables(data, specialProperties)
		--	end
		--end

	for stepName, stepData in pairs(vfxData) do
		if typeof(stepData) == "table" then
			-- 1. Merge special overrides FIRST (Radius, Duration, etc.)
			if specialProperties then
				mergeTables(stepData, specialProperties)
			end

			-- 2. NOW apply the Position/CFrame (this ensures it sticks)
			stepData.Fx = stepData.Fx or {}
			stepData.Fx.CFrame = Cf
			-- 3. Render
			if stepData.Render then
				local effectInstance = template:Clone()
				VFXModule.render(effectInstance, stepData)
			end
		end
	end
end

----------------------------------------------------
-- HIT NPC HIGHLIGHT (unchanged)
----------------------------------------------------
local HIT_COOLDOWN = 0.3
local hitCooldowns = {}

function VFXModule.playHitNPC(npcModel)
	if not npcModel then return end

	local now = os.clock()
	if hitCooldowns[npcModel] and now - hitCooldowns[npcModel] < HIT_COOLDOWN then
		return
	end
	hitCooldowns[npcModel] = now

	local highlight = npcModel:FindFirstChild("HitHighlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "HitHighlight"
		highlight.FillColor = Color3.new(1,1,1)
		highlight.Adornee = npcModel
		highlight.Parent = npcModel
	end

	highlight.Enabled = true

	TweenService:Create(
		highlight,
		TweenInfo.new(0.75),
		{ FillTransparency = 1, OutlineTransparency = 1 }
	):Play()
end

return VFXModule

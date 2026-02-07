-- ReplicatedStorage/Controllers/Input/KeyboardMouseInput.lua

local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local KM = {
	Enabled = false,

	OnPrimaryBegin = function() end,
	OnPrimaryEnd   = function() end,

	OnSecondaryBegin = function() end,
	OnSecondaryEnd   = function() end,

	OnSprintBegin = function() end,
	OnSprintEnd   = function() end,

	OnDash = function() end,
}

KM._conns = {}

KM._primaryDown = false
KM._secondaryDown = false

------------------------------------------------------------
-- ENABLE
------------------------------------------------------------
function KM:Enable()
	if self.Enabled then return end
	self.Enabled = true

	--------------------------------------------------------
	-- INPUT BEGAN
	--------------------------------------------------------
	self._conns.inputBegan = UIS.InputBegan:Connect(function(input, gp)

		-- PRIMARY (Mouse 1)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if not self._primaryDown then
				self._primaryDown = true
				self.OnPrimaryBegin()
			end
			return
		end

		-- SECONDARY (Mouse 2)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if not self._secondaryDown then
				self._secondaryDown = true
				self.OnSecondaryBegin()
			end
			return
		end

		-- SPRINT
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.OnSprintBegin()
			return
		end

		-- DASH
		if input.KeyCode == Enum.KeyCode.Space then
			self.OnDash()
			return
		end
	end)

	--------------------------------------------------------
	-- INPUT ENDED (best effort, not trusted alone)
	--------------------------------------------------------
	self._conns.inputEnded = UIS.InputEnded:Connect(function(input)
		-- PRIMARY
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self._primaryDown then
				self._primaryDown = false
				self.OnPrimaryEnd()
			end
			return
		end

		-- SECONDARY
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self._secondaryDown then
				self._secondaryDown = false
				self.OnSecondaryEnd()
			end
			return
		end

		-- SPRINT
		if input.KeyCode == Enum.KeyCode.LeftShift then
			self.OnSprintEnd()
			return
		end
	end)

	--------------------------------------------------------
	-- PHYSICAL STATE VERIFIER (AUTHORITATIVE RELEASE)
	--------------------------------------------------------
	self._conns.mouseVerifier = RunService.Heartbeat:Connect(function()
		-- PRIMARY SAFETY
		if self._primaryDown
			and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			self._primaryDown = false
			self.OnPrimaryEnd()
		end

		-- SECONDARY SAFETY
		if self._secondaryDown
			and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			self._secondaryDown = false
			self.OnSecondaryEnd()
		end
	end)

	--------------------------------------------------------
	-- FOCUS SAFETY (ALT-TAB, MENU, ETC)
	--------------------------------------------------------
	self._conns.focusLost = UIS.WindowFocusReleased:Connect(function()
		if self._primaryDown then
			self._primaryDown = false
			self.OnPrimaryEnd()
		end

		if self._secondaryDown then
			self._secondaryDown = false
			self.OnSecondaryEnd()
		end

		self.OnSprintEnd()
	end)
end

------------------------------------------------------------
-- DISABLE
------------------------------------------------------------
function KM:Disable()
	if not self.Enabled then return end
	self.Enabled = false

	for _, conn in pairs(self._conns) do
		if conn then
			conn:Disconnect()
		end
	end

	self._conns = {}
	self._primaryDown = false
	self._secondaryDown = false
end

return KM

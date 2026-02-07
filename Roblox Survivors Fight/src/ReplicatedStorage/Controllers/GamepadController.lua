-- ReplicatedStorage/Controllers/GamepadController.lua

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GamepadController = {
	Enabled = false,
	Deadzone = 0.15,

	OnMove = function() end,
	OnPrimaryBegin = function() end,
	OnPrimaryEnd = function() end,
	OnSecondaryBegin = function() end,
	OnSecondaryEnd = function() end,
	OnDash = function() end,
}

GamepadController._conns = {}
GamepadController._primaryDown = false
GamepadController._secondaryDown = false

GamepadController.Mapping = {
	Primary = Enum.KeyCode.ButtonX,
	Secondary = Enum.KeyCode.ButtonY,
	Dash = Enum.KeyCode.ButtonB,
}

local function stickToWorld(vec2: Vector2): Vector3
	local cam = Workspace.CurrentCamera
	if not cam then
		return Vector3.new(vec2.X, 0, -vec2.Y)
	end

	local forward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)

	if forward.Magnitude <= 0 then
		forward = Vector3.new(0, 0, -1)
	end

	forward = forward.Unit
	right = right.Unit

	local dir = (right * vec2.X) + (forward * -vec2.Y)
	if dir.Magnitude <= 0 then
		return Vector3.zero
	end

	return dir.Unit
end

local function isGamepad1(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Gamepad1
end

function GamepadController:Enable()
	if self.Enabled then return end
	self.Enabled = true

	self._conns.inputChanged = UserInputService.InputChanged:Connect(function(input)
		if not isGamepad1(input) then return end
		if input.KeyCode ~= Enum.KeyCode.Thumbstick1 then return end

		local vec2 = Vector2.new(input.Position.X, input.Position.Y)
		if vec2.Magnitude < self.Deadzone then
			self.OnMove(Vector3.zero)
			return
		end

		self.OnMove(stickToWorld(vec2))
	end)

	self._conns.inputBegan = UserInputService.InputBegan:Connect(function(input, gp)
		if not isGamepad1(input) then return end

		if input.KeyCode == self.Mapping.Primary then
			if not self._primaryDown then
				self._primaryDown = true
				self.OnPrimaryBegin()
			end
		elseif input.KeyCode == self.Mapping.Secondary then
			if not self._secondaryDown then
				self._secondaryDown = true
				self.OnSecondaryBegin()
			end
		elseif input.KeyCode == self.Mapping.Dash then
			self.OnDash()
		end
	end)

	self._conns.inputEnded = UserInputService.InputEnded:Connect(function(input)
		if not isGamepad1(input) then return end

		if input.KeyCode == self.Mapping.Primary then
			if self._primaryDown then
				self._primaryDown = false
				self.OnPrimaryEnd()
			end
		elseif input.KeyCode == self.Mapping.Secondary then
			if self._secondaryDown then
				self._secondaryDown = false
				self.OnSecondaryEnd()
			end
		end
	end)
end

function GamepadController:Disable()
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

return GamepadController

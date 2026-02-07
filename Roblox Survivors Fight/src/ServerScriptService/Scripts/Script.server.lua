local module = {}


-----< Variables

local RunService = game:GetService("RunService")
local RemoteEvent = script:WaitForChild("RemoteEvent")
local RemoteFunction = script:WaitForChild("RemoteFunction")


-----< Register

local Remotes = {}
local Binds = {}

function module.Register(Name, Callback)
	if not Remotes[Name] then
		Remotes[Name] = {}
	end

	table.insert(Remotes[Name], Callback)
end

function module.Bind(Name, Callback)
	if not Binds[Name] then
		Binds[Name] = {}
	end

	table.insert(Binds[Name], Callback)
end


-----< Send

function module.SendClient(Name, Player, ...)
	if RunService:IsServer() then
		RemoteEvent:FireClient(Player, Name, ...)
	end
end

function module.SendServer(Name, ...)
	if RunService:IsClient() then
		RemoteEvent:FireServer(Name, ...)
	end
end

function module.SendAll(Name, ...)
	if RunService:IsServer() then
		RemoteEvent:FireAllClients(Name, ...)
	end
end

function module.SendEvent(Name, ...)
	local Callbacks = Binds[Name]
	if not Callbacks then return end

	for _, Callback in ipairs(Callbacks) do
		task.spawn(Callback, ...)
	end
end

-----< Get

function module.GetFromServer(Name, ...)
	if RunService:IsClient() then
		local Args = table.pack(...)
		local Results
		local Success, Message = pcall(function()
			Results = { RemoteFunction:InvokeServer(Name, table.unpack(Args)) }
		end)

		if Success then
			return table.unpack(Results)
		end
	end
end

function module.GetFromClient(Name, Player, ...)
	if RunService:IsServer() and Player then
		local Data = ...
		local Success, Result = pcall(function()
			return RemoteFunction:InvokeClient(Player, Name, Data)
		end)

		if Success then
			return Result
		end
	end
end


-----< Listener

local function Dispatch(Name, Player, ...)
	local Callbacks = Remotes[Name]
	if not Callbacks then return end
	for _, Callback in ipairs(Callbacks) do
		if Player then
			task.spawn(Callback, Player, ...)
		else
			task.spawn(Callback, ...)
		end
	end
end

if RunService:IsClient() then
	RemoteEvent.OnClientEvent:Connect(function(Name, ...)
		Dispatch(Name, nil, ...)
	end)

	RemoteFunction.OnClientInvoke = function(Name, ...)
		if not Remotes[Name] then return end
		return Remotes[Name][1](...)
	end
else
	RemoteEvent.OnServerEvent:Connect(function(Player, Name, ...)
		Dispatch(Name, Player, ...)
		--module.SendEvent("debug_log", Player, Name, ...)
	end)

	RemoteFunction.OnServerInvoke = function(Player, Name, ...)
		if not Remotes[Name] then return end
		return Remotes[Name][1](Player, ...)
	end
end

return module
				
local VFXModule = require(game.ReplicatedStorage:WaitForChild("VFXModule"))
local vfxEvent = game.ReplicatedStorage.RemoteEvents:WaitForChild("VFXEvent")
local GroundResolver = require(	game.ReplicatedStorage:WaitForChild("GroundResolver"))

vfxEvent.OnClientEvent:Connect(function(effectName, ...)
	if effectName == "HitNPC" then
		local npcModel = select(1, ...)
		if npcModel and npcModel:IsA("Model") then
			VFXModule.playHitNPC(npcModel)
		else
			warn("[VFX] HitNPC received invalid model:", npcModel)
		end
	elseif effectName == "AoeVFX" then
		local ground, radius, duration = ...
		local pos = ground.Position
		local posNormal = ground.Normal
		local cf = GroundResolver.buildAlignedCFrame(pos, posNormal)
		cf = cf * CFrame.new(0, 1, 0) -- lift
		local parameters = {
			Part = {
				Size = {
					Vector3.new(0.1, 1, 1),
					Vector3.new(0.1, radius * 2, radius * 2),
				},
			},
			Fx = { Duration = duration },
		}
		VFXModule.play("AoeVFX", cf * CFrame.Angles(0, 0, math.rad(90)), parameters)
		
		
		
		
	elseif effectName == "SpawnVFX" then
		local modelPosition = ...
		if typeof(modelPosition) ~= "CFrame" then
			modelPosition = GroundResolver.resolve(modelPosition)
		end
		local pos = modelPosition.Position
		local posNormal = modelPosition.Normal
		local cf = GroundResolver.buildAlignedCFrame(pos, posNormal)
		cf = cf * CFrame.new(0, 0, 0) -- lift
		VFXModule.play("SpawnVFX", cf)
	elseif effectName == "ProjectileImpact" then
		local hitPos, hitNormal, weaponName, baseAction, hitType = ...
		if typeof(hitPos) ~= "Vector3" then
			return
		end

		if hitType == "Ground" then
			local ground = GroundResolver.resolve(hitPos)
			local cf = GroundResolver.buildAlignedCFrame(ground.Position, ground.Normal)
			VFXModule.play("SpawnVFX", cf)
		elseif hitType == "Air" then
			local cf = CFrame.new(hitPos)
			VFXModule.play("SpawnVFX", cf)
		end
		
		
		
		
	elseif effectName == "RingVFX" then
		
		local ground, radius, duration, color= ...
		if typeof(ground) ~= "CFrame" then
			ground = GroundResolver.resolve(ground)
		end
		
		
		local pos = ground.Position
		local posNormal = ground.Normal
		local cf = GroundResolver.buildAlignedCFrame(pos, posNormal)
		cf = cf * CFrame.new(0, 1, 0) -- lift
		local parameters = {
			--Part = {
				--Size = {
				--	Vector3.new(0.1, 1, 1),
				--	Vector3.new(0.1, radius * 2, radius * 2),
				--},
			--},
			Fx = { Duration = duration },
			Emiter = {Color = ColorSequence.new(color)},
			Emiter2 = {Color = ColorSequence.new(color)}
		}
		
		
		VFXModule.play("RingVFX", cf * CFrame.Angles(0, 0, math.rad(90)), parameters)
	
	end
end)

local VFXLibrary = {}
--Three prefixes to consider, Fx = entire object effect, Part = part, Emiter = Emiter. Use these three when customizing properties.



-- Properties for all abilities
VFXLibrary.Fx = {
	RingVFX = {
		Step1 = {
			Render = true,
			Emit = true,
			Part = {Name = "RingVFX", Attachment = false, Size = Vector3.new(0.1,1,1), Transparency = 1},
			Fx = {Duration = 1, Offset = Vector3.new(0,0,0), LerpFraction = 1},
			Emiter = {Name = "CircleWave", Attachment = "Attachment", Color = {ColorSequence.new(Color3.new(0.905882, 0.298039, 0.235294))}},
			Emiter2 = {Name = "Gradient", Attachment = "Attachment", Color = {ColorSequence.new(Color3.new(0.905882, 0.298039, 0.235294))}},
			PointLight = {Name = "PointLight", Attachment = "Attachment", Range = {8, 2} , Stage = "End"}},},
	
	SpawnVFX = {
		Step1 = {
			Render = true,
			Emit = false,
			Part = {Name = "SpawnVFX", Attachment = false, Size = Vector3.new(1,1,1), Transparency = 1},
			Fx = {Duration = 1,Offset = Vector3.new(0,0.1,0), LerpFraction = 1},
			Emiter = {Name = "CircleWave", Attachment  = "Attachment", Speed = {NumberRange.new(1, 1), NumberRange.new(15, 15)}},
			Emiter2 = {Name = "Specs", Attachment  = "Attachment", Speed = {NumberRange.new(1, 1), NumberRange.new(15, 15)}},
			Emiter3 = {Name = "Stuff", Attachment  = "Attachment", Speed = {NumberRange.new(1, 1), NumberRange.new(15, 15)}},
			PointLight = {Name = "PointLight", Attachment  = "Attachment", Range = {2, 8} , Stage = "Begin"}},
		Step2 = {
			Render = true,
			Emit = false,
			Part = {Name = "SpawnVFX", Attachment = false, Size = Vector3.new(1,1,1), Transparency = 1},
			Fx = {Duration = 1, Offset = Vector3.new(0,0.1,0), LerpFraction = .3},
			Emiter = {Name = "CircleWave", Attachment  = "Attachment", Speed = {NumberRange.new(15, 15), NumberRange.new(1, 1)}},
			Emiter2 = {Name = "Specs", Attachment  = "Attachment", Speed = {NumberRange.new(15, 15), NumberRange.new(1, 1)}},
			Emiter3 = {Name = "Stuff", Attachment  = "Attachment", Speed = {NumberRange.new(15, 15), NumberRange.new(1, 1)}},
			PointLight = {Name = "PointLight", Attachment  = "Attachment", Range = {8, 2} , Stage = "End"}}},
	
	AoeVFX = {
		Step1 = {
			Render = true,
			Emit = false,
			Part = {Name = "AoeVFX", Attachment = false, Size = {Vector3.new(0.1,1,1),Vector3.new(0.1,5,5)}, Transparency = 1, Stage = "Reverse"},
			Fx = {Duration = 1, Offset = Vector3.new(0,0.1,0), LerpFraction = .5},
			Emiter = {Name = "FireParticle", Attachment  = false, Rate = {100,5} , Stage = "End"},
			PointLight = {Name = "Light", Attachment  = false, Range = {21, 2} , Stage = "End"}}},
}

-- Function to fetch ability properties
function VFXLibrary.getAbility(effectName)
	if typeof(effectName) == "string" then
		return VFXLibrary.Fx[effectName]
	elseif typeof(effectName) == "Instance" then
		return VFXLibrary.Fx[effectName.Name]
	end
end

return VFXLibrary

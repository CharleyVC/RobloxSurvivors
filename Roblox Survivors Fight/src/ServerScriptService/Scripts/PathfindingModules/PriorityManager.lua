local PriorityManager = {}

function PriorityManager.calculatePriority(npc, target)
	local distance = (npc.PrimaryPart.Position - target.PrimaryPart.Position).Magnitude

	if distance < 100 then
		return "High"
	elseif distance < 150 then
		return "Medium"
	else
		return "Low"
	end
end

return PriorityManager

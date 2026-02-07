local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local animateScript = character:WaitForChild("Animate", 5)
		if animateScript then
			animateScript.Disabled = true -- Disable the default Animate script
		end
	end)
end)
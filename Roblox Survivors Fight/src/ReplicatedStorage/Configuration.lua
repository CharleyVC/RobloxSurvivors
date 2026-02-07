local Configuration = {}

Configuration.RunKey = Enum.KeyCode.LeftShift -- Change this to your key

Configuration.WalkSpeed = game.StarterPlayer.CharacterWalkSpeed
Configuration.RunSpeed = 25

Configuration.WalkFov = workspace.Camera.FieldOfView
Configuration.RunFov = 80
Configuration.Duration = 0.2 -- How long it will take to change from the Walk to Run

--Configuration.WalkAnimationId = nil -- put nil if you want default animations
Configuration.RunAnimationId = nil -- put nil if you want default animations

return Configuration

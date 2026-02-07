local MovementState = {}

-- last known direction from ANY input source (keyboard, joystick, gamepad)
MovementState.moveVector = Vector3.zero

function MovementState.SetMoveVector(vec)
	MovementState.moveVector = vec
end

function MovementState.GetMoveVector()
	return MovementState.moveVector
end

return MovementState

local EventDispatcher = {}

function EventDispatcher.schedule(taskFunc, delay)
	task.spawn(function()
		task.wait(delay)
		taskFunc()
	end)
end

return EventDispatcher

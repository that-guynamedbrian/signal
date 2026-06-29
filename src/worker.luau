--!native
--!strict

local free_workers: { thread } = {}

function call(func: (...any) -> (), ...: any)
	func(...)
	table.insert(free_workers, coroutine.running())
end

function create_worker(func: (...any) -> (), ...: any)
	call(func, ...)
	while true do
		call(coroutine.yield())
	end
end

--[[
	Get a thread from pool, or a new one if it doesnt exist, thread automatically returned to pool once used.

    if you don't task.spawn a worker it will just remove it from the pool and cause it to be garbage collected.
]]
function get_worker(): thread
	return table.remove(free_workers) or coroutine.create(create_worker)
end

return get_worker

--!native
--!strict
-- This module returns a function that returns a coroutine
-- once used, the coroutine is cached for reuse
-- coroutines are only created when none are free
local free_workers: {thread} = {}

function call(func:(...any)->(), ...:any)
	func(...)
end

function create_worker(func:(...any)->(), ...:any)
	func(...) 
	while true do
		table.insert(free_workers,coroutine.running())
		call(coroutine.yield())
	end
end

-- ALWAYS spawn a worker, otherwise it will just remove it from the cache
function get_worker(): thread
    return table.remove(free_workers) or coroutine.create(create_worker)
end

return get_worker
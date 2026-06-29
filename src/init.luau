--!native
--!strict

local worker = require("@self/worker")

export type Connection<T... = ...any> = {
	Type: "Connection",

	IsConnected: boolean,
	Reconnect: (self: Connection<T...>) -> (),
	Disconnect: (self: Connection<T...>) -> (),
}
type _Connection<T... = ...any> = {
	_signal: _Signal<T...>,
	_next: _Connection<T...>?,
	_prev: _Connection<T...>?,
	_func: (T...) -> (),
} & Connection<T...>

export type Signal<T... = ...any> = {
	Type: "Signal",

	Fire: (self: Signal<T...>, T...) -> (),
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection<T...>,
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}
type _Signal<T... = ...any> = {
	_head: _Connection<T...>?,
	_rbxConn: RBXScriptConnection?,
} & Signal<T...>

local Connection = {
	Type = "Connection",

	IsConnected = true,

	Reconnect = function<T...>(self: _Connection<T...>)
		if self.IsConnected then return end

		local signal = self._signal
		local nextConnection = signal._head

		self._next = nextConnection
		if nextConnection ~= nil then nextConnection._prev = self end
		signal._head = self

		self.IsConnected = true
	end,

	Disconnect = function<T...>(self: _Connection<T...>)
		if not self.IsConnected then return end

		local nextConnection, prevConnection = self._next, self._prev
		if nextConnection ~= nil then nextConnection._prev = prevConnection end
		if prevConnection ~= nil then prevConnection._next = nextConnection end
		table.clear(self)

		self.IsConnected = false
	end,
} :: Connection

local Signal = {

	Type = "Signal",

	Fire = function<T...>(self: _Signal<T...>, ...: T...): ()
		local connection = self._head
		while connection ~= nil do
			task.spawn(worker(), connection._func, ...)
			connection = connection._next
		end
	end,

	Connect = function<T...>(self: _Signal<T...>, callback: (T...) -> ()): Connection<T...>
		local nextConnection = self._head

		local connection = table.clone(Connection) :: _Connection<T...>
		connection._signal = self
		connection._next = nextConnection
		connection._func = callback

		if nextConnection ~= nil then nextConnection._prev = connection end
		self._head = connection
		return connection
	end,

	Once = function<T...>(self: _Signal<T...>, callback: (T...) -> ()): Connection<T...>
		local connection: Connection<T...>
		connection = self:Connect(function(...: T...)
			callback(...)
			connection:Disconnect()
		end)
		return connection
	end,

	Wait = function<T...>(self: _Signal<T...>): T...
		local co = coroutine.running()
		self:Once(function(...: T...)
			task.spawn(co, ...)
		end)
		return coroutine.yield()
	end,

	DisconnectAll = function<T...>(self: _Signal<T...>): ()
		local connection = self._head
		while connection ~= nil do
			local temp = connection._next
			connection:Disconnect()
			connection = temp
		end
	end,

	Destroy = function<T...>(self: _Signal<T...>)
		self:DisconnectAll()
		table.clear(self)
		if self._rbxConn then self._rbxConn:Disconnect() end
	end,
} :: Signal

return {
	--[[
		Construct a new signal.

		Optionally pass in type args. 
			
		e.g. signal.new<<(number, boolean)>>()
	]]
	new = function<T...>(): Signal<T...>
		return table.clone(Signal)
	end,

	--[[
		Wrap an existing RBXScriptSignal to make it compatible with other signals.

		Types automatically inferred.

		Always call Destroy on wrapped signals, can lead to memory leak otherwise.
	]]
	wrap = function<T...>(signal: RBXScriptSignal<T...>): Signal<T...>
		local self = table.clone(Signal) :: _Signal<T...>
		self._rbxConn = signal:Connect(function(...: T...)
			self:Fire(...)
		end)
		return self
	end,
}

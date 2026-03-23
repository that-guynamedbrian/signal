--!native
--!strict
--!optimize 2

local worker = require(script.Packages.worker)

local task_spawn = task.spawn
local coroutine_yield = coroutine.yield
local coroutine_running = coroutine.running

local table_clear = table.clear
local table_clone = table.clone

-- Types
-- -- Receiver type
export type IReceiver<T... = ...any> = {
	--public
	Type: "Receiver",
	IsConnected: boolean,
	Reconnect: (self: Receiver<T...>) -> (),
	Disconnect: (self: Receiver<T...>) -> (),
}
type Receiver<T... = ...any> = {
	--private
	_signal: Signal<T...>,
	_next: Receiver<T...>,
	_prev: Receiver<T...>,
	_func: (T...) -> (),
} & IReceiver<T...>

-- -- Signal type
export type ISignal<T... = ...any> = {
	Type: "Signal",
	Fire: (self: ISignal<T...>, T...) -> (),
	Connect: (self: ISignal<T...>, callback: (T...) -> ()) -> IReceiver<T...>,
	Once: (self: ISignal<T...>, callback: (T...) -> ()) -> IReceiver<T...>,
	Wait: (self: ISignal<T...>) -> T...,
	DisconnectAll: (self: ISignal<T...>) -> (),
	Destroy: (self: ISignal<T...>) -> (),
}
type Signal<T... = ...any> = {
	--private
	_head: Receiver<T...>,
} & ISignal<T...>

-- Functions
-- -- Receiver
local function receiver_disconnect<T...>(self: Receiver<T...>)
	if not self.IsConnected then return end

	local nextReceiver, prevReceiver = self._next, self._prev
	if nextReceiver ~= nil then nextReceiver._prev = prevReceiver end
	if prevReceiver ~= nil then prevReceiver._next = nextReceiver end
	table_clear(self)

	self.IsConnected = false
end

local function receiver_reconnect<T...>(self: Receiver<T...>)
	if self.IsConnected then return end

	local signal = self._signal
	local nextReceiver = signal._head

	self._next = nextReceiver
	if nextReceiver ~= nil then nextReceiver._prev = self end
	signal._head = self

	self.IsConnected = true
end

local Receiver = {
	Type = "Receiver",
	IsConnected = true,
	Reconnect = receiver_reconnect,
	Disconnect = receiver_disconnect,
} :: IReceiver

-- -- Signal
local function signal_fire<T...>(self: Signal<T...>, ...: T...)
	local receiver = self._head
	while receiver ~= nil do
		task_spawn(worker(), receiver._func, ...)
		receiver = receiver._next
	end
end

local function signal_connect<T...>(self: Signal<T...>, callback: (T...) -> ())
	local nextReceiver = self._head

	local receiver = table_clone(Receiver) :: Receiver<T...>
	receiver._signal = self
	receiver._next = nextReceiver
	receiver._func = callback

	if nextReceiver ~= nil then nextReceiver._prev = receiver end
	self._head = receiver
	return receiver
end

local function signal_once<T...>(self: Signal<T...>, callback: (T...) -> ())
	local receiver: Receiver<T...>
	receiver = signal_connect(self, function(...: T...)
		callback(...)
		receiver_disconnect(receiver)
	end)
	return receiver
end

local function signal_wait<T...>(self: Signal<T...>): T...
	local co = coroutine_running()
	signal_once(self, function(...: T...)
		task_spawn(co, ...)
	end)
	return coroutine_yield()
end

local function signal_disconnectall<T...>(self: Signal<T...>)
	local receiver = self._head
	while receiver ~= nil do
		local temp = receiver._next
		receiver_disconnect(receiver)
		receiver = temp
	end
end

local function signal_destroy<T...>(self: Signal<T...>)
	signal_disconnectall(self)
	table_clear(self)
end

local Signal = {
	Type = "Signal",
	Fire = signal_fire,
	Connect = signal_connect,
	Once = signal_once,
	Wait = signal_wait,
	DisconnectAll = signal_disconnectall,
	Destroy = signal_destroy,
} :: ISignal

-- Return Constructor
local function signal_new<T...>(): ISignal<T...>
	return table_clone(Signal) :: ISignal<T...>
end

local function signal_wrap<T...>(signal: RBXScriptSignal): ISignal<T...>
	local self = table_clone(Signal) :: Signal<T...>
	signal:Connect(function(...: T...)
		signal_fire(self, ...)
	end)
	return self :: ISignal<T...>
end

return {
	new = signal_new,
	wrap = signal_wrap,
}

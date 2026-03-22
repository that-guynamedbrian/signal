--!native
--!strict
local worker = require(script.packages.worker)

local task_spawn = task.spawn
local coroutine_yield = coroutine.yield
local coroutine_running = coroutine.running

local table_clear = table.clear
local table_clone = table.clone
-- Types
-- -- Receiver type
export type IReceiver<T...=...any> = {
    --public
    Type: "Receiver";
    Disconnect: (self:Receiver<T...>)->();
}

type Receiver<T...=...any> = {
    --private
    _next: Receiver<T...>;
    _prev: Receiver<T...> | Signal<T...>;
    _func: (T...)->();
} & IReceiver<T...>;

-- -- Signal type
export type ISignal<T...=...any> = {
    Type: "Signal";
    Destroy: (self:ISignal<T...>)->();
    Fire: (self:ISignal<T...>, T...)->();
    Connect: (self:ISignal<T...>, callback:(T...)->())->(IReceiver<T...>);
    Once: (self:ISignal<T...>, callback:(T...)->())->(IReceiver<T...>);
    Wait: (self:ISignal<T...>)->(T...);
};

type Signal<T...=...any> = {
    --private
    _next: Receiver<T...>;
    _prev: Receiver<T...> | Signal<T...>;
} & ISignal<T...>;

-- Functions
-- -- Receiver
local function receiver_disconnect<T...>(self:Receiver<T...>)
    local nextReceiver, prevReceiver = self._next, self._prev
    if nextReceiver then 
        nextReceiver._prev = prevReceiver
    end
    prevReceiver._next = nextReceiver
    table_clear(self)
end

local Receiver: IReceiver = {
    Type = "Receiver";
    Disconnect = receiver_disconnect;
}

-- -- Signal
local function signal_fire<T...>(self:Signal<T...>, ...:T...)
    local receiver = self._next
    while receiver ~= nil do
        task_spawn(worker(), receiver._func, ...)
        receiver = receiver._next
    end
end

local function signal_connect<T...>(self:Signal<T...>, callback:(T...)->())
    local nextReceiver = self._next
    
    local receiver: Receiver<T...> = table_clone(Receiver)
    receiver._next = nextReceiver
    receiver._prev = self
    receiver._func = callback

    if nextReceiver ~= nil then
        nextReceiver._prev = receiver
    end
    self._next = receiver
    return receiver
end

local function signal_once<T...>(self:Signal<T...>, callback:(T...)->())
    local receiver :Receiver<T...>
    receiver = signal_connect(self, function(...:T...)
        callback(...)
        receiver_disconnect(receiver)
    end)
    return receiver
end

local function signal_wait<T...>(self:Signal<T...>):T...    
    local co = coroutine_running();
    signal_once(self, function(...:T...)
        task_spawn(co, ...);
    end);
    return coroutine_yield();
end

local function signal_destroy<T...>(self:Signal<T...>)
    local receiver = self._next;
    while receiver ~= nil do
        local temp = receiver._next;
        receiver_disconnect(receiver);
        receiver = temp;
    end
    table_clear(self);
end

local Signal = {
    Type = "Signal";
    Fire = signal_fire;
    Connect = signal_connect;
    Once = signal_once;
    Wait = signal_wait;
    Destroy = signal_destroy;
} :: ISignal

-- Return Constructor
local function signal_new<T...>(): ISignal<T...>
    return table_clone(Signal) :: ISignal<T...>
end

return signal_new
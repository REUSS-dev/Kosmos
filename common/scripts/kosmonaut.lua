-- kosmonaut
local kosmonaut = {}



-- documentation

---@alias AsyncTask string|table Async task context, that is processed by task launcher
---@alias AsyncTaskIdentifier integer Number that identifies task object within the Async system. 
---@alias AsyncNickname integer|string Nickname of a task used to externally and independently identify abstract task
---@alias AsyncCallback fun(task: AsyncTask, result: any?, err: string?, ...) Async operation result catch callback function

-- config



-- consts

local DEFAULT_TIMEOUT = 5
local DEFAULT_MAX_SEQUENCE = 10

-- vars

local task_id

-- init

task_id = 0

-- fnc

local function getNewTaskID()
    task_id = task_id + 1
    return task_id
end

-- classes

---@class AsyncAgent Helper for async operations
---@field tasks table<AsyncTaskIdentifier, AsyncTask> Map of task objects currently being processed by AsyncAgent
---@field callbacks table<AsyncTaskIdentifier, AsyncCallback> Map of task callbacks called on task finish
---@field extra_callbacks table<AsyncTaskIdentifier, AsyncCallback[]?> Map of extra callbacks that should be called on task finish
---@field wait_time table<AsyncTaskIdentifier, number> Map of tasks time elapsed after popping. Used to discard tasks on timeouts
---@field nickname table<AsyncNickname, AsyncTaskIdentifier> Map of Task nicknames to task IDs
---@field _nickname table<AsyncTaskIdentifier, AsyncNickname> Map of task IDs to tas nicknames
---@field queue AsyncTaskIdentifier[] Queue of tasks to be processed. Consists of task IDENTIFIERS, not actual tasks
---@field timeout number Timeout (in seconds) after which the task will be finished with failure and discarded
---@field sequenceCounter integer Current amount of back-to-back successful pops.
---@field maxSequence integer Maximum allowed amount of back-to-back successful pops.
---@field parent table Parenting object that is set as first parameter of all tasks callback calls
local AsyncAgent = {}
local AsyncAgent_meta = { __index = AsyncAgent }

--#region Task management

---Queues provided task into processing
---@param task AsyncTask
---@param callback AsyncCallback
---@param nickname AsyncNickname?
---@return AsyncTaskIdentifier
function AsyncAgent:queueTask(task, callback, nickname)
    local new_task_id = getNewTaskID()

    self.tasks[new_task_id] = task
    self.callbacks[new_task_id] = callback

    self.queue[#self.queue+1] = new_task_id

    self:addNickname(new_task_id, nickname)

    return new_task_id
end

---Extract first task from the processing queue.
---@return AsyncTask? new_task New task extracted from queue, if queue is not empty; nil otherwise
---@return AsyncTaskIdentifier? new_task_id Task id used to finish this task, if queue is not empty; nil otherwise
function AsyncAgent:popTask()
    local task_dispatched = self.queue[1]

    if not task_dispatched or self.sequenceCounter >= self.maxSequence then
        self:resetSubsequent()
        return nil
    end

    self.sequenceCounter = self.sequenceCounter + 1

    table.remove(self.queue, 1)

    self.wait_time[task_dispatched] = 0

    return self.tasks[task_dispatched], task_dispatched
end

---Returns currently processed tasks with provided identifier (if such exists)
---@param task_identifier AsyncTaskIdentifier
---@return AsyncTask?
function AsyncAgent:getTask(task_identifier)
    return self.tasks[task_identifier]
end

---Closes currently processed task with provided indetifier and result.
---@param task_identifier AsyncTaskIdentifier
---@param result any?
---@param ... any?
---@return boolean success True, if task with provided identifier exists and is scuccessfuly closed; false otherwise
function AsyncAgent:finishTask(task_identifier, result, ...)
    local finished_task = self.tasks[task_identifier]

    if not finished_task then
        return false
    end

    self.callbacks[task_identifier](self.parent, finished_task, result, ...)

    self.tasks[task_identifier] = nil
    self.callbacks[task_identifier] = nil
    self.wait_time[task_identifier] = nil

    self:removeNickname(task_identifier)

    if self.extra_callbacks[task_identifier] then
        for _, extra_callback in ipairs(self.extra_callbacks[task_identifier]) do
            extra_callback(self.parent, finished_task, result, ...)
        end

        self.extra_callbacks[task_identifier] = nil
    end

    return true
end

---Attach additional catch callback to a currently processed task
---@param nickname AsyncNickname
---@param newCallback AsyncCallback
---@return boolean success True, if task with provided nickname exists and additional callback successfuly attached; false otherwise
function AsyncAgent:attachCallback(nickname, newCallback)
    local resloved = self:resolveNickname(nickname)

    if not resloved then
        return false
    end

    self.extra_callbacks[resloved] = self.extra_callbacks[resloved] or {}

    self.extra_callbacks[resloved][#self.extra_callbacks[resloved]+1] = newCallback

    return true
end

--#endregion

--#region Task nickname management

---Assign nickname to a task
---@param task_identifier AsyncTaskIdentifier
---@param nickname AsyncNickname?
---@private
function AsyncAgent:addNickname(task_identifier, nickname)
    if not nickname then
        return
    end

    self.nickname[nickname] = task_identifier
    self._nickname[task_identifier] = nickname
end

---Remove task's associated nickname
---@param task_identifier AsyncTaskIdentifier
---@private
function AsyncAgent:removeNickname(task_identifier)
    if not self._nickname[task_identifier] then
        return
    end

    self.nickname[self._nickname[task_identifier]] = nil
    self._nickname[task_identifier] = nil
end

---Try to resolve task nickname
---@param nickname AsyncNickname
---@return AsyncTaskIdentifier?
---@private
function AsyncAgent:resolveNickname(nickname)
    return self.nickname[nickname]
end

--#endregion

--#region Task timeout management

---Get currently set task wait time
---@return number
function AsyncAgent:getTimeout()
    return self.timeout
end

---Set new timeout to wait before finishing task forcefully
---@param new_timeout number
function AsyncAgent:setTimeout(new_timeout)
    self.timeout = new_timeout

    return self
end

---Update processed tasks' timeouts
---@param dt number
function AsyncAgent:update(dt)
    for identifier, time_elapsed in pairs(self.wait_time) do
        self.wait_time[identifier] = self.wait_time[identifier] + dt

        if time_elapsed + dt > self.timeout then
            self:finishTask(identifier, nil)
        end
    end
end

--#endregion

--#region Maximum subsequent tasks management

---Get maximum amount of tasks that can be popped subsequently
---@return integer max_subsequent
---@public
function AsyncAgent:getMaximumSubsequentPops()
    return self.maxSequence
end

---Set maximum amount of tasks that can be popped subsequently
---@param new_subsequent integer
---@return AsyncAgent self
---@public
function AsyncAgent:setMaximumSubsequentPops(new_subsequent)
    self.maxSequence = new_subsequent

    return self
end

---Reset sequence counter of popped tasks
function AsyncAgent:resetSubsequent()
    self.sequenceCounter = 0
end

--#endregion

-- kosmonaut fnc

function kosmonaut.new(parent, timeout, max_consequent_pops)
    local new_async = setmetatable({
        queue = {},
        tasks = {},
        callbacks = {},
        extra_callbacks = {},
        wait_time = {},

        nickname = {},
        _nickname = {},

        timeout = timeout or DEFAULT_TIMEOUT,
        maxSequence = max_consequent_pops or DEFAULT_MAX_SEQUENCE,
        sequenceCounter = 0,

        parent = parent
    }, AsyncAgent_meta)

    return new_async
end

return kosmonaut
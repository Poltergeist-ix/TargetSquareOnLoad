--[[
    module for calling functions when specific world squares are loaded on server, based on TheIndieStone's SGlobalObjectSystem
    Author Poltergeist
--]]

if isClient() then return end

---@class TargetSquareOnLoad
local System = { Type = "TargetSquareOnLoad" }
---@type table<string, fun(square: IsoGridSquare,commandData: table)>
System.OnLoadCommands = {}
System.wantNoise = getDebug()

---try to sync if file is reloaded
function System.instanceCheck()
    for i = 0, SGlobalObjects.getSystemCount() - 1 do
        local system = SGlobalObjects.getSystemByIndex(i)
        local luaSystem = system:getModData()
        if luaSystem.Type == System.Type then
            System = luaSystem
            return
        end
    end
end
System.instanceCheck()

---@param message string
function System:noise(message) if self.wantNoise then print(self.Type..': '..message) end end

---Create instance
function System.OnSGlobalObjectSystemInit()
    local jSystem = SGlobalObjects.registerSystem(System.Type)
    jSystem:setModDataKeys({"savedData"})
    jSystem:setObjectModDataKeys({"commands"})

    ---@class TargetSquareOnLoad
    local o = jSystem:getModData()
    setmetatable(o, System)
    System.__index = System
    o.system = jSystem
    o.savedData = o.savedData or {}
    o:addPreInitActions()
    o:noise('OnSGlobalObjectSystemInit, #objects='.. jSystem:getObjectCount())
    System.instance = o
    return o
end

---Add commands that were added before system init
function System:addPreInitActions()
    if not System.queuedCommands then return end
    for i,v in ipairs(System.queuedCommands) do
        self:addCommandToGlobalObject(unpack(v))
    end
    System.queuedCommands = nil
end

--- called from java when a chunk with GlobalObjects managed by this system is loaded.
---@param wx int
---@param wy int
function System:OnChunkLoaded(wx, wy)
    local ipairs, table, getSquare = ipairs, table, getSquare
    local globalObjects = self.system:getObjectsInChunk(wx, wy)
    if self.wantNoise then self:noise("loaded chunk with #objects="..globalObjects:size()) end

    for i = globalObjects:size() - 1, 0, -1  do
        local globalObject = globalObjects:get(i)
        local luaObject = globalObject:getModData() --only has the persistent commands table
        local square = getSquare(globalObject:getX(), globalObject:getY(), globalObject:getZ())

        local repeatCommands, repeatNum = {}, 0
        for i,command in ipairs(luaObject.commands) do
            if self:doCommand(square,command) == true then
                repeatNum = repeatNum + 1
                repeatCommands[repeatNum] = command
            end
        end

        if repeatNum > 0 then
            luaObject.commands = repeatCommands
        else
            self.system:removeObject(globalObject)
        end
    end

    self.system:finishedWithList(globalObjects)
end

---Call a command function added for the square
---@param square? IsoGridSquare
---@param command table
---@return boolean?
function System:doCommand(square, command)
    if not square and not command.squareCanBeNil then return end
    local f = self.OnLoadCommands[command.command]
    if type(f) == "function" then
        return f(square, command)
    else
        print(string.format("%s: command %s is %s",self.Type,type(command) == "table" and command.command or command,tostring(f)))
    end
end

---Check if the command is valid
---@param command table
function System:isValidCommand(command)
    if type(command) ~= "table" then error(self.Type .. ": invalid command, not a table type " .. tostring(command)) return end
    if type(command.command) ~= "string" then error(self.Type .. ": invalid command, not a string type " .. tostring(command)) return end
    if type(self.OnLoadCommands[command.command]) ~= "function" then error(self.Type .. ": invalid command, no function " .. tostring(command)) return end
    return true
end

---Add the command to the global object data
---@param x int
---@param y int
---@param z int
---@param command table
function System:addCommandToGlobalObject(x,y,z,command)
    if System:isValidCommand(command) then
        local globalObject = self.system:getObjectAt(x,y,z)
        if globalObject then
            table.insert(globalObject:getModData().commands, command)
        else
            globalObject = self.system:newObject(x,y,z)
            globalObject:getModData().commands = { command }
        end
        self:noise(string.format("added command for square: %d,%d,%d",x,y,z))
    end
end

---queue command for after system init
function System.queueAddCommand(...)
    if not System.queuedCommands then System.queuedCommands = {} end
    table.insert(System.queuedCommands,{...})
end

---@param x number
---@param y number
---@param z number
---@param commandData table
function System.addCommand(x,y,z,commandData)
    if System.instance then
        System.instance:addCommandToGlobalObject(x,y,z,commandData)
    else
        System.queueAddCommand(x,y,z,commandData)
    end
end

---called from java, return nil or a Lua table that is used to initialize the client-side system
function System:getInitialStateForClient() return nil end

Events.OnSGlobalObjectSystemInit.Add(System.OnSGlobalObjectSystemInit)

---fixes for global object debugger -SP only
if not isServer() and getDebug() then
    function System:getIsoObjectAt() return nil end

    local DebugGlobalObjectStateUI_ObjectList_doDrawItem = DebugGlobalObjectStateUI.ObjectList_doDrawItem
    function DebugGlobalObjectStateUI:ObjectList_doDrawItem(y, item, alt)
        if item.item.system:getName() == System.Type then
            local x = 4

            if self.selected == item.index then
                self:drawRect(0, y, self:getWidth(), item.height-1, 0.3, 0.7, 0.35, 0.15)
            end

            local r,g,b,a = 1,1,1,1
            local data = item.item
            if not data.system:getObjectAt(data.x, data.y, data.z) then
                r,g,b = 0.5,0.5,0.5
            end

            self:drawText(item.text, x, y, r, g, b, a, self.font)
            y = y + self.fontHgt

            self:drawRect(x, y, self.width - 4 * 2, 1, 1.0, 0.5, 0.5, 0.5)
            y = y + 2

            return y
        else
            return DebugGlobalObjectStateUI_ObjectList_doDrawItem(self, y, item, alt)
        end
    end
end

return System
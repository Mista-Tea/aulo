AuloPackage = AuloPackage or {}
AuloPackage.__index = AuloPackage

--[[--------------------------------------------------------------------------
-- 	new(string)
--]]--
function AuloPackage:new(aulo, parent, name, path)
    -- Convert the package filepath into something similar to Java's packages
    local id  = ("%s.%s"):format(path:Replace('/', '.'), name):lower()

    return setmetatable({
        [  '_aulo_'  ] = function() return aulo end,   -- reference to the aulo table
        [ '_parent_' ] = function() return parent end, -- reference to this package's parent package
        [  '_name_'  ] = name,   -- name of this package
        [  '_path_'  ] = path,   -- the folder path to this package
        [   '_id_'   ] = id,     -- unique identifier for package hooks
    }, self)
end

-- Allows calls like AuloPackage() to instantiate a new object
setmetatable(AuloPackage, {__call = AuloPackage.new})

function AuloPackage:__tostring()
    local str = "<[object:AuloPackage]\n  Fields:\n"
    
    for field, value in SortedPairs(self) do
        if AuloPackage[field] == nil then
            str = str .. ("\t%-24s : %s\n"):format(field, value)
        end
    end
    
    return str .. ">"
end

--[[--------------------------------------------------------------------------
-- 	IsDebugging()
--]]--
function AuloPackage:IsDebugging()
    return self:_aulo_().debug
end

--[[--------------------------------------------------------------------------
-- 	Debug(varargs...)
--]]--
function AuloPackage:Debug(...)
    self:_aulo_():Debug(...)
end

function AuloPackage:Reload(doRecursive)
    self:_aulo_():ReloadPackage(self._id_, doRecursive)
end

--[[--------------------------------------------------------------------------
-- 	GetParent()
--]]--
function AuloPackage:GetParent()
    return self:_parent_()
end

--[[--------------------------------------------------------------------------
-- 	GetName()
--]]--
function AuloPackage:GetName()
    return self._name_
end

--[[--------------------------------------------------------------------------
-- 	GetPath()
--]]--
function AuloPackage:GetPath()
    return self._path_
end

--[[--------------------------------------------------------------------------
-- 	GetID()
--]]--
function AuloPackage:GetID()
    return self._id_
end

--[[--------------------------------------------------------------------------
-- 	IsValid()
--]]--
function AuloPackage:IsValid()
    return true
end



-- Hook functionality for the current package

--[[--------------------------------------------------------------------------
-- 	AddHook(string, *, function)
--]]--
function AuloPackage:AddHook(hookname, id, func)
    self:AddGlobalHook(self._id_ .. '.' .. hookname, id, func)
end

--[[--------------------------------------------------------------------------
-- 	RemoveHook(string, *)
--]]--
function AuloPackage:RemoveHook(hookname, id)
    self:RemoveGlobalHook(self._id_ .. '.' .. hookname, id)
end

--[[--------------------------------------------------------------------------
-- 	RunHook(string, varargs...)
--]]--
function AuloPackage:RunHook(hookname, ...)
    self:RunGlobalHook(self._id_ .. '.' .. hookname, ...)
end



-- Hook functionality for the specified package

--[[--------------------------------------------------------------------------
-- 	AddPackageHook(string, *, function)
--]]--
function AuloPackage:AddPackageHook(packagename, id, func)
    self:AddGlobalHook(self._aulo_().baseid .. '.' .. packagename, id, func)
end

--[[--------------------------------------------------------------------------
-- 	RemovePackageHook(string, *)
--]]--
function AuloPackage:RemovePackageHook(packagename, id)
    self:RemoveGlobalHook(self._aulo_().baseid .. '.' .. packagename, id)
end

--[[--------------------------------------------------------------------------
-- 	RunPackageHook(string, varargs...)
--]]--
function AuloPackage:RunPackageHook(packagename, ...)
    self:RunGlobalHook(self._aulo_().baseid .. '.' .. packagename, ...)
end



-- Hook functionality for regular GMod hooks

--[[--------------------------------------------------------------------------
-- 	AddGlobalHook(string, *, function)
--]]--
function AuloPackage:AddGlobalHook(hookname, id, func)
    hook.Add(hookname, isstring(id) and self._id_ .. '.' .. id or id, func)
end

--[[--------------------------------------------------------------------------
-- 	RemoveGlobalHook(string, *)
--]]--
function AuloPackage:RemoveGlobalHook(hookname, id)
    hook.Remove(hookname, isstring(id) and self._id_ .. '.' .. id or id)
end

--[[--------------------------------------------------------------------------
-- 	RunGlobalHook(string, varargs...)
--]]--
function AuloPackage:RunGlobalHook(hookname, ...)
    if self:IsDebugging() then
        self:Debug("Hook: ", hookname)
    end
    
    hook.Run(hookname, ...)
end

--[[--------------------------------------------------------------------------
-- 	AddGamemodeHook(string, function)
--]]--
function AuloPackage:AddGamemodeHook(hookname, func)
    GAMEMODE[hookname] = func
end

--[[--------------------------------------------------------------------------
-- 	RunGamemodeHook(string, varargs...)
--]]--
function AuloPackage:RunGamemodeHook(hookname, ...)
    GAMEMODE[hookname](...)
end

if SERVER then
    function AuloPackage:AddNetworkString(msgname)
        util.AddNetworkString(self._id_ .. '.' .. msgname)
    end
    
    function AuloPackage:Send(msgname, plys, ...)
        fnet.Send(self._id_ .. '.' .. msgname, plys, ...)
    end
    
    function AuloPackage:Broadcast(msgname, ...)
        fnet.Broadcast(self._id_ .. '.' .. msgname, ...)
    end
    
    function AuloPackage:SendOmit(msgname, ply, ...)
        fnet.SendOmit(self._id_ .. '.' .. msgname, ply, ...)
    end
else
    function AuloPackage:Send(msgname, ...)
        fnet.SendToServer(self._id_ .. '.' .. msgname, ...)
    end
end

function AuloPackage:Receive(msgname, callback)
    local _callback
    
    if self:IsDebugging() then
         _callback = function(...)
            self:Debug("Net Receive: ", msgname)
            callback(...)
        end
    else
        _callback = callback
    end
    
    net.Receive(self._id_ .. '.' .. msgname, _callback)
end

--[[--------------------------------------------------------------------------
-- 	GetPackage(string)
--]]--
function AuloPackage:GetPackage(name)
    local aulo = self._aulo_()
    return aulo:GetPackage(name) or aulo:GetPackageByName(name)
end
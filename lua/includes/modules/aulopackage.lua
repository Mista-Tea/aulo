AuloPackage = AuloPackage or {}
AuloPackage.__index = AuloPackage

--[[--------------------------------------------------------------------------
-- 	new(string)
--]]--
function AuloPackage:new(path)
    return setmetatable({ ['path'] = path }, self)
end

--[[--------------------------------------------------------------------------
-- 	AddHook(string,string, function)
--]]--
function AuloPackage:AddHook(hookname, id, func)
    hook.Add(self.path .. hookname, self.path .. id, func)
end

--[[--------------------------------------------------------------------------
-- 	RemoveHook(string,string)
--]]--
function AuloPackage:RemoveHook(hookname, id)
    hook.Remove(self.path .. hookname, self.path .. id)
end

--[[--------------------------------------------------------------------------
-- 	RunHook(string, varargs...)
--]]--
function AuloPackage:RunHook(hookname, varargs)
    hook.Run(self.path .. hookname, varargs)
end

--[[--------------------------------------------------------------------------
-- 	AddGlobalHook(string,string, function)
--]]--
function AuloPackage:AddGlobalHook(hookname, id, func)
    hook.Add(hookname, self.path .. id, func)
end

--[[--------------------------------------------------------------------------
-- 	RemoveGlobalHook(string,string)
--]]--
function AuloPackage:RemoveGlobalHook(hookname, id)
    hook.Remove(hookname, self.path .. id)
end

--[[--------------------------------------------------------------------------
-- 	RunGlobalHook(string, varargs...)
--]]--
function AuloPackage:RunGlobalHook(hookname, varargs)
    hook.Run(hookname, varargs)
end

-- Allows calls like AuloPackage() to instantiate a new object
setmetatable(AuloPackage, {__call = AuloPackage.new})

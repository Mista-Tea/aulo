--[[
    MIT License

    Copyright (c) 2018, Mista-Tea

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]

local file = file
local debug = debug
local ipairs = ipairs
local xpcall = xpcall
local include = include
local require = require
local ErrorNoHalt = ErrorNoHalt
local AddCSLuaFile = AddCSLuaFile

AddCSLuaFile('includes/modules/aulopackage.lua')
include('includes/modules/aulopackage.lua')

Aulo = Aulo or {}
Aulo.__index = Aulo

--[[--------------------------------------------------------------------------
-- 	new(string)
--]]--
function Aulo:new()
    return setmetatable({
        packages   = {},    -- table of loaded packages (AuloPackage objects)
        lookup     = {},    -- table of packages indexed by their package path (abc.jkl.xyz)
        basepath   = "",    -- the directory where packages are located
        baseid     = "",    -- the root of the package directory (equivalent to basepath with '.' instead of '/')
        searchpath = "LUA", -- where to load files from, see http://wiki.garrysmod.com/page/File_Search_Paths
    }, self)
end

-- Allows calls like Aulo() to instantiate a new object
setmetatable(Aulo, {__call = Aulo.new})

function Aulo:__tostring()
    return ("<%s\n %s\n>"):format("[object:Aulo]", self:Print())
end


if SERVER then
    Aulo.includes = {
        sv = include,
        sh = function(path) AddCSLuaFile(path) return include(path) end,
        cl = AddCSLuaFile
    }
else
    Aulo.includes = {
        cl = include,
        sh = include
    }
end

--[[--------------------------------------------------------------------------
-- 	Print(table, number)
--]]--
function Aulo:Print(tbl, depth)
    local str = tbl and "" or self.basepath
    
    for name, pkg in SortedPairs(tbl or self.packages) do
        if not istable(pkg) or pkg._aulo_ == nil then continue end
        
        str = str .. ("\n%s╚ %-12s"):format(('  '):rep(depth or 1), name)
        str = str .. (" (%d fields/functions)"):format(table.Count(pkg))
        
        local substr = self:Print(pkg, depth and depth + 1 or 2)
        if substr ~= nil then
            str = str .. ("%s%s"):format(('  '):rep(depth and depth + 1 or 2), substr)
        end
    end
    
    return str
end

--[[--------------------------------------------------------------------------
-- 	ClearPackages()
--]]--
function Aulo:ClearPackages()
    self.packages = {}
    self.lookup   = {}
end

--[[--------------------------------------------------------------------------
-- 	GetPackage(string)
--]]--
function Aulo:GetPackage(id)
    return self.lookup[id:lower()]
end

--[[--------------------------------------------------------------------------
-- 	GetPackageByName(string)
--]]--
function Aulo:GetPackageByName(name)
    return self.lookup[self.baseid .. "." .. name]
end

--[[--------------------------------------------------------------------------
-- 	GetPackages()
--]]--
function Aulo:GetPackages()
    return self.packages
end

--[[--------------------------------------------------------------------------
-- 	GenerateNewPackage(table, string, string)
--]]--
function Aulo:GenerateNewPackage(parent, packagename, path)
    local pkg = AuloPackage(self, parent, packagename, path)
    self.lookup[pkg:GetID()] = pkg
    
    return pkg
end

--[[--------------------------------------------------------------------------
-- 	ReloadPackage(string, boolean)
--]]--
function Aulo:ReloadPackage(id, doRecursive)
    local pkg = self:GetPackage(id) or self:GetPackageByName(id)
    if pkg then
        self:LoadPackage(pkg:GetParent(), pkg:GetPath(), pkg:GetName(), doRecursive or false)
    else
        ErrorNoHalt(("\n[Aulo] No package was found with the id '%s'\n"):format(id))
    end
end

--[[--------------------------------------------------------------------------
-- 	LoadPackage(table, string, string, boolean)
--]]--
function Aulo:LoadPackage(destination, path, packagename, doRecursive)
    local files, subpackages = file.Find(("%s/%s/*"):format(path, packagename), self.searchpath, "nameasc")
    
    -- Create a new package, or reuse it if it already exists (i.e. reloading)
    destination[packagename] = destination[packagename] or self:GenerateNewPackage(destination, packagename, path)
        
    -- Loop through each Lua file in the package and include it based on it's file prefix (cl_, sh_, sv_)
    for _, filename in ipairs(files) do
        local realm = filename:sub(1,2)
        local includefile = self.includes[realm]
        local fullpath = ("%s/%s/%s"):format(path, packagename, filename)
        local loader = includefile(fullpath)
        
        -- If the included file returned a function, pass it a reference to the full library and have it populate the current package 
        if loader then
            local ok, err = xpcall(function()
                loader(self.packages, destination[packagename])
            end, function(err) ErrorNoHalt(("\n[Aulo] Failed to load file %s\n%s\n%s\n\n"):format(filename, err, debug.traceback())) end)
        end
    end
    
    -- Loop through the subfolders and recursively add them as subpackages
    if doRecursive then
        for _, subpackage in ipairs(subpackages) do
            local subpath = ("%s/%s"):format(path, packagename)
            self:LoadPackage(destination[packagename], subpath, subpackage, doRecursive)
        end
    end
end

--[[--------------------------------------------------------------------------
-- 	Load(string, string)
--]]--
function Aulo:Load(basepath, searchpath)
    self.basepath   = basepath
    self.baseid     = basepath:Replace("/", ".")
    self.searchpath = searchpath or self.searchpath
    
    local _, folders = file.Find(basepath .. "/*", self.searchpath, "nameasc")
    
    -- Loop through each folder in the directory and begin recursively building the packages
    for _, folder in ipairs(folders) do
        self:LoadPackage(self.packages, basepath, folder, true)
    end
end
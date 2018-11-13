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
require('aulopackage')

aulo = aulo or {
    packages   = {},    -- table of loaded packages (AuloPackage objects)
    searchpath = "LUA", -- where to load files from, see http://wiki.garrysmod.com/page/File_Search_Paths
}

if SERVER then
    aulo.includes = {
        sv = include,
        sh = function(path) AddCSLuaFile(path) return include(path) end,
        cl = AddCSLuaFile
    }
else
    aulo.includes = {
        cl = include,
        sh = include
    }
end

--[[--------------------------------------------------------------------------
-- 	ClearPackages()
--]]--
function aulo.ClearPackages()
    aulo.packages = {}
end

--[[--------------------------------------------------------------------------
-- 	GenerateNewPackage(string, string)
--]]--
function aulo.GenerateNewPackage(path, packagename)
    -- Convert the package filepath into something similar to Java's packages
    path = ("%s.%s."):format(path:Replace('/', '.'), packagename)
    
    return AuloPackage(path)
end

--[[--------------------------------------------------------------------------
-- 	LoadPackage(table, string, string)
--]]--
function aulo.LoadPackage(destination, path, packagename)
    local files, subpackages = file.Find(("%s/%s/*"):format(path, packagename), aulo.searchpath, "nameasc")
    
    -- Create a new package, or reuse it if it already exists (i.e. reloading)
    destination[packagename] = destination[packagename] or aulo.GenerateNewPackage(path, packagename)
        
    -- Loop through each Lua file in the package and include it based on it's file prefix (cl_, sh_, sv_)
    for _, filename in ipairs(files) do
        local realm = filename:sub(1,2)
        local includefile = aulo.includes[realm]
        local fullpath = ("%s/%s/%s"):format(path, packagename, filename)
        local loader = includefile(fullpath)
        
        -- If the included file returned a function, pass it a reference to the full library and have it populate the current package 
        if loader then
            local ok, err = xpcall(function()
                loader(aulo.packages, destination[packagename])
            end, function(err) ErrorNoHalt(("\n[aulo] Failed to load file %s\n%s\n%s\n\n"):format(filename, err, debug.traceback())) end)
        end
    end
    
    -- Loop through the subfolders and recursively add them as subpackages
    for _, subpackage in ipairs(subpackages) do
        local subpath = ("%s/%s"):format(path, packagename)
        aulo.LoadPackage(destination[packagename], subpath, subpackage)
    end
end

--[[--------------------------------------------------------------------------
-- 	Load(string)
--]]--
function aulo.Load(basepath, searchpath)
    aulo.searchpath = searchpath or aulo.searchpath
    
    local _, folders = file.Find(basepath .. "/*", aulo.searchpath, "nameasc")
    
    -- Loop through each folder in the directory and begin recursively building the packages
    for _, folder in ipairs(folders) do
        aulo.LoadPackage(aulo.packages, basepath, folder)
    end
end
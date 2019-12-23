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

aulo = aulo or {
    packages   = {},    -- table of loaded packages (AuloPackage objects)
    lookup     = {},    -- table of packages indexed by their package path (abc.jkl.xyz)
    basepath   = "",    -- the directory where packages are located
    baseid     = "",    -- the root of the package directory (equivalent to basepath with '.' instead of '/')
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
-- 	Print([table]. [number])
--]]--
function aulo.Print(tbl, depth)
    local str = tbl and "" or aulo.basepath
    
    for name, pkgs in pairs(tbl or aulo.packages) do
        str = str .. ("\n%s%-12s"):format(('  '):rep(depth or 1), name)
        
        if IsValid(pkgs) then
            str = str .. (" (%d fields/functions)"):format(table.Count(pkgs))
        else
            str = str .. ("\n%s%s"):format(('  '):rep(depth and depth + 1 or 2), aulo.Print(pkgs, depth or 2))
        end
    end
    
    if not tbl then
        print(str)
    else
        return str
    end
end

function aulo.Print()
    local base = aulo.basepath:Replace("/", ".")
    
    local output = base
    
    for name, pkg in SortedPairs(aulo.lookup) do
        local id = pkg:GetID():Replace(base .. ".", "")
        local tbl = ("."):Explode(id)
        local depth = #tbl
        
        output = output .. ("\n%s╚ %-12s (%s fields/functions)"):format(("  "):rep(depth - 1), tbl[depth], table.Count(pkg))
    end
    
    print(output)
end

--[[--------------------------------------------------------------------------
-- 	ClearPackages()
--]]--
function aulo.ClearPackages()
    aulo.packages = {}
    aulo.lookup   = {}
end

--[[--------------------------------------------------------------------------
-- 	GetPackage(string)
--]]--
function aulo.GetPackage(id)
    return aulo.lookup[id:lower()]
end

--[[--------------------------------------------------------------------------
-- 	GetPackageByName(string)
--]]--
function aulo.GetPackageByName(name)
    return aulo.lookup[aulo.baseid .. "." .. name]
end

--[[--------------------------------------------------------------------------
-- 	GetPackages()
--]]--
function aulo.GetPackages()
    return aulo.packages
end

--[[--------------------------------------------------------------------------
-- 	GenerateNewPackage(string, string)
--]]--
function aulo.GenerateNewPackage(parent, packagename, path)
    local pkg = AuloPackage(aulo, parent, packagename, path)
    aulo.lookup[pkg:GetID()] = pkg
    
    return pkg
end

--[[--------------------------------------------------------------------------
-- 	ReloadPackage(string, boolean)
--]]--
function aulo.ReloadPackage(id, doRecursive)
    local pkg = aulo.GetPackage(id) or aulo.GetPackageByName(id)
    if pkg then
        aulo.LoadPackage(pkg:GetParent(), pkg:GetPath(), pkg:GetName(), doRecursive or false)
    else
        ErrorNoHalt(("\n[aulo] No package was found with the id '%s'\n"):format(id))
    end
end

--[[--------------------------------------------------------------------------
-- 	LoadPackage(table, string, string, boolean)
--]]--
function aulo.LoadPackage(destination, path, packagename, doRecursive)
    local files, subpackages = file.Find(("%s/%s/*"):format(path, packagename), aulo.searchpath, "nameasc")
    
    -- Create a new package, or reuse it if it already exists (i.e. reloading)
    destination[packagename] = destination[packagename] or aulo.GenerateNewPackage(destination, packagename, path)
        
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
    if doRecursive then
        for _, subpackage in ipairs(subpackages) do
            local subpath = ("%s/%s"):format(path, packagename)
            aulo.LoadPackage(destination[packagename], subpath, subpackage)
        end
    end
end

--[[--------------------------------------------------------------------------
-- 	Load(string)
--]]--
function aulo.Load(basepath, searchpath)
    aulo.basepath   = basepath
    aulo.baseid     = basepath:Replace("/", ".")
    aulo.searchpath = searchpath or aulo.searchpath
    
    local _, folders = file.Find(basepath .. "/*", aulo.searchpath, "nameasc")
    
    -- Loop through each folder in the directory and begin recursively building the packages
    for _, folder in ipairs(folders) do
        aulo.LoadPackage(aulo.packages, basepath, folder, true)
    end
end
local BASE = "leopardrp_mapeditor/"

if SERVER then
    AddCSLuaFile(BASE .. "sh_core.lua")
    AddCSLuaFile(BASE .. "sh_surfaces.lua")
    AddCSLuaFile(BASE .. "cl_surfaces.lua")
end

include(BASE .. "sh_core.lua")
include(BASE .. "sh_surfaces.lua")

if SERVER then
    include(BASE .. "sv_surfaces.lua")
else
    include(BASE .. "cl_surfaces.lua")
end

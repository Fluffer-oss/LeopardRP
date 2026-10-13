LeopardRPMapEditor = LeopardRPMapEditor or {}
local MapEditor = LeopardRPMapEditor

MapEditor.NetSync = "lrp_mapedit_sync"
MapEditor.NetAction = "lrp_mapedit_action"

MapEditor.MaxOverrides = 500
MapEditor.MaxHistory = 50

-- Minimum distance (world units) between two overrides before Reset/Save will reject
-- an add as a near-duplicate of an existing entry picked by right-click removal.
MapEditor.RemoveSnapDistance = 24

function MapEditor.GetMapDataPath()
    return "leopardrp_mapeditor/surfaces/" .. game.GetMap() .. ".json"
end

-- Superadmin is always allowed. If this schema's own administration system is
-- loaded alongside this standalone addon, respect its "administrator" rank too,
-- without hard-depending on it existing.
function MapEditor.CanUseEditor(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end

    local admin = LeopardRP and LeopardRP.Administration
    if admin and admin.GetPermissionRank and admin.HasRankAtLeast then
        local rankID = admin.GetPermissionRank(ply:SteamID64())
        if admin.HasRankAtLeast(rankID, "administrator") then
            return true
        end
    end

    return false
end

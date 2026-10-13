local MapEditor = LeopardRPMapEditor

util.AddNetworkString(MapEditor.NetSync)
util.AddNetworkString(MapEditor.NetAction)

-- Global undo/redo history for the current map. Shared across every admin editing
-- at once, since the override set is shared world state, not per-player state.
local UndoStack = {}
local RedoStack = {}

local function SnapshotCurrentState()
    return MapEditor.SerializeSurfaceOverrides(MapEditor.SurfaceOverrides)
end

local function PushUndoSnapshot()
    table.insert(UndoStack, SnapshotCurrentState())
    if #UndoStack > MapEditor.MaxHistory then
        table.remove(UndoStack, 1)
    end
    RedoStack = {}
end

local function SaveToDisk()
    local relativePath = MapEditor.GetMapDataPath()
    file.CreateDir("leopardrp_mapeditor")
    file.CreateDir("leopardrp_mapeditor/surfaces")
    file.Write(relativePath, util.TableToJSON(SnapshotCurrentState(), true))
end

local function LoadFromDisk()
    local relativePath = MapEditor.GetMapDataPath()
    if not file.Exists(relativePath, "DATA") then
        MapEditor.SurfaceOverrides = {}
        return
    end

    local contents = file.Read(relativePath, "DATA")
    local list = util.JSONToTable(contents or "[]") or {}
    MapEditor.SurfaceOverrides = MapEditor.DeserializeSurfaceOverrides(list)
end

local function BroadcastSync(ply)
    net.Start(MapEditor.NetSync)
    net.WriteString(util.TableToJSON(SnapshotCurrentState()))
    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

local function RestoreSnapshot(list)
    MapEditor.SurfaceOverrides = MapEditor.DeserializeSurfaceOverrides(list)
    SaveToDisk()
    BroadcastSync()
end

local function CountOverrides()
    local count = 0
    for _ in pairs(MapEditor.SurfaceOverrides) do
        count = count + 1
    end
    return count
end

local function FindNearestOverride(pos, maxDistance)
    local nearestID, nearestDist = nil, maxDistance * maxDistance
    for id, entry in pairs(MapEditor.SurfaceOverrides) do
        local distSqr = entry.pos:DistToSqr(pos)
        if distSqr <= nearestDist then
            nearestID, nearestDist = id, distSqr
        end
    end
    return nearestID
end

local function HandleAdd(ply, payload)
    if CountOverrides() >= MapEditor.MaxOverrides then
        return false, "Reached the maximum number of surface overrides for this map."
    end

    local entry = MapEditor.SanitizeSurfaceEntry(payload.entry)
    if not entry then
        return false, "Invalid surface override payload."
    end

    entry.createdBy = ply:SteamID64()
    entry.createdAt = os.time()

    PushUndoSnapshot()
    MapEditor.SurfaceOverrides[entry.id] = entry
    SaveToDisk()
    BroadcastSync()

    return true, "Surface override saved."
end

local function HandleUpdate(ply, payload)
    local id = tostring(payload.id or "")
    if not MapEditor.SurfaceOverrides[id] then
        return false, "That override no longer exists."
    end

    local entry = MapEditor.SanitizeSurfaceEntry(payload.entry, id)
    if not entry then
        return false, "Invalid surface override payload."
    end

    entry.createdBy = MapEditor.SurfaceOverrides[id].createdBy
    entry.createdAt = MapEditor.SurfaceOverrides[id].createdAt

    PushUndoSnapshot()
    MapEditor.SurfaceOverrides[id] = entry
    SaveToDisk()
    BroadcastSync()

    return true, "Surface override updated."
end

local function HandleRemove(ply, payload)
    local id = tostring(payload.id or "")

    if not MapEditor.SurfaceOverrides[id] and payload.pos then
        local pos = payload.pos
        if istable(pos) then
            pos = Vector(tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
            id = FindNearestOverride(pos, MapEditor.RemoveSnapDistance) or id
        end
    end

    if not MapEditor.SurfaceOverrides[id] then
        return false, "No override found to remove there."
    end

    PushUndoSnapshot()
    MapEditor.SurfaceOverrides[id] = nil
    SaveToDisk()
    BroadcastSync()

    return true, "Surface override removed."
end

local function HandleReset(ply)
    PushUndoSnapshot()
    MapEditor.SurfaceOverrides = {}
    SaveToDisk()
    BroadcastSync()

    return true, "All surface overrides for this map have been cleared."
end

local function HandleUndo(ply)
    if #UndoStack == 0 then
        return false, "Nothing to undo."
    end

    table.insert(RedoStack, SnapshotCurrentState())
    local previous = table.remove(UndoStack)
    MapEditor.SurfaceOverrides = MapEditor.DeserializeSurfaceOverrides(previous)
    SaveToDisk()
    BroadcastSync()

    return true, "Undid last surface edit."
end

local function HandleRedo(ply)
    if #RedoStack == 0 then
        return false, "Nothing to redo."
    end

    table.insert(UndoStack, SnapshotCurrentState())
    local nextState = table.remove(RedoStack)
    MapEditor.SurfaceOverrides = MapEditor.DeserializeSurfaceOverrides(nextState)
    SaveToDisk()
    BroadcastSync()

    return true, "Redid surface edit."
end

local function HandleReload(ply)
    LoadFromDisk()
    UndoStack = {}
    RedoStack = {}
    BroadcastSync()

    return true, "Reloaded surface overrides from disk."
end

local Handlers = {
    add = HandleAdd,
    update = HandleUpdate,
    remove = HandleRemove,
    reset = HandleReset,
    undo = HandleUndo,
    redo = HandleRedo,
    reload = HandleReload
}

net.Receive(MapEditor.NetAction, function(_, ply)
    local payload = util.JSONToTable(net.ReadString() or "{}") or {}

    if not MapEditor.CanUseEditor(ply) then
        net.Start(MapEditor.NetAction)
        net.WriteString(util.TableToJSON({ ok = false, message = "You do not have permission to use the map editor." }))
        net.Send(ply)
        return
    end

    local handler = Handlers[tostring(payload.type or "")]
    if not handler then
        net.Start(MapEditor.NetAction)
        net.WriteString(util.TableToJSON({ ok = false, message = "Unknown map editor action." }))
        net.Send(ply)
        return
    end

    local ok, message = handler(ply, payload)

    net.Start(MapEditor.NetAction)
    net.WriteString(util.TableToJSON({ ok = ok, message = message }))
    net.Send(ply)
end)

hook.Add("PlayerInitialSpawn", "LeopardRPMapEditor.SyncOnJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            BroadcastSync(ply)
        end
    end)
end)

-- Load immediately: on a fresh map start this file is included before
-- Initialize fires anyway, and this also covers a mid-session Lua refresh.
LoadFromDisk()

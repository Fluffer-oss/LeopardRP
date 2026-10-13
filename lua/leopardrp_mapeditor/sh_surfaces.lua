local MapEditor = LeopardRPMapEditor

-- Committed, synced overrides: id -> entry
MapEditor.SurfaceOverrides = MapEditor.SurfaceOverrides or {}

local function CloneColor(color)
    color = istable(color) and color or {}
    return {
        r = math.Clamp(tonumber(color.r) or 255, 0, 255),
        g = math.Clamp(tonumber(color.g) or 255, 0, 255),
        b = math.Clamp(tonumber(color.b) or 255, 0, 255),
        a = math.Clamp(tonumber(color.a) or 255, 0, 255)
    }
end

-- Builds/validates a surface override entry from loosely-typed input (net payload
-- or a JSON-decoded file row). Returns nil if the entry is not usable.
function MapEditor.SanitizeSurfaceEntry(raw, existingID)
    raw = istable(raw) and raw or {}

    local pos = raw.pos
    if istable(pos) then
        pos = Vector(tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
    end
    if not isvector(pos) then return nil end

    local normal = raw.normal
    if istable(normal) then
        normal = Vector(tonumber(normal.x) or 0, tonumber(normal.y) or 0, tonumber(normal.z) or 1)
    end
    if not isvector(normal) or normal:LengthSqr() < 0.01 then
        normal = Vector(0, 0, 1)
    end
    normal:Normalize()

    local material = tostring(raw.material or "")
    if material == "" then return nil end

    return {
        id = tostring(existingID or raw.id or util.CRC(tostring(SysTime()) .. tostring(math.random(1, 999999)))),
        pos = pos,
        normal = normal,
        rotation = math.Clamp(tonumber(raw.rotation) or 0, 0, 360),
        width = math.Clamp(tonumber(raw.width) or 32, 1, 512),
        height = math.Clamp(tonumber(raw.height) or 32, 1, 512),
        offset = math.Clamp(tonumber(raw.offset) or 0.3, 0, 8),
        material = material,
        color = CloneColor(raw.color),
        originalTexture = tostring(raw.originalTexture or ""),
        createdBy = tostring(raw.createdBy or ""),
        createdAt = tonumber(raw.createdAt) or os.time()
    }
end

function MapEditor.SurfaceEntryToTable(entry)
    return {
        id = entry.id,
        pos = { x = entry.pos.x, y = entry.pos.y, z = entry.pos.z },
        normal = { x = entry.normal.x, y = entry.normal.y, z = entry.normal.z },
        rotation = entry.rotation,
        width = entry.width,
        height = entry.height,
        offset = entry.offset,
        material = entry.material,
        color = entry.color,
        originalTexture = entry.originalTexture,
        createdBy = entry.createdBy,
        createdAt = entry.createdAt
    }
end

function MapEditor.SerializeSurfaceOverrides(overrides)
    local list = {}
    for _, entry in pairs(overrides) do
        table.insert(list, MapEditor.SurfaceEntryToTable(entry))
    end
    return list
end

function MapEditor.DeserializeSurfaceOverrides(list)
    local overrides = {}
    if not istable(list) then return overrides end

    for _, raw in ipairs(list) do
        local entry = MapEditor.SanitizeSurfaceEntry(raw, raw.id)
        if entry then
            overrides[entry.id] = entry
        end
    end

    return overrides
end

-- Shared so both the authoritative server state and the client's local preview
-- can be rendered with identical geometry.
function MapEditor.BuildSurfaceQuadCorners(entry)
    local baseAngle = entry.normal:Angle()
    baseAngle.roll = entry.rotation

    local right = baseAngle:Right()
    local up = baseAngle:Up()
    local offsetPos = entry.pos + entry.normal * entry.offset

    local halfW = entry.width * 0.5
    local halfH = entry.height * 0.5

    return {
        offsetPos - right * halfW - up * halfH,
        offsetPos - right * halfW + up * halfH,
        offsetPos + right * halfW + up * halfH,
        offsetPos + right * halfW - up * halfH
    }
end

LeopardRP = LeopardRP or {}
LeopardRP.GameMaster = LeopardRP.GameMaster or {}

local GM = LeopardRP.GameMaster

local FORCED_OWNER_STEAMID64 = tostring((LeopardRP.Personnel and LeopardRP.Personnel.ForcedOwnerSteamID64) or "76561199122465449")

local TABLE_PERMISSIONS = "leopardrp_gm_permissions"
local TABLE_LOGS = "leopardrp_gm_logs"
local TABLE_EVENT_CHARACTERS = "leopardrp_gm_event_characters"

GM.ActiveSessions = GM.ActiveSessions or {}
GM.PermissionCache = GM.PermissionCache or {}

local function EnsureTables()
    sql.Query(string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            steamid64 TEXT PRIMARY KEY,
            rank_id TEXT NOT NULL DEFAULT 'none',
            updated_by TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT 0
        )
    ]], TABLE_PERMISSIONS))

    sql.Query(string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            steamid64 TEXT NOT NULL,
            steam_name TEXT NOT NULL,
            character_name TEXT NOT NULL,
            gm_rank TEXT NOT NULL,
            action TEXT NOT NULL,
            target_steamid64 TEXT NOT NULL,
            target_name TEXT NOT NULL,
            details_json TEXT NOT NULL,
            date_text TEXT NOT NULL,
            time_text TEXT NOT NULL,
            stardate_text TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0
        )
    ]], TABLE_LOGS))

    sql.Query(string.format([[
        CREATE TABLE IF NOT EXISTS %s (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            owner_steamid64 TEXT NOT NULL,
            character_name TEXT NOT NULL,
            species TEXT NOT NULL,
            gender TEXT NOT NULL,
            body_id TEXT NOT NULL,
            head_id TEXT NOT NULL,
            skin TEXT NOT NULL,
            bodygroups_json TEXT NOT NULL,
            model_path TEXT NOT NULL,
            bone_merge INTEGER NOT NULL DEFAULT 0,
            payload_json TEXT NOT NULL,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
        )
    ]], TABLE_EVENT_CHARACTERS))
end

local function LoadPermissionCache()
    GM.PermissionCache = {}

    local rows = sql.Query(string.format("SELECT steamid64, rank_id FROM %s", TABLE_PERMISSIONS))
    if not istable(rows) then return end

    for _, row in ipairs(rows) do
        local steamID64 = tostring(row.steamid64 or "")
        if steamID64 ~= "" then
            GM.PermissionCache[steamID64] = GM.NormalizeRank(row.rank_id)
        end
    end
end

function GM.GetPermissionRank(steamID64)
    steamID64 = tostring(steamID64 or "")
    if steamID64 == "" then
        return "none"
    end

    if steamID64 == FORCED_OWNER_STEAMID64 then
        return "chief_game_master"
    end

    return GM.NormalizeRank(GM.PermissionCache[steamID64])
end

function GM.SetPermissionRank(steamID64, rankID, updatedBy)
    steamID64 = tostring(steamID64 or "")
    if steamID64 == "" then
        return false
    end

    if steamID64 == FORCED_OWNER_STEAMID64 then
        rankID = "chief_game_master"
    end

    rankID = GM.NormalizeRank(rankID)
    GM.PermissionCache[steamID64] = rankID

    local query = string.format(
        "REPLACE INTO %s (steamid64, rank_id, updated_by, updated_at) VALUES ('%s', '%s', '%s', %d)",
        TABLE_PERMISSIONS,
        sql.SQLStr(steamID64, true),
        sql.SQLStr(rankID, true),
        sql.SQLStr(tostring(updatedBy or "system"), true),
        os.time()
    )
    sql.Query(query)

    return true
end

function GM.IsClockedIn(ply)
    if not IsValid(ply) then return false end

    local session = GM.ActiveSessions[tostring(ply:SteamID64() or "")]
    return istable(session) and session.clockedIn == true
end

function GM.HasPermission(ply, requiredRank)
    if not IsValid(ply) then return false end

    local rankID = GM.GetPermissionRank(ply:SteamID64())
    if not GM.HasRankAtLeast(rankID, requiredRank or "game_master") then
        return false
    end

    return GM.IsClockedIn(ply)
end

EnsureTables()
LoadPermissionCache()

local function SQLSafe(value)
    return sql.SQLStr(tostring(value or ""), true)
end

local function SerializeTable(value)
    return util.TableToJSON(value or {}, false) or "{}"
end

local function DeserializeTable(value)
    return util.JSONToTable(value or "{}") or {}
end

local function GetStardateText()
    local now = os.time()
    local stardate = (now / 86400) + 100000
    return string.format("%.2f", stardate)
end

local function GetCharacterName(ply)
    if not IsValid(ply) then
        return "Unknown"
    end

    if isfunction(ply.getDarkRPVar) then
        local rpName = ply:getDarkRPVar("rpname")
        if isstring(rpName) and rpName ~= "" then
            return rpName
        end
    end

    return tostring(ply:Nick() or "Unknown")
end

local function LogAction(ply, actionID, targetPly, details)
    if not IsValid(ply) then return end

    local steamID64 = tostring(ply:SteamID64() or "")
    local rankID = GM.GetPermissionRank(steamID64)
    local timestamp = os.time()
    local row = {
        steamid64 = steamID64,
        steam_name = ply:Nick(),
        character_name = GetCharacterName(ply),
        gm_rank = rankID,
        action = tostring(actionID or "unknown"),
        target_steamid64 = IsValid(targetPly) and targetPly:SteamID64() or "",
        target_name = IsValid(targetPly) and targetPly:Nick() or "",
        details_json = SerializeTable(details),
        date_text = os.date("%Y-%m-%d", timestamp),
        time_text = os.date("%H:%M:%S", timestamp),
        stardate_text = GetStardateText(),
        created_at = timestamp,
    }

    local query = string.format(
        "INSERT INTO %s (steamid64, steam_name, character_name, gm_rank, action, target_steamid64, target_name, details_json, date_text, time_text, stardate_text, created_at) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d)",
        TABLE_LOGS,
        SQLSafe(row.steamid64),
        SQLSafe(row.steam_name),
        SQLSafe(row.character_name),
        SQLSafe(row.gm_rank),
        SQLSafe(row.action),
        SQLSafe(row.target_steamid64),
        SQLSafe(row.target_name),
        SQLSafe(row.details_json),
        SQLSafe(row.date_text),
        SQLSafe(row.time_text),
        SQLSafe(row.stardate_text),
        tonumber(row.created_at) or 0
    )

    sql.Query(query)
    hook.Run("LeopardRP.GMLogCreated", row)
end

local function CountSessionActions(steamID64, startedAt)
    local query = string.format(
        "SELECT COUNT(id) as count_value FROM %s WHERE steamid64 = '%s' AND created_at >= %d",
        TABLE_LOGS,
        SQLSafe(steamID64),
        tonumber(startedAt) or 0
    )

    local rows = sql.Query(query)
    if istable(rows) and rows[1] then
        return tonumber(rows[1].count_value) or 0
    end

    return 0
end

local function WritePayload(netString, ply, payload)
    net.Start(netString)
    net.WriteString(SerializeTable(payload))
    net.Send(ply)
end

local function GetClockStatusPayload(ply)
    local steamID64 = ply:SteamID64()
    local rankID = GM.GetPermissionRank(steamID64)
    local session = GM.ActiveSessions[steamID64]

    return {
        rankID = rankID,
        rankName = GM.GetRankDefinition(rankID).Name,
        clockedIn = session and session.clockedIn == true or false,
        sessionStartedAt = session and session.startedAt or 0,
        canManageGMs = GM.HasRankAtLeast(rankID, "chief_game_master")
    }
end

local function FetchEventCharacters(ownerSteamID64)
    local query = string.format("SELECT * FROM %s WHERE owner_steamid64 = '%s' ORDER BY id DESC LIMIT 150", TABLE_EVENT_CHARACTERS, SQLSafe(ownerSteamID64))
    local rows = sql.Query(query)
    if not istable(rows) then return {} end

    local output = {}
    for _, row in ipairs(rows) do
        table.insert(output, {
            id = tonumber(row.id) or 0,
            name = tostring(row.character_name or "Unknown"),
            species = tostring(row.species or ""),
            gender = tostring(row.gender or ""),
            modelPath = tostring(row.model_path or ""),
            boneMerge = tonumber(row.bone_merge or 0) == 1,
            payload = DeserializeTable(row.payload_json)
        })
    end

    return output
end

local function FindPlayerBySteamID64(steamID64)
    for _, candidate in ipairs(player.GetAll()) do
        if candidate:SteamID64() == steamID64 then
            return candidate
        end
    end

    return nil
end

local function GetEventCharacterByID(actorPly, charID)
    local actorRank = GM.GetPermissionRank(actorPly:SteamID64())
    local ownsAll = GM.HasRankAtLeast(actorRank, "chief_game_master")
    local query

    if ownsAll then
        query = string.format("SELECT * FROM %s WHERE id = %d LIMIT 1", TABLE_EVENT_CHARACTERS, tonumber(charID) or 0)
    else
        query = string.format("SELECT * FROM %s WHERE id = %d AND owner_steamid64 = '%s' LIMIT 1", TABLE_EVENT_CHARACTERS, tonumber(charID) or 0, SQLSafe(actorPly:SteamID64()))
    end

    local rows = sql.Query(query)
    if not istable(rows) or not rows[1] then
        return nil
    end

    return rows[1]
end

local function ResolveHeadModel(payload)
    local headID = tostring(payload.headID or "")
    local species = tostring(payload.species or "Human")
    if headID == "" then return "" end

    if util.IsValidModel(headID) then
        return headID
    end

    local index = tonumber(headID)
    if index and LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.GetHeadModels then
        local list = LeopardRP.CharacterCreation.GetHeadModels(species)
        if istable(list) then
            return tostring(list[index] or "")
        end
    end

    return ""
end

local function ResolveBodyModel(payload)
    local bodyID = tostring(payload.bodyID or "")
    if bodyID ~= "" and util.IsValidModel(bodyID) then
        return bodyID
    end

    local modelPath = tostring(payload.modelPath or "")
    if modelPath ~= "" and util.IsValidModel(modelPath) then
        return modelPath
    end

    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.GetBodyModel then
        local division = tostring(payload.division or "Operations")
        local gender = tostring(payload.gender or "Male")
        local uniformType = tostring(payload.uniformType or "Standard")
        return tostring(LeopardRP.CharacterCreation.GetBodyModel(division, gender, uniformType) or "")
    end

    return ""
end

local function ApplyBodygroupsToEntity(entity, bodygroups)
    if not IsValid(entity) or not istable(bodygroups) then return end

    for key, value in pairs(bodygroups) do
        local targetIndex = tonumber(key)
        if not targetIndex and entity.FindBodygroupByName and isstring(key) then
            targetIndex = entity:FindBodygroupByName(key)
        end

        if targetIndex and targetIndex >= 0 then
            entity:SetBodygroup(targetIndex, math.max(0, tonumber(value) or 0))
        end
    end
end

local function ApplyEventCharacterToPlayer(actorPly, targetPly, eventRow)
    if not IsValid(targetPly) then return false, "Target player is invalid." end

    local payload = DeserializeTable(eventRow.payload_json)
    local useBoneMerge = payload.boneMerge == true
    local bodyModel = ResolveBodyModel(payload)
    local headModel = ResolveHeadModel(payload)
    local skin = math.max(0, tonumber(payload.skin) or 0)
    local bodygroups = payload.bodygroups
    if not istable(bodygroups) then
        bodygroups = DeserializeTable(eventRow.bodygroups_json)
    end

    if bodyModel == "" or not util.IsValidModel(bodyModel) then
        return false, "Event character body model is invalid."
    end

    if not targetPly.LeopardRP_PreEventCharacterState then
        targetPly.LeopardRP_PreEventCharacterState = {
            model = targetPly:GetModel(),
            skin = targetPly:GetSkin(),
            bodygroups = {}
        }

        for _, bg in ipairs(targetPly:GetBodyGroups() or {}) do
            targetPly.LeopardRP_PreEventCharacterState.bodygroups[tonumber(bg.id) or 0] = targetPly:GetBodygroup(tonumber(bg.id) or 0)
        end
    end

    targetPly:SetModel(bodyModel)
    targetPly:SetSkin(skin)
    ApplyBodygroupsToEntity(targetPly, bodygroups or {})

    if targetPly.SetupHands then
        targetPly:SetupHands()
        timer.Simple(0, function()
            if IsValid(targetPly) and targetPly.SetupHands then
                targetPly:SetupHands()
            end
        end)
    end

    if useBoneMerge and headModel ~= "" and LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.ApplyHeadToPlayer then
        LeopardRP.CharacterCreation.ApplyHeadToPlayer(targetPly, headModel)
    elseif LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.RemoveHeadFromPlayer then
        LeopardRP.CharacterCreation.RemoveHeadFromPlayer(targetPly)
    end

    targetPly:SetNWBool("LeopardRP.EventCharacter.Active", true)
    targetPly:SetNWString("LeopardRP.EventCharacter.ID", tostring(eventRow.id or ""))
    targetPly:SetNWString("LeopardRP.EventCharacter.Name", tostring(eventRow.character_name or payload.name or "Event Character"))
    targetPly:SetNWString("LeopardRP.EventCharacter.Owner", tostring(eventRow.owner_steamid64 or ""))

    LogAction(actorPly, "apply_event_character", targetPly, {
        eventCharacterID = tonumber(eventRow.id) or 0,
        eventCharacterName = tostring(eventRow.character_name or "Event Character")
    })

    return true
end

local function SpawnEventCharacterEntity(actorPly, eventRow)
    local payload = DeserializeTable(eventRow.payload_json)
    local bodyModel = ResolveBodyModel(payload)
    if bodyModel == "" or not util.IsValidModel(bodyModel) then
        return false, "Event character body model is invalid."
    end

    local trace = actorPly:GetEyeTrace()
    local spawnPos = trace.HitPos + Vector(0, 0, 12)
    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then
        return false, "Failed to spawn event entity."
    end

    ent:SetModel(bodyModel)
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, actorPly:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()
    ent:SetSkin(math.max(0, tonumber(payload.skin) or 0))
    ApplyBodygroupsToEntity(ent, payload.bodygroups or {})

    local headModel = ResolveHeadModel(payload)
    if payload.boneMerge == true and headModel ~= "" and util.IsValidModel(headModel) then
        local head = ents.Create("prop_dynamic")
        if IsValid(head) then
            head:SetModel(headModel)
            head:SetPos(spawnPos)
            head:SetAngles(ent:GetAngles())
            head:SetMoveType(MOVETYPE_NONE)
            head:SetSolid(SOLID_NONE)
            head:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            head:Spawn()
            head:Activate()
            head:SetParent(ent, 0)
            head:AddEffects(EF_BONEMERGE)
            head:AddEffects(EF_BONEMERGE_FASTCULL)
        end
    end

    LogAction(actorPly, "spawn_event_character", nil, {
        eventCharacterID = tonumber(eventRow.id) or 0,
        entityModel = bodyModel
    })

    return true
end

local function FetchLogs(limit)
    local query = string.format("SELECT * FROM %s ORDER BY id DESC LIMIT %d", TABLE_LOGS, math.Clamp(tonumber(limit) or 100, 10, 300))
    local rows = sql.Query(query)
    if not istable(rows) then return {} end

    local output = {}
    for _, row in ipairs(rows) do
        table.insert(output, {
            steamName = tostring(row.steam_name or "Unknown"),
            steamID64 = tostring(row.steamid64 or ""),
            characterName = tostring(row.character_name or "Unknown"),
            gmRank = tostring(row.gm_rank or "none"),
            action = tostring(row.action or "unknown"),
            targetName = tostring(row.target_name or ""),
            targetSteamID64 = tostring(row.target_steamid64 or ""),
            details = DeserializeTable(row.details_json),
            date = tostring(row.date_text or ""),
            time = tostring(row.time_text or ""),
            stardate = tostring(row.stardate_text or "")
        })
    end

    return output
end

local function BuildOnlinePlayers()
    local list = {}
    for _, ply in ipairs(player.GetAll()) do
        table.insert(list, {
            steamID64 = ply:SteamID64(),
            name = ply:Nick(),
            characterName = GetCharacterName(ply)
        })
    end
    table.sort(list, function(a, b)
        return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
    end)
    return list
end

local Notify
local Success

Notify = function(ply, text)
    WritePayload(GM.NetworkStrings.ActionResult, ply, { ok = false, message = tostring(text or "Unable to complete request.") })
end

Success = function(ply, text)
    WritePayload(GM.NetworkStrings.ActionResult, ply, { ok = true, message = tostring(text or "Completed.") })
end

local function HandleClockToggle(ply, shouldClockIn)
    local rankID = GM.GetPermissionRank(ply:SteamID64())
    if rankID == "none" then
        return Notify(ply, "You do not have a Game Master rank.")
    end

    local steamID64 = ply:SteamID64()
    local now = os.time()

    if shouldClockIn then
        GM.ActiveSessions[steamID64] = {
            clockedIn = true,
            startedAt = now
        }

        LogAction(ply, "clock_in", nil, { rankID = rankID })
        Success(ply, "Clocked in to Game Master duty.")

        if IsValid(ply) then
            if not ply:HasWeapon("weapon_physgun") then
                ply:Give("weapon_physgun")
            end
            if not ply:HasWeapon("gmod_tool") then
                ply:Give("gmod_tool")
            end
        end
    else
        local session = GM.ActiveSessions[steamID64]
        local duration = session and math.max(0, now - (tonumber(session.startedAt) or now)) or 0
        GM.ActiveSessions[steamID64] = nil
        LogAction(ply, "clock_out", nil, { sessionLengthSeconds = duration })
        Success(ply, "Clocked out of Game Master duty.")

        if IsValid(ply) then
            if ply:HasWeapon("weapon_physgun") then
                ply:StripWeapon("weapon_physgun")
            end
            if ply:HasWeapon("gmod_tool") then
                ply:StripWeapon("gmod_tool")
            end
            if ply:HasWeapon("gmod_tool") then
                ply:StripWeapon("gmod_tool")
            end
        end
    end

    WritePayload(GM.NetworkStrings.ClockStatus, ply, GetClockStatusPayload(ply))
end

local function HandleSetRank(ply, payload)
    local actorRank = GM.GetPermissionRank(ply:SteamID64())
    if not GM.HasRankAtLeast(actorRank, "chief_game_master") then
        return Notify(ply, "You do not have permission to manage Game Masters.")
    end

    local targetSteamID64 = tostring(payload.targetSteamID64 or "")
    if targetSteamID64 == "" then
        return Notify(ply, "Invalid target SteamID64.")
    end

    local targetRank = GM.NormalizeRank(payload.rankID)
    GM.SetPermissionRank(targetSteamID64, targetRank, ply:Nick())
    LogAction(ply, "set_gm_rank", nil, { targetSteamID64 = targetSteamID64, rankID = targetRank })
    Success(ply, "Updated Game Master rank.")
end

local function HandleEventCharacterCreate(ply, payload)
    if not GM.HasPermission(ply, "game_master") then
        return Notify(ply, "You must be clocked in as Game Master.")
    end

    local now = os.time()
    local steamID64 = ply:SteamID64()
    local name = string.Trim(tostring(payload.name or ""))
    if name == "" then
        return Notify(ply, "Character name is required.")
    end

    local query = string.format(
        "INSERT INTO %s (owner_steamid64, character_name, species, gender, body_id, head_id, skin, bodygroups_json, model_path, bone_merge, payload_json, created_at, updated_at) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d, '%s', %d, %d)",
        TABLE_EVENT_CHARACTERS,
        SQLSafe(steamID64),
        SQLSafe(name),
        SQLSafe(payload.species or "Human"),
        SQLSafe(payload.gender or "Male"),
        SQLSafe(payload.bodyID or ""),
        SQLSafe(payload.headID or ""),
        SQLSafe(payload.skin or "0"),
        SQLSafe(SerializeTable(payload.bodygroups or {})),
        SQLSafe(payload.modelPath or ""),
        payload.boneMerge and 1 or 0,
        SQLSafe(SerializeTable(payload)),
        now,
        now
    )

    sql.Query(query)
    LogAction(ply, "create_event_character", nil, { characterName = name })
    Success(ply, "Event character saved.")
end

local function HandleEventCharacterDelete(ply, payload)
    if not GM.HasPermission(ply, "game_master") then
        return Notify(ply, "You must be clocked in as Game Master.")
    end

    local charID = tonumber(payload.id) or 0
    if charID <= 0 then
        return Notify(ply, "Invalid event character.")
    end

    local query = string.format("DELETE FROM %s WHERE id = %d AND owner_steamid64 = '%s'", TABLE_EVENT_CHARACTERS, charID, SQLSafe(ply:SteamID64()))
    sql.Query(query)

    LogAction(ply, "delete_event_character", nil, { id = charID })
    Success(ply, "Event character deleted.")
end

local function HandleEventCharacterDeploy(ply, payload)
    if not GM.HasPermission(ply, "game_master") then
        return Notify(ply, "You must be clocked in as Game Master.")
    end

    local charID = tonumber(payload.id) or 0
    if charID <= 0 then
        return Notify(ply, "Invalid event character.")
    end

    local eventRow = GetEventCharacterByID(ply, charID)
    if not eventRow then
        return Notify(ply, "Event character not found.")
    end

    local deployMode = tostring(payload.deployMode or "apply")
    if deployMode == "spawn" then
        local ok, message = SpawnEventCharacterEntity(ply, eventRow)
        if not ok then
            return Notify(ply, message or "Failed to spawn event character.")
        end

        return Success(ply, "Spawned event character entity.")
    end

    local targetSteamID64 = tostring(payload.targetSteamID64 or ply:SteamID64())
    local targetPly = FindPlayerBySteamID64(targetSteamID64)
    local ok, message = ApplyEventCharacterToPlayer(ply, targetPly, eventRow)
    if not ok then
        return Notify(ply, message or "Failed to apply event character.")
    end

    Success(ply, "Event character applied.")
end

local function HandleUtilityAction(ply, payload)
    if not GM.HasPermission(ply, "game_master") then
        return Notify(ply, "You must be clocked in as Game Master.")
    end

    local actionID = tostring(payload.actionID or "")
    local targetSteamID64 = tostring(payload.targetSteamID64 or "")
    local targetPly = nil

    if targetSteamID64 ~= "" then
        for _, candidate in ipairs(player.GetAll()) do
            if candidate:SteamID64() == targetSteamID64 then
                targetPly = candidate
                break
            end
        end
    end

    if actionID == "teleport_to" and IsValid(targetPly) then
        ply:SetPos(targetPly:GetPos() + Vector(0, 0, 6))
    elseif actionID == "bring_player" and IsValid(targetPly) then
        targetPly.LeopardRP_LastGMReturnPos = targetPly:GetPos()
        targetPly:SetPos(ply:GetPos() + ply:GetForward() * 48)
    elseif actionID == "return_player" and IsValid(targetPly) and targetPly.LeopardRP_LastGMReturnPos then
        targetPly:SetPos(targetPly.LeopardRP_LastGMReturnPos)
    elseif actionID == "freeze_player" and IsValid(targetPly) then
        targetPly:Freeze(true)
    elseif actionID == "unfreeze_player" and IsValid(targetPly) then
        targetPly:Freeze(false)
    elseif actionID == "cleanup_event_props" then
        game.CleanUpMap(false, { "prop_physics", "prop_dynamic" })
    elseif actionID == "cleanup_event_npcs" then
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:IsNPC() then
                ent:Remove()
            end
        end
    elseif actionID == "cleanup_entire_event" then
        game.CleanUpMap(false)
    end

    LogAction(ply, actionID, targetPly, { targetSteamID64 = targetSteamID64 })
    Success(ply, "Event utility executed.")
end

local function HandleSubmitAction(ply)
    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local actionType = tostring(payload.type or "")

    if actionType == "clock_toggle" then
        return HandleClockToggle(ply, tobool(payload.clockIn))
    end

    if actionType == "set_rank" then
        return HandleSetRank(ply, payload)
    end

    if actionType == "create_event_character" then
        return HandleEventCharacterCreate(ply, payload)
    end

    if actionType == "delete_event_character" then
        return HandleEventCharacterDelete(ply, payload)
    end

    if actionType == "deploy_event_character" then
        return HandleEventCharacterDeploy(ply, payload)
    end

    if actionType == "utility_action" then
        return HandleUtilityAction(ply, payload)
    end

    Notify(ply, "Unknown Game Master action.")
end

local function SendInitialData(ply)
    local payload = {
        clock = GetClockStatusPayload(ply),
        onlinePlayers = BuildOnlinePlayers(),
        eventCharacters = FetchEventCharacters(ply:SteamID64()),
        logs = FetchLogs(GM.HasPermission(ply, "chief_game_master") and 200 or 40),
        gmRanks = GM.Ranks,
    }

    WritePayload(GM.NetworkStrings.ReceiveInitialData, ply, payload)
end

net.Receive(GM.NetworkStrings.RequestOpenMenu, function(_, ply)
    if GM.GetPermissionRank(ply:SteamID64()) == "none" then
        return Notify(ply, "No Game Master permissions assigned.")
    end

    net.Start(GM.NetworkStrings.OpenMenu)
    net.Send(ply)
end)

net.Receive(GM.NetworkStrings.RequestInitialData, function(_, ply)
    if GM.GetPermissionRank(ply:SteamID64()) == "none" then
        return Notify(ply, "No Game Master permissions assigned.")
    end

    SendInitialData(ply)
end)

net.Receive(GM.NetworkStrings.ClockToggle, function(_, ply)
    local shouldClockIn = net.ReadBool()
    HandleClockToggle(ply, shouldClockIn)
end)

net.Receive(GM.NetworkStrings.SubmitAction, function(_, ply)
    HandleSubmitAction(ply)
    SendInitialData(ply)
end)

hook.Add("PlayerDisconnected", "LeopardRP.GM.ClockOutOnDisconnect", function(ply)
    if not IsValid(ply) then return end
    if not GM.ActiveSessions[ply:SteamID64()] then return end

    local now = os.time()
    local startedAt = tonumber(GM.ActiveSessions[ply:SteamID64()].startedAt) or now
    local duration = math.max(0, now - startedAt)
    LogAction(ply, "clock_out", nil, { sessionLengthSeconds = duration, disconnect = true })
    GM.ActiveSessions[ply:SteamID64()] = nil
end)

local BASIC_COMMAND_TOOL_ALLOWLIST = {
    remover = true,
    weld = true,
    axis = true,
    nocollide = true,
    rope = true,
    material = true,
    color = true
}

local function IsCommandStaffBuilder(ply)
    if not IsValid(ply) then return false end
    if not (LeopardRP.Personnel and LeopardRP.Personnel.GetPlayerRankOrder) then return false end
    local minOrder = tonumber(LeopardRP.Config.CommandStaffMinimumRankOrder) or 12
    return (LeopardRP.Personnel.GetPlayerRankOrder(ply) or 0) >= minOrder
end

local function HasAdminNoClip(ply)
    if not (LeopardRP.Personnel and LeopardRP.Personnel.CanAccessAdminPanel) then
        return false
    end

    return LeopardRP.Personnel.CanAccessAdminPanel(ply)
end

local function CanUseNoClip(ply)
    if not IsValid(ply) then
        return false
    end

    local gmRank = GM.GetPermissionRank(ply:SteamID64())
    if GM.IsClockedIn(ply) and GM.HasRankAtLeast(gmRank, "game_master") then
        return true
    end

    return HasAdminNoClip(ply)
end

local function CanUseStaffWeapons(ply)
    if not IsValid(ply) then
        return false
    end

    local gmRank = GM.GetPermissionRank(ply:SteamID64())
    if GM.IsClockedIn(ply) and GM.HasRankAtLeast(gmRank, "game_master") then
        return true
    end

    if LeopardRP.Personnel and LeopardRP.Personnel.CanAccessAdminPanel and LeopardRP.Personnel.CanAccessAdminPanel(ply) then
        return true
    end

    return false
end

hook.Add("PlayerNoClip", "LeopardRP.GMAndAdminNoClip", function(ply)
    if not IsValid(ply) then return end

    if CanUseNoClip(ply) then
        return true
    end

    return false
end)

hook.Add("Think", "LeopardRP.GMAndAdminNoClipHardDeny", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NOCLIP and not CanUseNoClip(ply) then
            ply:SetMoveType(MOVETYPE_WALK)
        end
    end
end)

hook.Add("CanTool", "LeopardRP.GMAndCommandToolRules", function(ply, _, toolMode)
    if not IsValid(ply) then return end

    if CanUseStaffWeapons(ply) then
        return true
    end

    if Star_Trek and Star_Trek.Holodeck and Star_Trek.Holodeck.IsPlayerInHolodeck and Star_Trek.Holodeck:IsPlayerInHolodeck(ply) then
        return true
    end

    return false
end)

local function GMCanBuild(ply)
    local gmRank = GM.GetPermissionRank(ply:SteamID64())
    return GM.IsClockedIn(ply) and GM.HasRankAtLeast(gmRank, "game_master")
end

local function PlayerShouldHaveToolgun(ply)
    if not IsValid(ply) then return false end
    return CanUseStaffWeapons(ply)
end

hook.Add("PlayerSpawn", "LeopardRP.GM.ToolgunLoadoutPolicy", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        if PlayerShouldHaveToolgun(ply) then
            if not ply:HasWeapon("weapon_physgun") then
                ply:Give("weapon_physgun")
            end
            if not ply:HasWeapon("gmod_tool") then
                ply:Give("gmod_tool")
            end
            return
        end

        if ply:HasWeapon("weapon_physgun") then
            ply:StripWeapon("weapon_physgun")
        end
        if ply:HasWeapon("gmod_tool") then
            ply:StripWeapon("gmod_tool")
        end
        if ply:HasWeapon("gmod_tool") then
            ply:StripWeapon("gmod_tool")
        end
    end)
end)

hook.Add("PlayerSpawnProp", "LeopardRP.GMSpawnProp", function(ply)
    if GMCanBuild(ply) then
        LogAction(ply, "spawn_prop")
        return true
    end

	return false
end)

hook.Add("PlayerSpawnSENT", "LeopardRP.GMSpawnSENT", function(ply)
    if GMCanBuild(ply) then
        LogAction(ply, "spawn_sent")
        return true
    end

	return false
end)

hook.Add("PlayerSpawnNPC", "LeopardRP.GMSpawnNPC", function(ply)
    if GMCanBuild(ply) then
        LogAction(ply, "spawn_npc")
        return true
    end

    return false
end)

hook.Add("PlayerSpawnVehicle", "LeopardRP.GMSpawnVehicle", function(ply)
    if GMCanBuild(ply) then
        LogAction(ply, "spawn_vehicle")
        return true
    end

    return false
end)

hook.Add("PlayerSpawnEffect", "LeopardRP.GMSpawnEffect", function(ply)
    if GMCanBuild(ply) then
        LogAction(ply, "spawn_effect")
        return true
    end

    return false
end)

hook.Add("PlayerSpawnSWEP", "LeopardRP.GMSpawnSWEP", function(ply)
    if CanUseStaffWeapons(ply) then
        LogAction(ply, "spawn_swep")
        return true
    end

    return false
end)

hook.Add("PlayerGiveSWEP", "LeopardRP.GMGiveSWEP", function(ply)
    if CanUseStaffWeapons(ply) then
        LogAction(ply, "give_swep")
        return true
    end

    return false
end)

hook.Add("PlayerCanPickupWeapon", "LeopardRP.GMPickupSWEP", function(ply)
    if CanUseStaffWeapons(ply) then
        return true
    end
end)

hook.Add("PhysgunPickup", "LeopardRP.GMPhysgunPickup", function(ply)
    if CanUseStaffWeapons(ply) then
        return true
    end

    if Star_Trek and Star_Trek.Holodeck and Star_Trek.Holodeck.IsPlayerInHolodeck and Star_Trek.Holodeck:IsPlayerInHolodeck(ply) then
        return true
    end
end)

hook.Add("CanPlayerHoldObject", "LeopardRP.GMCanHoldObject", function(ply)
    if CanUseStaffWeapons(ply) then
        return true
    end

    if Star_Trek and Star_Trek.Holodeck and Star_Trek.Holodeck.IsPlayerInHolodeck and Star_Trek.Holodeck:IsPlayerInHolodeck(ply) then
        return true
    end
end)

hook.Add("PhysgunReload", "LeopardRP.GMPhysgunReload", function(_, ply)
    if CanUseStaffWeapons(ply) then
        return true
    end

    if Star_Trek and Star_Trek.Holodeck and Star_Trek.Holodeck.IsPlayerInHolodeck and Star_Trek.Holodeck:IsPlayerInHolodeck(ply) then
        return true
    end
end)

hook.Add("CanPlayerUnfreeze", "LeopardRP.GMCanUnfreeze", function(ply)
    if CanUseStaffWeapons(ply) then
        return true
    end

    if Star_Trek and Star_Trek.Holodeck and Star_Trek.Holodeck.IsPlayerInHolodeck and Star_Trek.Holodeck:IsPlayerInHolodeck(ply) then
        return true
    end
end)

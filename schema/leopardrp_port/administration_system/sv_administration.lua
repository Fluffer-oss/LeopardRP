LeopardRP = LeopardRP or {}
LeopardRP.Administration = LeopardRP.Administration or {}

local Admin = LeopardRP.Administration

local FORCED_OWNER_STEAMID64 = tostring((LeopardRP.Personnel and LeopardRP.Personnel.ForcedOwnerSteamID64) or "76561199122465449")

local TABLE_PERMISSIONS = "leopardrp_admin_permissions"
local TABLE_LOGS = "leopardrp_admin_logs"
local TABLE_PUNISHMENTS = "leopardrp_admin_punishments"
local TABLE_RULEBOOK = "leopardrp_admin_rulebook"
local TABLE_GUIDELINES = "leopardrp_admin_guidelines"

Admin.ActiveSessions = Admin.ActiveSessions or {}
Admin.PunishmentStates = Admin.PunishmentStates or {
    muted = {},
    gagged = {},
    jailed = {}
}
Admin.MovementStates = Admin.MovementStates or {
    staffReturn = {},
    targetReturn = {}
}

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
    local year = tonumber(os.date("%Y", now)) or 2400
    local day = tonumber(os.date("%j", now)) or 1
    local fraction = day / 365
    return string.format("%d.%02d", year, math.floor(fraction * 100))
end

local function GetCharacterName(ply)
    if LeopardRP.Personnel and LeopardRP.Personnel.GetActiveCharacter then
        local character = LeopardRP.Personnel.GetActiveCharacter(ply)
        if istable(character) then
            local first = tostring(character.firstName or "")
            local last = tostring(character.lastName or "")
            local fullName = string.Trim(first .. " " .. last)
            if fullName ~= "" then
                return fullName
            end
        end
    end

    return IsValid(ply) and ply:Nick() or "Unknown"
end

local function EnsureTables()
    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE_PERMISSIONS .. [[ (
        steamid64 TEXT PRIMARY KEY,
        rank_id TEXT NOT NULL DEFAULT 'none',
        updated_by TEXT,
        updated_at TEXT
    )]])

    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE_LOGS .. [[ (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        steamid64 TEXT,
        steam_name TEXT,
        character_name TEXT,
        admin_rank TEXT,
        action TEXT,
        target_steamid64 TEXT,
        target_name TEXT,
        details_json TEXT,
        date_text TEXT,
        time_text TEXT,
        stardate_text TEXT,
        created_at INTEGER
    )]])

    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE_PUNISHMENTS .. [[ (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_steamid64 TEXT,
        target_name TEXT,
        staff_steamid64 TEXT,
        staff_name TEXT,
        punishment_type TEXT,
        duration_text TEXT,
        reason TEXT,
        notes TEXT,
        date_text TEXT,
        time_text TEXT,
        stardate_text TEXT,
        created_at INTEGER
    )]])

    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE_RULEBOOK .. [[ (
        id INTEGER PRIMARY KEY,
        content_json TEXT,
        updated_by TEXT,
        updated_at INTEGER
    )]])

    sql.Query([[CREATE TABLE IF NOT EXISTS ]] .. TABLE_GUIDELINES .. [[ (
        id INTEGER PRIMARY KEY,
        content_json TEXT,
        updated_by TEXT,
        updated_at INTEGER
    )]])
end

EnsureTables()

local function EnsureDefaultDocuments()
    local defaultRulebook = {
        sections = {
            { title = "Server Conduct", body = "Follow Star Trek RP standards, remain respectful, and avoid disruptive behavior." },
            { title = "Administrative Process", body = "Moderation actions must include reason, duration where applicable, and staff accountability." }
        }
    }

    local defaultGuidelines = {
        entries = {
            { key = "spam", description = "Repeated chat/voice spam.", recommended = "Warn, then mute.", escalation = "Repeat offenses can lead to temp ban.", notes = "Capture evidence before escalating." },
            { key = "failrp", description = "Ignoring roleplay standards.", recommended = "Warn and document.", escalation = "Temp ban for repeated incidents.", notes = "Consider context and intent." },
            { key = "metagaming", description = "Using OOC knowledge in character.", recommended = "Warn.", escalation = "Temp ban for repeated abuse.", notes = "Explain the rule when issuing warning." },
            { key = "rdm", description = "Random deathmatch without RP basis.", recommended = "Jail and warning.", escalation = "Temp ban if repeated.", notes = "Review combat logs first." },
            { key = "nitrp", description = "No intent to roleplay.", recommended = "Warn and monitor.", escalation = "Kick or temp ban for patterns.", notes = "Use history filter for prior notes." },
            { key = "prop_abuse", description = "Props used to grief or block gameplay.", recommended = "Cleanup and warn.", escalation = "Temp ban if repeated.", notes = "Keep screenshots when possible." },
            { key = "combat_logging", description = "Disconnecting to avoid RP consequences.", recommended = "Warn and note.", escalation = "Temp ban for repeated abuse.", notes = "Correlate with timestamps." },
            { key = "exploiting", description = "Abusing bugs or external tools.", recommended = "Immediate temp/permanent ban.", escalation = "Escalate to Head Admin/Owner review.", notes = "Preserve evidence and server logs." }
        }
    }

    local existingRulebook = sql.QueryValue("SELECT content_json FROM " .. TABLE_RULEBOOK .. " WHERE id = 1")
    if not existingRulebook then
        sql.Query(string.format(
            "INSERT INTO %s (id, content_json, updated_by, updated_at) VALUES (1, '%s', '%s', %d)",
            TABLE_RULEBOOK,
            SQLSafe(SerializeTable(defaultRulebook)),
            SQLSafe("System"),
            os.time()
        ))
    end

    local existingGuidelines = sql.QueryValue("SELECT content_json FROM " .. TABLE_GUIDELINES .. " WHERE id = 1")
    if not existingGuidelines then
        sql.Query(string.format(
            "INSERT INTO %s (id, content_json, updated_by, updated_at) VALUES (1, '%s', '%s', %d)",
            TABLE_GUIDELINES,
            SQLSafe(SerializeTable(defaultGuidelines)),
            SQLSafe("System"),
            os.time()
        ))
    end
end

EnsureDefaultDocuments()

function Admin.GetPermissionRank(steamID64)
    if tostring(steamID64 or "") == FORCED_OWNER_STEAMID64 then
        return "head_administrator"
    end

    local query = string.format("SELECT rank_id FROM %s WHERE steamid64 = '%s' LIMIT 1", TABLE_PERMISSIONS, SQLSafe(steamID64))
    local rows = sql.Query(query)
    if istable(rows) and rows[1] then
        return Admin.NormalizeRank(rows[1].rank_id)
    end

    return "none"
end

function Admin.SetPermissionRank(steamID64, rankID, actorName)
    if tostring(steamID64 or "") == FORCED_OWNER_STEAMID64 then
        rankID = "head_administrator"
    end

    local normalized = Admin.NormalizeRank(rankID)
    local timestamp = os.time()

    local query = string.format(
        "INSERT OR REPLACE INTO %s (steamid64, rank_id, updated_by, updated_at) VALUES ('%s', '%s', '%s', '%s')",
        TABLE_PERMISSIONS,
        SQLSafe(steamID64),
        SQLSafe(normalized),
        SQLSafe(actorName or "System"),
        SQLSafe(os.date("%Y-%m-%d", timestamp))
    )

    sql.Query(query)
end

function Admin.IsClockedIn(ply)
    if not IsValid(ply) then return false end
    local session = Admin.ActiveSessions[ply:SteamID64()]
    return session and session.clockedIn == true or false
end

local function IsOwner(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function IsHeadAdminOrOwner(ply)
    if not IsValid(ply) then return false end
    if IsOwner(ply) then return true end
    return Admin.HasRankAtLeast(Admin.GetPermissionRank(ply:SteamID64()), "head_administrator")
end

local function HasAnyAdminPermission(ply)
    if not IsValid(ply) then return false end
    return Admin.GetPermissionRank(ply:SteamID64()) ~= "none"
end

local function HasActiveAdminTools(ply)
    if not IsValid(ply) then return false end
    local rankID = Admin.GetPermissionRank(ply:SteamID64())
    if rankID == "head_administrator" then
        return true
    end

    return Admin.IsClockedIn(ply)
end

local function LogAction(ply, actionID, targetPly, details)
    if not IsValid(ply) then return end

    local steamID64 = ply:SteamID64()
    local timestamp = os.time()
    local rankID = Admin.GetPermissionRank(steamID64)
    local row = {
        steamid64 = steamID64,
        steam_name = ply:Nick(),
        character_name = GetCharacterName(ply),
        admin_rank = rankID,
        action = tostring(actionID or "unknown"),
        target_steamid64 = IsValid(targetPly) and targetPly:SteamID64() or tostring(details and details.targetSteamID64 or ""),
        target_name = IsValid(targetPly) and targetPly:Nick() or tostring(details and details.targetName or ""),
        details_json = SerializeTable(details),
        date_text = os.date("%Y-%m-%d", timestamp),
        time_text = os.date("%H:%M:%S", timestamp),
        stardate_text = GetStardateText(),
        created_at = timestamp
    }

    local query = string.format(
        "INSERT INTO %s (steamid64, steam_name, character_name, admin_rank, action, target_steamid64, target_name, details_json, date_text, time_text, stardate_text, created_at) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d)",
        TABLE_LOGS,
        SQLSafe(row.steamid64),
        SQLSafe(row.steam_name),
        SQLSafe(row.character_name),
        SQLSafe(row.admin_rank),
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
    hook.Run("LeopardRP.AdminLogCreated", row)
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

local function FetchAdminLogs(limit)
    local query = string.format("SELECT * FROM %s ORDER BY id DESC LIMIT %d", TABLE_LOGS, math.Clamp(tonumber(limit) or 120, 10, 300))
    local rows = sql.Query(query)
    if not istable(rows) then return {} end

    local output = {}
    for _, row in ipairs(rows) do
        table.insert(output, {
            staffName = tostring(row.steam_name or "Unknown"),
            staffSteamID64 = tostring(row.steamid64 or ""),
            characterName = tostring(row.character_name or "Unknown"),
            adminRank = tostring(row.admin_rank or "none"),
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

local function FetchPunishments(limit)
    local query = string.format("SELECT * FROM %s ORDER BY id DESC LIMIT %d", TABLE_PUNISHMENTS, math.Clamp(tonumber(limit) or 300, 20, 500))
    local rows = sql.Query(query)
    if not istable(rows) then return {} end

    local output = {}
    for _, row in ipairs(rows) do
        table.insert(output, {
            id = tonumber(row.id) or 0,
            targetName = tostring(row.target_name or ""),
            targetSteamID64 = tostring(row.target_steamid64 or ""),
            staffName = tostring(row.staff_name or ""),
            staffSteamID64 = tostring(row.staff_steamid64 or ""),
            punishmentType = tostring(row.punishment_type or ""),
            duration = tostring(row.duration_text or ""),
            reason = tostring(row.reason or ""),
            notes = tostring(row.notes or ""),
            date = tostring(row.date_text or ""),
            time = tostring(row.time_text or ""),
            stardate = tostring(row.stardate_text or "")
        })
    end

    return output
end

local function FetchRulebook()
    local query = string.format("SELECT content_json FROM %s WHERE id = 1 LIMIT 1", TABLE_RULEBOOK)
    local value = sql.QueryValue(query)
    return DeserializeTable(value)
end

local function FetchGuidelines()
    local query = string.format("SELECT content_json FROM %s WHERE id = 1 LIMIT 1", TABLE_GUIDELINES)
    local value = sql.QueryValue(query)
    return DeserializeTable(value)
end

local function UpdateRulebook(actorName, payload)
    sql.Query(string.format(
        "UPDATE %s SET content_json = '%s', updated_by = '%s', updated_at = %d WHERE id = 1",
        TABLE_RULEBOOK,
        SQLSafe(SerializeTable(payload)),
        SQLSafe(actorName),
        os.time()
    ))
end

local function UpdateGuidelines(actorName, payload)
    sql.Query(string.format(
        "UPDATE %s SET content_json = '%s', updated_by = '%s', updated_at = %d WHERE id = 1",
        TABLE_GUIDELINES,
        SQLSafe(SerializeTable(payload)),
        SQLSafe(actorName),
        os.time()
    ))
end

local function Notify(ply, text)
    WritePayload(Admin.NetworkStrings.ActionResult, ply, { ok = false, message = tostring(text or "Unable to complete request.") })
end

local function Success(ply, text)
    WritePayload(Admin.NetworkStrings.ActionResult, ply, { ok = true, message = tostring(text or "Completed.") })
end

local function GetClockStatusPayload(ply)
    local steamID64 = ply:SteamID64()
    local rankID = Admin.GetPermissionRank(steamID64)
    local session = Admin.ActiveSessions[steamID64]

    return {
        rankID = rankID,
        rankName = Admin.GetRankDefinition(rankID).Name,
        clockedIn = session and session.clockedIn == true or false,
        sessionStartedAt = session and session.startedAt or 0,
        canManageStaff = IsHeadAdminOrOwner(ply),
        canEditPolicy = IsHeadAdminOrOwner(ply)
    }
end

local function SendInitialData(ply)
    local payload = {
        clock = GetClockStatusPayload(ply),
        onlinePlayers = BuildOnlinePlayers(),
        adminRanks = Admin.Ranks,
        logs = FetchAdminLogs(200),
        punishments = FetchPunishments(400),
        rulebook = FetchRulebook(),
        guidelines = FetchGuidelines()
    }

    WritePayload(Admin.NetworkStrings.ReceiveInitialData, ply, payload)
end

local function FindTargetBySteamID64(steamID64)
    for _, ply in ipairs(player.GetAll()) do
        if ply:SteamID64() == steamID64 then
            return ply
        end
    end

    return nil
end

local function ParseDurationToSeconds(durationText, defaultSeconds)
    local directPartsYears = tonumber(durationText and durationText.years)
    local directPartsDays = tonumber(durationText and durationText.days)
    local directPartsSeconds = tonumber(durationText and durationText.seconds)
    if directPartsYears or directPartsDays or directPartsSeconds then
        local total = 0
        total = total + math.max(0, math.floor(directPartsYears or 0)) * 31536000
        total = total + math.max(0, math.floor(directPartsDays or 0)) * 86400
        total = total + math.max(0, math.floor(directPartsSeconds or 0))
        if total > 0 then
            return total
        end
    end

    local text = string.lower(string.Trim(tostring(durationText or "")))
    if text == "" then
        return math.max(0, tonumber(defaultSeconds) or 0)
    end

    local direct = tonumber(text)
    if direct then
        return math.max(0, math.floor(direct * 60))
    end

    local value, unit = string.match(text, "^(%d+)%s*([smhdw])$")
    value = tonumber(value)
    if not value then
        return math.max(0, tonumber(defaultSeconds) or 0)
    end

    local unitScale = {
        s = 1,
        m = 60,
        h = 3600,
        d = 86400,
        w = 604800
    }

    local scale = unitScale[unit] or 60
    return math.max(0, math.floor(value * scale))
end

local function ParseDurationFromPayload(payload)
    payload = istable(payload) and payload or {}

    local years = math.max(0, math.floor(tonumber(payload.durationYears) or 0))
    local days = math.max(0, math.floor(tonumber(payload.durationDays) or 0))
    local seconds = math.max(0, math.floor(tonumber(payload.durationSeconds) or 0))
    local packedSeconds = (years * 31536000) + (days * 86400) + seconds

    if packedSeconds > 0 then
        return packedSeconds, string.format("%dy %dd %ds", years, days, seconds)
    end

    local legacySeconds = ParseDurationToSeconds(payload.duration or "", 0)
    return legacySeconds, tostring(payload.duration or "")
end

local function GetTargetSteamID(targetPly, targetSteamID64)
    if IsValid(targetPly) then
        return tostring(targetPly:SteamID() or util.SteamIDFrom64(targetPly:SteamID64()) or "")
    end

    if util.SteamIDFrom64 then
        local converted = util.SteamIDFrom64(tostring(targetSteamID64 or ""))
        if converted and converted ~= "" then
            return converted
        end
    end

    return tostring(targetSteamID64 or "")
end

local function SetMutedState(steamID64, durationSeconds)
    local expiresAt = durationSeconds > 0 and (os.time() + durationSeconds) or 0
    Admin.PunishmentStates.muted[tostring(steamID64 or "")] = expiresAt
end

local function SetGaggedState(steamID64, durationSeconds)
    local expiresAt = durationSeconds > 0 and (os.time() + durationSeconds) or 0
    Admin.PunishmentStates.gagged[tostring(steamID64 or "")] = expiresAt
end

local function SetJailedState(targetPly, durationSeconds, jailOrigin)
    if not IsValid(targetPly) then return end
    local steamID64 = targetPly:SteamID64()
    local expiresAt = durationSeconds > 0 and (os.time() + durationSeconds) or 0

    Admin.PunishmentStates.jailed[steamID64] = {
        expiresAt = expiresAt,
        returnPos = targetPly:GetPos(),
        jailPos = jailOrigin or targetPly:GetPos()
    }

    targetPly:SetPos(jailOrigin or targetPly:GetPos())
    targetPly:Freeze(true)
end

local function ClearJailState(targetPly)
    if not IsValid(targetPly) then return end
    local steamID64 = targetPly:SteamID64()
    local jailState = Admin.PunishmentStates.jailed[steamID64]
    if jailState and jailState.returnPos then
        targetPly:SetPos(jailState.returnPos)
    end
    targetPly:Freeze(false)
    Admin.PunishmentStates.jailed[steamID64] = nil
end

local function ExecutePunishmentWithBackend(staffPly, targetPly, punishmentType, reason, durationText, targetSteamID64)
    local durationSeconds = ParseDurationToSeconds(durationText, 0)
    local durationMinutes = math.max(0, math.floor(durationSeconds / 60))
    local externalDurationText = tostring(durationText or "")
    if istable(durationText) then
        externalDurationText = string.format("%dy %dd %ds",
            math.max(0, math.floor(tonumber(durationText.years) or 0)),
            math.max(0, math.floor(tonumber(durationText.days) or 0)),
            math.max(0, math.floor(tonumber(durationText.seconds) or 0))
        )
    end

    local externalResult, externalBackend = hook.Run("LeopardRP.AdminPunishmentEnforce", staffPly, targetPly, {
        punishmentType = punishmentType,
        reason = reason,
        durationText = externalDurationText,
        durationSeconds = durationSeconds,
        durationMinutes = durationMinutes,
        targetSteamID64 = targetSteamID64
    })

    if externalResult == true then
        return true, tostring(externalBackend or "external")
    elseif externalResult == false then
        return false, tostring(externalBackend or "External backend rejected punishment.")
    end

    if punishmentType == "warn" then
        if IsValid(targetPly) then
            net.Start(Admin.NetworkStrings.WarnOverlay)
                net.WriteString(tostring(reason or "You have been warned."))
                net.WriteString(tostring(staffPly and staffPly:Nick() or "Administration"))
            net.Send(targetPly)
        end
        return true, "native_warn"
    end

    if punishmentType == "kick" then
        if IsValid(targetPly) then
            targetPly:Kick("[LeopardRP Administration] " .. reason)
            return true, "native_kick"
        end
        return false, "Target is offline for kick."
    end

    if punishmentType == "temp_ban" or punishmentType == "perm_ban" then
        local minutes = punishmentType == "perm_ban" and 0 or math.max(1, durationMinutes)
        if IsValid(targetPly) then
            targetPly:Ban(minutes, true)
            targetPly:Kick("[LeopardRP Administration] " .. reason)
            return true, "native_ban"
        end

        local steamID = GetTargetSteamID(targetPly, targetSteamID64)
        if steamID ~= "" then
            RunConsoleCommand("banid", tostring(minutes), steamID)
            RunConsoleCommand("writeid")
            return true, "native_banid"
        end

        return false, "Unable to resolve SteamID for ban."
    end

    if punishmentType == "unban" then
        local steamID = GetTargetSteamID(targetPly, targetSteamID64)
        if steamID == "" then
            return false, "Unable to resolve SteamID for unban."
        end

        RunConsoleCommand("removeid", steamID)
        RunConsoleCommand("writeid")
        return true, "native_unban"
    end

    if punishmentType == "mute" then
        SetMutedState(targetSteamID64, durationSeconds)
        return true, "native_mute"
    end

    if punishmentType == "gag" then
        SetGaggedState(targetSteamID64, durationSeconds)
        return true, "native_gag"
    end

    if punishmentType == "jail" then
        if not IsValid(targetPly) then
            return false, "Target is offline for jail."
        end

        local jailPos = staffPly:GetPos() + staffPly:GetForward() * 72
        SetJailedState(targetPly, durationSeconds, jailPos)
        return true, "native_jail"
    end

    if punishmentType == "freeze" then
        if IsValid(targetPly) then
            targetPly:Freeze(true)
            return true, "native_freeze"
        end
        return false, "Target is offline for freeze."
    end

    if punishmentType == "spectate" then
        if IsValid(targetPly) then
            targetPly:Spectate(OBS_MODE_ROAMING)
            return true, "native_spectate"
        end
        return false, "Target is offline for spectate."
    end

    if punishmentType == "teleport" then
        if IsValid(targetPly) then
            Admin.MovementStates.staffReturn[staffPly:SteamID64()] = staffPly:GetPos()
            staffPly:SetPos(targetPly:GetPos() + Vector(0, 0, 6))
            return true, "native_teleport"
        end
        return false, "Target is offline for teleport."
    end

    if punishmentType == "bring" then
        if IsValid(targetPly) then
            Admin.MovementStates.targetReturn[targetSteamID64] = targetPly:GetPos()
            targetPly:SetPos(staffPly:GetPos() + staffPly:GetForward() * 48)
            return true, "native_bring"
        end
        return false, "Target is offline for bring."
    end

    if punishmentType == "return" then
        if IsValid(targetPly) and Admin.MovementStates.targetReturn[targetSteamID64] then
            targetPly:SetPos(Admin.MovementStates.targetReturn[targetSteamID64])
            Admin.MovementStates.targetReturn[targetSteamID64] = nil
            return true, "native_return"
        end
        return false, "No return position available."
    end

    return false, "Unsupported punishment action."
end

local function HandleClockToggle(ply, shouldClockIn)
    if not HasAnyAdminPermission(ply) then
        return Notify(ply, "No administration permissions assigned.")
    end

    local steamID64 = ply:SteamID64()
    local now = os.time()

    if shouldClockIn then
        Admin.ActiveSessions[steamID64] = {
            clockedIn = true,
            startedAt = now
        }

        LogAction(ply, "clock_in", nil, { rankID = Admin.GetPermissionRank(steamID64) })
        Success(ply, "Clocked in to administration duty.")
    else
        local session = Admin.ActiveSessions[steamID64]
        local startedAt = session and tonumber(session.startedAt) or now
        local actionCount = CountSessionActions(steamID64, startedAt)
        local duration = math.max(0, now - startedAt)
        Admin.ActiveSessions[steamID64] = nil

        LogAction(ply, "clock_out", nil, {
            sessionLengthSeconds = duration,
            actionsPerformed = actionCount
        })

        Success(ply, "Clocked out of administration duty.")
    end

    WritePayload(Admin.NetworkStrings.ClockStatus, ply, GetClockStatusPayload(ply))
end

local function RecordPunishment(ply, payload)
    if not HasActiveAdminTools(ply) then
        return Notify(ply, "Clock in to use moderation actions.")
    end

    local punishmentType = tostring(payload.punishmentType or "")
    local reason = string.Trim(tostring(payload.reason or ""))
    local durationSeconds, durationLabel = ParseDurationFromPayload(payload)
    local duration = string.Trim(tostring(durationLabel or ""))
    local notes = string.Trim(tostring(payload.notes or ""))
    local targetSteamID64 = string.Trim(tostring(payload.targetSteamID64 or payload.manualTargetSteamID64 or ""))
    local targetName = tostring(payload.targetName or "")
    local reasonRequired = punishmentType == "warn"
        or punishmentType == "kick"
        or punishmentType == "temp_ban"
        or punishmentType == "perm_ban"
        or punishmentType == "mute"
        or punishmentType == "unban"

    if punishmentType == "" then
        return Notify(ply, "Punishment type is required.")
    end

    if reasonRequired and reason == "" then
        return Notify(ply, "Reason is required for warn, kick, ban, and mute.")
    end

    if targetSteamID64 == "" then
        return Notify(ply, "Target player is required.")
    end

    local targetPly = FindTargetBySteamID64(targetSteamID64)

    if (punishmentType == "temp_ban" or punishmentType == "jail" or punishmentType == "mute" or punishmentType == "gag") and durationSeconds <= 0 then
        return Notify(ply, "A non-zero duration is required for timed punishments.")
    end
    local now = os.time()

    sql.Query(string.format(
        "INSERT INTO %s (target_steamid64, target_name, staff_steamid64, staff_name, punishment_type, duration_text, reason, notes, date_text, time_text, stardate_text, created_at) VALUES ('%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', %d)",
        TABLE_PUNISHMENTS,
        SQLSafe(targetSteamID64),
        SQLSafe(targetName ~= "" and targetName or (IsValid(targetPly) and targetPly:Nick() or "Unknown")),
        SQLSafe(ply:SteamID64()),
        SQLSafe(ply:Nick()),
        SQLSafe(punishmentType),
        SQLSafe(duration),
        SQLSafe(reason),
        SQLSafe(notes),
        SQLSafe(os.date("%Y-%m-%d", now)),
        SQLSafe(os.date("%H:%M:%S", now)),
        SQLSafe(GetStardateText()),
        now
    ))

    local enforced, backendInfo = ExecutePunishmentWithBackend(ply, targetPly, punishmentType, reason, {
        years = math.floor((durationSeconds / 31536000)),
        days = math.floor((durationSeconds % 31536000) / 86400),
        seconds = math.floor(durationSeconds % 86400),
    }, targetSteamID64)
    if not enforced then
        return Notify(ply, tostring(backendInfo or "Failed to enforce punishment."))
    end

    LogAction(ply, punishmentType, targetPly, {
        reason = reason,
        duration = duration,
        notes = notes,
        backend = backendInfo
    })

    Success(ply, "Punishment recorded.")
end

hook.Add("Think", "LeopardRP.Admin.PunishmentExpiry", function()
    local now = os.time()

    for steamID64, expiresAt in pairs(Admin.PunishmentStates.muted or {}) do
        if tonumber(expiresAt) and tonumber(expiresAt) > 0 and now >= tonumber(expiresAt) then
            Admin.PunishmentStates.muted[steamID64] = nil
        end
    end

    for steamID64, expiresAt in pairs(Admin.PunishmentStates.gagged or {}) do
        if tonumber(expiresAt) and tonumber(expiresAt) > 0 and now >= tonumber(expiresAt) then
            Admin.PunishmentStates.gagged[steamID64] = nil
        end
    end

    for steamID64, jailState in pairs(Admin.PunishmentStates.jailed or {}) do
        local expiresAt = istable(jailState) and tonumber(jailState.expiresAt) or 0
        if expiresAt > 0 and now >= expiresAt then
            local targetPly = FindTargetBySteamID64(steamID64)
            if IsValid(targetPly) then
                ClearJailState(targetPly)
            else
                Admin.PunishmentStates.jailed[steamID64] = nil
            end
        end
    end
end)

hook.Add("PlayerCanHearPlayersVoice", "LeopardRP.Admin.MuteEnforcement", function(listener, talker)
    if not IsValid(listener) or not IsValid(talker) then return end
    if Admin.PunishmentStates.muted[talker:SteamID64()] ~= nil then
        return false, false
    end
end)

hook.Add("PlayerSay", "LeopardRP.Admin.GagEnforcement", function(ply, text)
    if not IsValid(ply) then return end
    if Admin.PunishmentStates.gagged[ply:SteamID64()] ~= nil then
        return ""
    end

    return text
end)

hook.Add("Move", "LeopardRP.Admin.JailEnforcement", function(ply, moveData)
    if not IsValid(ply) then return end
    local jailState = Admin.PunishmentStates.jailed[ply:SteamID64()]
    if not istable(jailState) then return end

    moveData:SetMaxClientSpeed(0)
    moveData:SetForwardSpeed(0)
    moveData:SetSideSpeed(0)
    moveData:SetUpSpeed(0)

    if jailState.jailPos and ply:GetPos():DistToSqr(jailState.jailPos) > (160 * 160) then
        ply:SetPos(jailState.jailPos)
    end
end)

local function HandleSetAdminRank(ply, payload)
    if not IsHeadAdminOrOwner(ply) then
        return Notify(ply, "Only Head Administrator or Owner can assign admin permissions.")
    end

    local targetSteamID64 = tostring(payload.targetSteamID64 or "")
    if targetSteamID64 == "" then
        return Notify(ply, "Invalid target SteamID64.")
    end

    local targetRank = Admin.NormalizeRank(payload.rankID)
    Admin.SetPermissionRank(targetSteamID64, targetRank, ply:Nick())

    LogAction(ply, "set_admin_rank", nil, {
        targetSteamID64 = targetSteamID64,
        rankID = targetRank
    })

    Success(ply, "Updated administration rank.")
end

local function HandleRulebookUpdate(ply, payload)
    if not IsHeadAdminOrOwner(ply) then
        return Notify(ply, "Only Head Administrator or Owner may edit the Rulebook.")
    end

    UpdateRulebook(ply:Nick(), payload.rulebook or {})
    LogAction(ply, "rulebook_edited", nil, {})
    Success(ply, "Rulebook updated.")
end

local function HandleGuidelinesUpdate(ply, payload)
    if not IsHeadAdminOrOwner(ply) then
        return Notify(ply, "Only Head Administrator or Owner may edit guidelines.")
    end

    UpdateGuidelines(ply:Nick(), payload.guidelines or {})
    LogAction(ply, "guidelines_edited", nil, {})
    Success(ply, "Guidelines updated.")
end

local function HandleSubmitAction(ply)
    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local actionType = tostring(payload.type or "")

    if actionType == "clock_toggle" then
        return HandleClockToggle(ply, tobool(payload.clockIn))
    end

    if actionType == "set_rank" then
        return HandleSetAdminRank(ply, payload)
    end

    if actionType == "punishment" then
        return RecordPunishment(ply, payload)
    end

    if actionType == "update_rulebook" then
        return HandleRulebookUpdate(ply, payload)
    end

    if actionType == "update_guidelines" then
        return HandleGuidelinesUpdate(ply, payload)
    end

    Notify(ply, "Unknown administration action.")
end

net.Receive(Admin.NetworkStrings.RequestOpenMenu, function(_, ply)
    if not HasAnyAdminPermission(ply) then
        return Notify(ply, "No administration permissions assigned.")
    end

    net.Start(Admin.NetworkStrings.OpenMenu)
    net.Send(ply)
end)

net.Receive(Admin.NetworkStrings.RequestInitialData, function(_, ply)
    if not HasAnyAdminPermission(ply) then
        return Notify(ply, "No administration permissions assigned.")
    end

    SendInitialData(ply)
end)

net.Receive(Admin.NetworkStrings.ClockToggle, function(_, ply)
    local shouldClockIn = net.ReadBool()
    HandleClockToggle(ply, shouldClockIn)
end)

net.Receive(Admin.NetworkStrings.SubmitAction, function(_, ply)
    HandleSubmitAction(ply)
    SendInitialData(ply)
end)

hook.Add("PlayerDisconnected", "LeopardRP.Admin.ClockOutOnDisconnect", function(ply)
    if not IsValid(ply) then return end

    local session = Admin.ActiveSessions[ply:SteamID64()]
    if not session then return end

    local now = os.time()
    local startedAt = tonumber(session.startedAt) or now
    local actions = CountSessionActions(ply:SteamID64(), startedAt)
    local duration = math.max(0, now - startedAt)

    LogAction(ply, "clock_out", nil, {
        sessionLengthSeconds = duration,
        actionsPerformed = actions,
        disconnect = true
    })

    Admin.ActiveSessions[ply:SteamID64()] = nil
end)

hook.Add("PlayerSpawnProp", "LeopardRP.AdminSpawnPropAlwaysFalse", function(ply)
    if not IsValid(ply) then return end
    if not HasActiveAdminTools(ply) then return end

    return nil
end)

hook.Add("PlayerNoClip", "LeopardRP.AdminNoClipPolicy", function(ply)
    if not IsValid(ply) then return end

    if LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank and LeopardRP.GameMaster.IsClockedIn and LeopardRP.GameMaster.HasRankAtLeast then
        local gmRankID = tostring(LeopardRP.GameMaster.GetPermissionRank(ply:SteamID64()) or "none")
        if LeopardRP.GameMaster.IsClockedIn(ply) and LeopardRP.GameMaster.HasRankAtLeast(gmRankID, "game_master") then
            return true
        end
    end

    local rankID = Admin.GetPermissionRank(ply:SteamID64())
    if Admin.HasRankAtLeast(rankID, "administrator") and Admin.IsClockedIn(ply) then
        return true
    end

    return false
end)

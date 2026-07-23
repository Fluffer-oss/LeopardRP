LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

local Personnel = LeopardRP.Personnel

local FORCED_OWNER_STEAMID64 = tostring(Personnel.ForcedOwnerSteamID64 or "76561199122465449")
local DATAKEY_STAFF_RANKS = "leopardrp_staff_ranks"
local DATAKEY_PERMISSION_PROFILES = "leopardrp_permission_profiles"
local DATAKEY_DEVMODE_SETTINGS = "leopardrp_devmode_settings"
local DATAKEY_LOGISTICS_SETTINGS = "leopardrp_logistics_settings"
local MIN_HELIX_INV_W = 6
local MIN_HELIX_INV_H = 4

local function IsForcedOwnerSubject(subject)
    if Personnel.IsForcedOwner then
        return Personnel.IsForcedOwner(subject)
    end

    local steamID64 = ""
    if IsValid(subject) and subject.SteamID64 then
        steamID64 = tostring(subject:SteamID64() or "")
    else
        steamID64 = tostring(subject or "")
    end

    return steamID64 ~= "" and steamID64 == FORCED_OWNER_STEAMID64
end

local function ReadGlobalData(key, default)
    if not ix or not ix.data or not ix.data.Get then
        return default
    end

    local value = ix.data.Get(key, default, true, true)
    if value == nil then
        return default
    end

    return value
end

local function WriteGlobalData(key, value)
    if not ix or not ix.data or not ix.data.Set then
        return false
    end

    ix.data.Set(key, value, true, true)
    return true
end

local function GetCharactersModule()
    return LeopardRP and LeopardRP.Characters or nil
end

local function Char_CreateEmptyProfile()
    local characters = GetCharactersModule()
    if characters and characters.CreateEmptyProfile then
        return characters.CreateEmptyProfile()
    end

    return {
        active = nil,
        characters = {}
    }
end

local function Char_NormalizeCharacterRecord(characterRecord)
    local characters = GetCharactersModule()
    if characters and characters.NormalizeCharacterRecord then
        return characters.NormalizeCharacterRecord(characterRecord)
    end

    local normalized = istable(characterRecord) and table.Copy(characterRecord) or {}
    normalized.id = tostring(normalized.id or "")
    normalized.name = tostring(normalized.name or "Unnamed")
    normalized.firstName = tostring(normalized.firstName or "")
    normalized.middleName = tostring(normalized.middleName or "")
    normalized.lastName = tostring(normalized.lastName or "")
    normalized.authCode = tostring(normalized.authCode or "")
    normalized.personnelNumber = tonumber(normalized.personnelNumber) or tonumber(normalized.id) or 100
    normalized.serviceNumber = tonumber(normalized.serviceNumber) or tonumber(normalized.id) or normalized.personnelNumber
    normalized.species = tostring(normalized.species or "Human")
    normalized.gender = tostring(normalized.gender or "Male")
    normalized.age = tonumber(normalized.age) or 24
    normalized.rankID = tostring(normalized.rankID or "cadet")
    normalized.division = tostring(normalized.division or "Operations")
    normalized.uniformType = tostring(normalized.uniformType or "Standard")
    normalized.bodyModel = tostring(normalized.bodyModel or "")
    normalized.headModel = tostring(normalized.headModel or "")
    normalized.headIndex = tonumber(normalized.headIndex) or 1
    normalized.createdAt = tonumber(normalized.createdAt) or os.time()
    normalized.updatedAt = tonumber(normalized.updatedAt) or normalized.createdAt
    normalized.creationDate = tostring(normalized.creationDate or os.date("%Y-%m-%d", normalized.createdAt))
    normalized.creationStardate = tostring(normalized.creationStardate or "")
    normalized.customData = istable(normalized.customData) and normalized.customData or {}
    return normalized
end

local function Char_NormalizeProfile(profile)
    local characters = GetCharactersModule()
    if characters and characters.NormalizeProfile then
        return characters.NormalizeProfile(profile)
    end

    local normalizedProfile = Char_CreateEmptyProfile()

    if istable(profile) then
        local activeID = tostring(profile.active or "")
        if activeID ~= "" then
            normalizedProfile.active = activeID
        end

        if istable(profile.characters) then
            for rawID, characterRecord in pairs(profile.characters) do
                local normalizedCharacter = Char_NormalizeCharacterRecord(characterRecord)
                local characterID = tostring(normalizedCharacter.id or "")
                if characterID == "" then
                    characterID = tostring(rawID or "")
                    normalizedCharacter.id = characterID
                end

                if characterID ~= "" then
                    normalizedProfile.characters[characterID] = normalizedCharacter
                end
            end
        end
    end

    if (not normalizedProfile.active or normalizedProfile.active == "") and normalizedProfile.characters then
        for characterID, _ in pairs(normalizedProfile.characters) do
            normalizedProfile.active = tostring(characterID)
            break
        end
    end

    return normalizedProfile
end

local function Char_GetCharacterList(profile)
    local characters = GetCharactersModule()
    if characters and characters.GetCharacterList then
        return characters.GetCharacterList(profile) or {}
    end

    local normalizedProfile = Char_NormalizeProfile(profile)
    local list = {}

    for _, characterRecord in pairs(normalizedProfile.characters or {}) do
        list[#list + 1] = Char_NormalizeCharacterRecord(characterRecord)
    end

    table.sort(list, function(a, b)
        return string.lower(tostring(a.name or "")) < string.lower(tostring(b.name or ""))
    end)

    return list
end

local function Char_GetActiveCharacter(profile)
    local characters = GetCharactersModule()
    if characters and characters.GetActiveCharacter then
        return characters.GetActiveCharacter(profile)
    end

    local normalizedProfile = Char_NormalizeProfile(profile)
    if normalizedProfile.active and normalizedProfile.characters then
        local activeCharacter = normalizedProfile.characters[tostring(normalizedProfile.active)]
        if activeCharacter then
            return Char_NormalizeCharacterRecord(activeCharacter)
        end
    end

    for _, characterRecord in pairs(normalizedProfile.characters or {}) do
        return Char_NormalizeCharacterRecord(characterRecord)
    end

    return nil
end

local function Char_LoadProfile(steamID64)
    local characters = GetCharactersModule()
    if characters and characters.LoadProfile then
        return Char_NormalizeProfile(characters.LoadProfile(steamID64))
    end

    local rows = sql.Query("SELECT profile_json FROM leopardrp_character_profiles WHERE steamid64 = " .. sql.SQLStr(tostring(steamID64 or "")) .. " LIMIT 1")
    if rows ~= false and istable(rows) and istable(rows[1]) then
        local decoded = util.JSONToTable(rows[1].profile_json or "{}") or {}
        return Char_NormalizeProfile(decoded)
    end

    local whereSchema = ""
    if Schema and Schema.folder then
        whereSchema = " AND schema = " .. sql.SQLStr(tostring(Schema.folder))
    end

    local charRows = sql.Query("SELECT id, name, model, create_time, last_join_time, data FROM ix_characters WHERE steamid = " .. sql.SQLStr(tostring(steamID64 or "")) .. whereSchema .. " ORDER BY id ASC")
    if charRows == false or not istable(charRows) then
        return Char_CreateEmptyProfile()
    end

    local profile = Char_CreateEmptyProfile()

    for _, row in ipairs(charRows) do
        local charID = tostring(row.id or "")
        if charID ~= "" then
            local fullName = tostring(row.name or "Unnamed")
            local firstName, lastName = string.match(fullName, "^(%S+)%s+(.+)$")
            local rowData = util.JSONToTable(row.data or "{}") or {}
            local customData = rowData.leopardrpCustomData

            profile.characters[charID] = {
                id = charID,
                name = fullName,
                firstName = tostring(firstName or fullName),
                middleName = "",
                lastName = tostring(lastName or ""),
                authCode = tostring(rowData.authCode or rowData.auth_code or ""),
                personnelNumber = tonumber(rowData.leopardrpPersonnelNumber) or tonumber(charID) or 100,
                serviceNumber = tonumber(rowData.leopardrpServiceNumber) or tonumber(charID) or 100,
                species = tostring(rowData.species or "Human"),
                gender = tostring(rowData.gender or "Male"),
                age = tonumber(rowData.age) or 24,
                rankID = tostring(rowData.leopardrpRankID or "cadet"),
                division = tostring(rowData.division or "Operations"),
                uniformType = tostring(rowData.uniformType or "Standard"),
                bodyModel = tostring(row.model or ""),
                headModel = tostring(rowData.headModel or ""),
                headIndex = tonumber(rowData.headIndex) or 1,
                createdAt = tonumber(row.create_time) or os.time(),
                updatedAt = tonumber(row.last_join_time) or tonumber(row.create_time) or os.time(),
                customData = istable(customData) and table.Copy(customData) or {}
            }

            if not profile.active then
                profile.active = charID
            end
        end
    end

    return Char_NormalizeProfile(profile)
end

local function Char_SaveProfile(steamID64, profile)
    local characters = GetCharactersModule()
    if characters and characters.SaveProfile then
        characters.SaveProfile(steamID64, profile)
        return true
    end

    local normalizedProfile = Char_NormalizeProfile(profile)
    local encoded = util.TableToJSON(normalizedProfile, true) or "{}"
    local query = string.format(
        "REPLACE INTO leopardrp_character_profiles (steamid64, profile_json, updated_at) VALUES (%s, %s, %d)",
        sql.SQLStr(tostring(steamID64 or "")),
        sql.SQLStr(encoded),
        os.time()
    )

    local result = sql.Query(query)
    if result == false then
        print("[LeopardRP Personnel] SQLite profile save failed: " .. tostring(sql.LastError() or "unknown error"))
        return false
    end

    return true
end

local function EnsurePersonnelTables()
    local queries = {
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_character_profiles (
                steamid64 TEXT PRIMARY KEY,
                profile_json TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_personnel_players (
                steamid64 TEXT PRIMARY KEY,
                steam_name TEXT NOT NULL,
                last_played INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_character_dossiers (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                character_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                stardate TEXT NOT NULL,
                author_steamid64 TEXT NOT NULL,
                author_name TEXT NOT NULL,
                category TEXT NOT NULL,
                entry_text TEXT NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_personnel_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                category TEXT NOT NULL,
                actor_name TEXT NOT NULL,
                actor_steamid64 TEXT NOT NULL,
                actor_character_name TEXT NOT NULL,
                target_name TEXT NOT NULL,
                target_steamid64 TEXT NOT NULL,
                message TEXT NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_player_reports (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp INTEGER NOT NULL,
                reporter_steamid64 TEXT NOT NULL,
                reporter_name TEXT NOT NULL,
                reporter_character_name TEXT NOT NULL,
                target_steamid64 TEXT NOT NULL,
                target_steam_name TEXT NOT NULL,
                target_character_name TEXT NOT NULL,
                category TEXT NOT NULL,
                description TEXT NOT NULL,
                admins_online INTEGER NOT NULL,
                pending_review INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_staff_ranks (
                steamid64 TEXT PRIMARY KEY,
                staff_rank TEXT NOT NULL,
                updated_by_steamid64 TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_permission_profiles (
                steamid64 TEXT PRIMARY KEY,
                server_permission TEXT NOT NULL,
                promotion_profile TEXT NOT NULL,
                training_permission INTEGER NOT NULL,
                updated_by_steamid64 TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_dev_mode_settings (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                whitelist_enabled INTEGER NOT NULL DEFAULT 0,
                whitelist_json TEXT NOT NULL DEFAULT '[]',
                updated_by_steamid64 TEXT NOT NULL DEFAULT 'system',
                updated_at INTEGER NOT NULL DEFAULT 0
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_whitelist_denied_attempts (
                steamid64 TEXT PRIMARY KEY,
                last_name TEXT NOT NULL,
                last_denied_at INTEGER NOT NULL,
                denied_count INTEGER NOT NULL DEFAULT 1
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_secondary_rank_definitions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                department TEXT NOT NULL,
                min_rank_order INTEGER NOT NULL,
                max_rank_order INTEGER NOT NULL,
                enforce_department INTEGER NOT NULL DEFAULT 1,
                enforce_rank_limits INTEGER NOT NULL DEFAULT 1,
                created_by_steamid64 TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS leopardrp_character_secondary_ranks (
                character_id TEXT NOT NULL,
                secondary_rank_id INTEGER NOT NULL,
                assigned_by_steamid64 TEXT NOT NULL,
                assigned_at INTEGER NOT NULL,
                PRIMARY KEY(character_id, secondary_rank_id)
            )
        ]]
    }

    for _, query in ipairs(queries) do
        local result = sql.Query(query)
        if result == false then
            print("[LeopardRP Personnel] SQLite init failed: " .. tostring(sql.LastError() or "unknown error"))
            return false
        end
    end

    local columns = sql.Query("PRAGMA table_info(leopardrp_secondary_rank_definitions)")
    local hasEnforceDepartment = false
    local hasEnforceRankLimits = false
    for _, column in ipairs(istable(columns) and columns or {}) do
        local columnName = string.lower(tostring(column.name or ""))
        if columnName == "enforce_department" then
            hasEnforceDepartment = true
        elseif columnName == "enforce_rank_limits" then
            hasEnforceRankLimits = true
        end
    end

    if not hasEnforceDepartment then
        sql.Query("ALTER TABLE leopardrp_secondary_rank_definitions ADD COLUMN enforce_department INTEGER NOT NULL DEFAULT 1")
    end
    if not hasEnforceRankLimits then
        sql.Query("ALTER TABLE leopardrp_secondary_rank_definitions ADD COLUMN enforce_rank_limits INTEGER NOT NULL DEFAULT 1")
    end

    return true
end

local function Notify(ply, message)
    if not IsValid(ply) then return end

    net.Start(Personnel.NetworkStrings.Notification)
    net.WriteString(tostring(message or ""))
    net.Send(ply)
end

local function CanAccessGMMenu(ply)
    if not IsValid(ply) then return false end
    if IsForcedOwnerSubject(ply) then return true end
    if not LeopardRP.GameMaster or not LeopardRP.GameMaster.GetPermissionRank then return false end

    local rankID = tostring(LeopardRP.GameMaster.GetPermissionRank(ply:SteamID64()) or "none")
    return rankID ~= "none"
end

local function CanAccessAdministrationMenu(ply)
    if not IsValid(ply) then return false end
    if IsForcedOwnerSubject(ply) then return true end

    return Personnel.CanAccessAdminPanel and Personnel.CanAccessAdminPanel(ply) or false
end

local function GetActorIdentity(ply)
    if not IsValid(ply) then
        return "System", "0", "System"
    end

    local steamName = ply:Nick()
    local steamID64 = ply:SteamID64()
    local characterName = steamName

    if LeopardRP.Personnel and LeopardRP.Personnel.GetActiveCharacter then
        local activeCharacter = LeopardRP.Personnel.GetActiveCharacter(ply)
        if istable(activeCharacter) and activeCharacter.name and activeCharacter.name ~= "" then
            characterName = tostring(activeCharacter.name)
        end
    end

    return steamName, steamID64, characterName
end

local function getActiveCharacterForPlayer(ply)
    if not IsValid(ply) then return nil end

    local activeCharacter

    if (LeopardRP.Characters and LeopardRP.Characters.GetPlayerProfile and LeopardRP.Characters.GetActiveCharacter) then
        local profile = LeopardRP.Characters.GetPlayerProfile(ply)
        if istable(profile) then
            activeCharacter = LeopardRP.Characters.GetActiveCharacter(profile)
            if not istable(activeCharacter) then
                activeCharacter = nil
            end
        end
    end

    local liveCharacter = ply.GetCharacter and ply:GetCharacter() or nil
    if not liveCharacter then
        return activeCharacter
    end

    local merged = istable(activeCharacter) and table.Copy(activeCharacter) or {}
    merged.customData = istable(merged.customData) and merged.customData or {}

    local liveName = liveCharacter.GetName and tostring(liveCharacter:GetName() or "") or ""
    if liveName ~= "" then
        merged.name = liveName
    end

    local liveDivision = ""
    if liveCharacter.GetDivision then
        liveDivision = tostring(liveCharacter:GetDivision("") or "")
    elseif liveCharacter.GetData then
        liveDivision = tostring(liveCharacter:GetData("division", "") or "")
    end
    if liveDivision ~= "" then
        merged.division = liveDivision
    end

    local liveRankID = ""
    if liveCharacter.GetData then
        liveRankID = tostring(liveCharacter:GetData("leopardrpRankID", "") or "")
    end

    if liveRankID == "" and liveCharacter.GetClass then
        liveRankID = tostring(liveCharacter:GetClass() or "")
    end

    if liveRankID ~= "" then
        merged.rankID = liveRankID
        if LeopardRP.GetRankName then
            merged.rank = tostring(LeopardRP.GetRankName(liveRankID) or merged.rank or "")
        end
    end

    if liveCharacter.GetData then
        local assignment = tostring(liveCharacter:GetData("assignment", "") or "")
        if assignment ~= "" then
            merged.customData.assignment = assignment
        end

        local position = tostring(liveCharacter:GetData("position", "") or "")
        if position ~= "" then
            merged.customData.position = position
        end
    end

    return merged
end

local function getCharacterDisplayName(ply, activeCharacter)
    if LeopardRP.Characters and LeopardRP.Characters.GetPlayerCharacterName then
        local resolved = tostring(LeopardRP.Characters.GetPlayerCharacterName(ply, ""))
        if resolved ~= "" and resolved ~= "Unknown" then
            return resolved
        end
    end

    if istable(activeCharacter) and isstring(activeCharacter.name) and activeCharacter.name ~= "" then
        return tostring(activeCharacter.name)
    end

    local nwName = IsValid(ply) and tostring(ply:GetNWString("LeopardRP.CharacterName", "")) or ""
    if nwName ~= "" then
        return nwName
    end

    return IsValid(ply) and tostring(ply:Nick() or "Unknown") or "Unknown"
end

local function getDivisionText(activeCharacter)
    if istable(activeCharacter) and isstring(activeCharacter.division) and activeCharacter.division ~= "" then
        return tostring(activeCharacter.division)
    end

    return ""
end

local function getRankData(activeCharacter)
    if not istable(activeCharacter) then
        return "", "", 0
    end

    local rankID = tostring(activeCharacter.rankID or "")
    local rankName = tostring(activeCharacter.rank or "")
    if rankName == "" and LeopardRP.GetRankName then
        rankName = tostring(LeopardRP.GetRankName(rankID) or "")
    end

    local rankOrder = LeopardRP.GetRankOrder and tonumber(LeopardRP.GetRankOrder(rankID) or 0) or 0
    return rankName, rankID, rankOrder
end

local function getSecondaryPosition(activeCharacter)
    if not istable(activeCharacter) then
        return ""
    end

    local customData = istable(activeCharacter.customData) and activeCharacter.customData or {}
    local position = tostring(customData.position or customData.assignment or "")
    return position
end

local function getActiveAdminRank(ply)
    if not IsValid(ply) then return "", false end
    if not (Personnel.CanAccessAdminPanel and Personnel.CanAccessAdminPanel(ply)) then
        return "", false
    end

    local rankName = ply:IsSuperAdmin() and "Super Admin" or "Admin"
    if ply.GetUserGroup then
        local groupName = string.Trim(tostring(ply:GetUserGroup() or ""))
        if groupName ~= "" then
            rankName = groupName
        end
    end

    return rankName, true
end

local function getActiveGMRank(ply)
    if not IsValid(ply) then return "", false end
    if not (LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank and LeopardRP.GameMaster.IsClockedIn) then
        return "", false
    end

    local rankID = tostring(LeopardRP.GameMaster.GetPermissionRank(ply:SteamID64()) or "none")
    local clocked = LeopardRP.GameMaster.IsClockedIn(ply) == true
    if rankID == "none" then
        return "", false
    end

    local rankDef = LeopardRP.GameMaster.GetRankDefinition and LeopardRP.GameMaster.GetRankDefinition(rankID) or nil
    return tostring(rankDef and rankDef.Name or rankID), clocked
end

local function buildManifestData()
    local playersData = {}

    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) then
            local activeCharacter = getActiveCharacterForPlayer(target)
            local rankName, rankID, rankOrder = getRankData(activeCharacter)
            local adminRank, adminClocked = getActiveAdminRank(target)
            local gmRank, gmClocked = getActiveGMRank(target)

            table.insert(playersData, {
                steamID = tostring(target:SteamID() or ""),
                steamID64 = tostring(target:SteamID64() or ""),
                steamName = tostring(target:Nick() or "Unknown"),
                characterName = getCharacterDisplayName(target, activeCharacter),
                division = getDivisionText(activeCharacter),
                rankName = rankName,
                rankID = rankID,
                rankOrder = rankOrder,
                secondaryPosition = getSecondaryPosition(activeCharacter),
                adminRank = adminRank,
                adminClockedIn = adminClocked,
                gmRank = gmRank,
                gmClockedIn = gmClocked,
                joinTimestamp = tonumber(target.LeopardRPJoinTimestamp) or os.time(),
                ping = tonumber(target:Ping() or 0) or 0,
            })
        end
    end

    return {
        serverName = tostring(GetHostName() or "Garry's Mod Server"),
        timestamp = os.time(),
        stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
        playersOnline = #playersData,
        maxPlayers = game.MaxPlayers(),
        players = playersData,
    }
end

local REPORT_CATEGORIES = {
    harassment = true,
    failrp = true,
    metagaming = true,
    rdm = true,
    exploit = true,
    chat_abuse = true,
    other = true,
}

local function hasLiveAdminReviewers()
    local count = 0
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) and Personnel.CanAccessAdminPanel and Personnel.CanAccessAdminPanel(target) then
            count = count + 1
        end
    end

    return count
end

local function notifyAdminReviewers(reporterCharacterName, targetCharacterName, category, description)
    local adminsOnline = 0
    for _, target in ipairs(player.GetAll()) do
        if IsValid(target) and Personnel.CanAccessAdminPanel and Personnel.CanAccessAdminPanel(target) then
            adminsOnline = adminsOnline + 1
            target:ChatPrint(string.format("[LeopardRP Report] %s reported %s (%s): %s", reporterCharacterName, targetCharacterName, category, description))
        end
    end

    return adminsOnline
end

local function LogPersonnelEvent(category, actorPly, targetName, targetSteamID64, message)
    if not EnsurePersonnelTables() then return end

    local actorName, actorSteamID64, actorCharacterName = GetActorIdentity(actorPly)
    local query = string.format(
        "INSERT INTO leopardrp_personnel_logs (timestamp, category, actor_name, actor_steamid64, actor_character_name, target_name, target_steamid64, message) VALUES (%d, %s, %s, %s, %s, %s, %s, %s)",
        os.time(),
        sql.SQLStr(tostring(category or "general")),
        sql.SQLStr(tostring(actorName or "System")),
        sql.SQLStr(tostring(actorSteamID64 or "0")),
        sql.SQLStr(tostring(actorCharacterName or actorName or "System")),
        sql.SQLStr(tostring(targetName or "")),
        sql.SQLStr(tostring(targetSteamID64 or "")),
        sql.SQLStr(tostring(message or ""))
    )

    local result = sql.Query(query)
    if result == false then
        print("[LeopardRP Personnel] Log insert failed: " .. tostring(sql.LastError() or "unknown error"))
    end
end

Personnel.LogEvent = LogPersonnelEvent

local function BuildLogData(searchText, categoryFilter, sortMode)
    local loweredSearch = string.lower(string.Trim(searchText or ""))
    local loweredCategory = string.lower(string.Trim(categoryFilter or ""))
    local normalizedSort = string.lower(string.Trim(sortMode or "newest"))
    local rows = sql.Query("SELECT id, timestamp, category, actor_name, actor_steamid64, actor_character_name, target_name, target_steamid64, message FROM leopardrp_personnel_logs ORDER BY timestamp DESC LIMIT 500")
    if rows == false then
        print("[LeopardRP Personnel] Log query failed: " .. tostring(sql.LastError() or "unknown error"))
        return {}
    end

    local list = {}
    for _, row in ipairs(istable(rows) and rows or {}) do
        local textBlob = string.lower(table.concat({
            tostring(row.category or ""),
            tostring(row.actor_name or ""),
            tostring(row.actor_steamid64 or ""),
            tostring(row.actor_character_name or ""),
            tostring(row.target_name or ""),
            tostring(row.target_steamid64 or ""),
            tostring(row.message or "")
        }, " "))

        local categoryMatches = loweredCategory == "" or loweredCategory == "all" or string.lower(tostring(row.category or "")) == loweredCategory
        if categoryMatches and (loweredSearch == "" or string.find(textBlob, loweredSearch, 1, true)) then
            table.insert(list, {
                id = tonumber(row.id) or 0,
                timestamp = tonumber(row.timestamp) or 0,
                category = tostring(row.category or "general"),
                actorName = tostring(row.actor_name or ""),
                actorSteamID64 = tostring(row.actor_steamid64 or ""),
                actorCharacterName = tostring(row.actor_character_name or ""),
                targetName = tostring(row.target_name or ""),
                targetSteamID64 = tostring(row.target_steamid64 or ""),
                message = tostring(row.message or "")
            })
        end
    end

    if normalizedSort == "oldest" then
        table.sort(list, function(a, b)
            return (a.timestamp or 0) < (b.timestamp or 0)
        end)
    elseif normalizedSort == "category" then
        table.sort(list, function(a, b)
            local ac = string.lower(tostring(a.category or ""))
            local bc = string.lower(tostring(b.category or ""))
            if ac == bc then
                return (a.timestamp or 0) > (b.timestamp or 0)
            end
            return ac < bc
        end)
    elseif normalizedSort == "actor" then
        table.sort(list, function(a, b)
            local an = string.lower(tostring(a.actorCharacterName or a.actorName or ""))
            local bn = string.lower(tostring(b.actorCharacterName or b.actorName or ""))
            if an == bn then
                return (a.timestamp or 0) > (b.timestamp or 0)
            end
            return an < bn
        end)
    elseif normalizedSort == "target" then
        table.sort(list, function(a, b)
            local an = string.lower(tostring(a.targetName or ""))
            local bn = string.lower(tostring(b.targetName or ""))
            if an == bn then
                return (a.timestamp or 0) > (b.timestamp or 0)
            end
            return an < bn
        end)
    end

    return list
end

local BuildProfilesBySteamID
local GetPlayerMetaRows

local function SendJSON(ply, netString, payload)
    if not IsValid(ply) then return end

    local jsonPayload = util.TableToJSON(payload or {}, false) or "{}"
    local compressedPayload = util.Compress(jsonPayload)

    net.Start(netString)
    net.WriteBool(compressedPayload ~= nil)
    if compressedPayload then
        net.WriteUInt(#compressedPayload, 32)
        net.WriteData(compressedPayload, #compressedPayload)
    else
        net.WriteString(jsonPayload)
    end
    net.Send(ply)
end

local function FindRankOrder(rankID, fallback)
    local order = LeopardRP.GetRankOrder and LeopardRP.GetRankOrder(rankID)
    return tonumber(order) or tonumber(fallback) or 1
end

local function EnsureSecondaryRankDefaults()
    if not EnsurePersonnelTables() then return end

    local countRows = sql.Query("SELECT COUNT(*) AS c FROM leopardrp_secondary_rank_definitions")
    local currentCount = tonumber(istable(countRows) and istable(countRows[1]) and countRows[1].c or 0) or 0
    if currentCount > 0 then return end

    local defaults = {
        { name = "Commanding Officer (CO)", department = "Command", min = "captain", max = "captain" },
        { name = "Acting Captain", department = "Command", min = "commander", max = "commander" },
        { name = "Executive Officer (XO)", department = "Command", min = "lieutenant_commander", max = "captain" },
        { name = "Second Officer", department = "Command", min = "lieutenant", max = "commander" },
        { name = "Chief Engineer", department = "Engineering", min = "lieutenant", max = "fleet_captain" },
        { name = "Chief Operations Officer", department = "Operations", min = "lieutenant", max = "fleet_captain" },
        { name = "Chief Transporter Officer", department = "Operations", min = "ensign", max = "fleet_captain" },
        { name = "Transporter Officer", department = "Operations", min = "crewman_first_class", max = "fleet_captain" },
        { name = "Chief Tactical Officer", department = "Tactical", min = "lieutenant", max = "fleet_captain" },
        { name = "Chief of Security", department = "Security", min = "lieutenant", max = "fleet_captain" },
        { name = "Chief Science Office", department = "Science", min = "lieutenant", max = "fleet_captain" },
        { name = "Chief Medical Officer", department = "Medical", min = "lieutenant", max = "fleet_captain" },
        { name = "Counselor", department = "Medical", min = "ensign", max = "fleet_captain" }
    }

    for _, entry in ipairs(defaults) do
        sql.Query(string.format(
            "INSERT INTO leopardrp_secondary_rank_definitions (name, department, min_rank_order, max_rank_order, created_by_steamid64, created_at) VALUES (%s, %s, %d, %d, %s, %d)",
            sql.SQLStr(tostring(entry.name or "")),
            sql.SQLStr(tostring(entry.department or "Operations")),
            FindRankOrder(entry.min, 1),
            FindRankOrder(entry.max, FindRankOrder(entry.min, 1)),
            sql.SQLStr("system"),
            os.time()
        ))
    end
end

local function BuildSecondaryRankDefinitions(searchText)
    EnsureSecondaryRankDefaults()

    local loweredSearch = string.lower(string.Trim(searchText or ""))
    local rows = sql.Query("SELECT id, name, department, min_rank_order, max_rank_order, enforce_department, enforce_rank_limits, created_by_steamid64, created_at FROM leopardrp_secondary_rank_definitions ORDER BY department ASC, name ASC")
    if rows == false then
        print("[LeopardRP Personnel] Secondary rank definition query failed: " .. tostring(sql.LastError() or "unknown error"))
        return {}
    end

    local list = {}
    local seenDefinitions = {}
    for _, row in ipairs(istable(rows) and rows or {}) do
        local minOrder = tonumber(row.min_rank_order) or 1
        local maxOrder = tonumber(row.max_rank_order) or minOrder
        local minRank = LeopardRP.GetRankByOrder and LeopardRP.GetRankByOrder(minOrder) or nil
        local maxRank = LeopardRP.GetRankByOrder and LeopardRP.GetRankByOrder(maxOrder) or nil
        local definitionKey = string.lower(table.concat({
            tostring(row.name or ""),
            tostring(row.department or ""),
            tostring(minOrder),
            tostring(maxOrder)
        }, "|"))

        if not seenDefinitions[definitionKey] then
            seenDefinitions[definitionKey] = true

            local blob = string.lower(table.concat({
                tostring(row.name or ""),
                tostring(row.department or ""),
                tostring(minRank and minRank.Name or ""),
                tostring(maxRank and maxRank.Name or "")
            }, " "))

            if loweredSearch == "" or string.find(blob, loweredSearch, 1, true) then
                table.insert(list, {
                    id = tonumber(row.id) or 0,
                    name = tostring(row.name or ""),
                    department = tostring(row.department or ""),
                    minRankOrder = minOrder,
                    maxRankOrder = maxOrder,
                    minRankName = tostring(minRank and minRank.Name or tostring(minOrder)),
                    maxRankName = tostring(maxRank and maxRank.Name or tostring(maxOrder)),
                    enforceDepartment = tonumber(row.enforce_department) ~= 0,
                    enforceRankLimits = tonumber(row.enforce_rank_limits) ~= 0,
                    createdBySteamID64 = tostring(row.created_by_steamid64 or ""),
                    createdAt = tonumber(row.created_at) or 0
                })
            end
        end
    end

    return list
end

local function GetSecondaryRankDefinition(definitionID)
    local rows = sql.Query("SELECT id, name, department, min_rank_order, max_rank_order, enforce_department, enforce_rank_limits FROM leopardrp_secondary_rank_definitions WHERE id = " .. sql.SQLStr(tostring(definitionID or 0)) .. " LIMIT 1")
    if rows == false or not istable(rows) or not istable(rows[1]) then
        return nil
    end

    local row = rows[1]
    return {
        id = tonumber(row.id) or 0,
        name = tostring(row.name or ""),
        department = tostring(row.department or ""),
        minRankOrder = tonumber(row.min_rank_order) or 1,
        maxRankOrder = tonumber(row.max_rank_order) or tonumber(row.min_rank_order) or 1,
        enforceDepartment = tonumber(row.enforce_department) ~= 0,
        enforceRankLimits = tonumber(row.enforce_rank_limits) ~= 0
    }
end

local BuildOnlineLookup

local function EnsureCharacterManagementData(characterRecord)
    if not istable(characterRecord) then return {} end

    characterRecord.customData = istable(characterRecord.customData) and characterRecord.customData or {}
    characterRecord.customData.activityLevel = string.Trim(tostring(characterRecord.customData.activityLevel or "active_duty"))
    characterRecord.customData.position = string.Trim(tostring(characterRecord.customData.position or characterRecord.customData.assignment or ""))
    characterRecord.customData.trainingRecords = istable(characterRecord.customData.trainingRecords) and characterRecord.customData.trainingRecords or {}
    characterRecord.customData.trainingHistory = istable(characterRecord.customData.trainingHistory) and characterRecord.customData.trainingHistory or {}
    characterRecord.customData.promotionHistory = istable(characterRecord.customData.promotionHistory) and characterRecord.customData.promotionHistory or {}
    characterRecord.customData.demotionHistory = istable(characterRecord.customData.demotionHistory) and characterRecord.customData.demotionHistory or {}
    characterRecord.customData.lastJoined = tonumber(characterRecord.customData.lastJoined) or tonumber(characterRecord.createdAt) or os.time()
    characterRecord.customData.lastActive = tonumber(characterRecord.customData.lastActive) or tonumber(characterRecord.updatedAt) or characterRecord.customData.lastJoined

    return characterRecord.customData
end

local function GetActivityLevelDefinition(activityID)
    local normalizedID = string.lower(string.Trim(tostring(activityID or "")))
    for _, activityData in ipairs(Personnel.ActivityLevels or {}) do
        if string.lower(tostring(activityData.ID or "")) == normalizedID then
            return activityData
        end
    end

    return Personnel.ActivityLevels and Personnel.ActivityLevels[1] or nil
end

local function BuildActivityColorTable(activityData)
    local colorData = activityData and activityData.Color or nil
    if not colorData then
        return { r = 255, g = 255, b = 255, a = 255 }
    end

    return {
        r = tonumber(colorData.r) or 255,
        g = tonumber(colorData.g) or 255,
        b = tonumber(colorData.b) or 255,
        a = tonumber(colorData.a) or 255
    }
end

local function GetLatestHistoryEntry(historyTable)
    if not istable(historyTable) then return nil end

    local latestEntry = nil
    for _, entry in ipairs(historyTable) do
        if istable(entry) then
            if not latestEntry or (tonumber(entry.timestamp) or 0) >= (tonumber(latestEntry.timestamp) or 0) then
                latestEntry = entry
            end
        end
    end

    return latestEntry
end

local function GetTrainingSummary(characterRecord)
    local customData = EnsureCharacterManagementData(characterRecord)
    local records = customData.trainingRecords or {}
    local completedCount = 0
    local activeCount = 0

    for _, record in ipairs(records) do
        local status = string.lower(tostring(istable(record) and record.status or ""))
        if status == "completed" then
            completedCount = completedCount + 1
        elseif status ~= "" then
            activeCount = activeCount + 1
        end
    end

    return {
        completed = completedCount,
        active = activeCount,
        total = #records
    }
end

local function BuildRosterEntry(steamID64, steamName, playerMeta, characterRecord, onlinePlayer)
    local customData = EnsureCharacterManagementData(characterRecord)
    local activityData = GetActivityLevelDefinition(customData.activityLevel)
    local latestPromotion = GetLatestHistoryEntry(customData.promotionHistory)
    local latestDemotion = GetLatestHistoryEntry(customData.demotionHistory)
    local trainingSummary = GetTrainingSummary(characterRecord)
    local characterRankOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(characterRecord.rankID) or 0) or 0

    return {
        steamID64 = steamID64,
        steamName = steamName,
        online = IsValid(onlinePlayer),
        characterID = characterRecord.id,
        characterName = tostring(characterRecord.name or "Unnamed"),
        rankID = characterRecord.rankID,
        rankName = tostring(characterRecord.rank and characterRecord.rank ~= "" and characterRecord.rank or (LeopardRP.GetRankName and LeopardRP.GetRankName(characterRecord.rankID) or characterRecord.rankID or "")),
        rankOrder = characterRankOrder,
        position = tostring(customData.position or customData.assignment or ""),
        species = tostring(characterRecord.species or ""),
        department = tostring(characterRecord.division or ""),
        lastActive = tonumber(customData.lastActive) or tonumber(playerMeta and playerMeta.lastPlayed) or tonumber(characterRecord.updatedAt) or tonumber(characterRecord.createdAt) or 0,
        lastJoined = tonumber(customData.lastJoined) or tonumber(playerMeta and playerMeta.lastPlayed) or tonumber(characterRecord.createdAt) or 0,
        activityLevel = tostring(customData.activityLevel or "active_duty"),
        activityLabel = tostring(activityData and activityData.Name or "Active Duty"),
        activityColor = BuildActivityColorTable(activityData),
        promotionDate = latestPromotion and (tonumber(latestPromotion.timestamp) or 0) or 0,
        promotionStardate = latestPromotion and tostring(latestPromotion.stardate or "") or "",
        demotionDate = latestDemotion and (tonumber(latestDemotion.timestamp) or 0) or 0,
        demotionStardate = latestDemotion and tostring(latestDemotion.stardate or "") or "",
        trainingSummary = trainingSummary,
        trainingRecords = customData.trainingRecords or {},
        promotionHistory = customData.promotionHistory or {},
        demotionHistory = customData.demotionHistory or {},
        assignment = tostring(customData.assignment or ""),
        clearanceWord = tostring(customData.clearanceWord or "Auto")
    }
end

local function BuildPersonnelRosterData(mode, requester, searchText, filters, sortKey, sortDirection)
    local loweredSearch = string.lower(string.Trim(searchText or ""))
    filters = istable(filters) and filters or {}
    local loweredDepartment = string.lower(string.Trim(tostring(filters.department or "")))
    local loweredRank = string.lower(string.Trim(tostring(filters.rank or "")))
    local loweredActivity = string.lower(string.Trim(tostring(filters.activity or "")))
    local normalizedSort = string.lower(string.Trim(sortKey or "rank"))
    local sortDescending = string.lower(string.Trim(sortDirection or "desc")) ~= "asc"

    local onlineLookup = BuildOnlineLookup()
    local profilesBySteamID = BuildProfilesBySteamID()
    local metaBySteamID = {}

    for _, row in ipairs(GetPlayerMetaRows()) do
        local steamID64 = tostring(row.steamid64 or "")
        if steamID64 ~= "" then
            metaBySteamID[steamID64] = {
                steamName = tostring(row.steam_name or "Unknown"),
                lastPlayed = tonumber(row.last_played) or 0
            }
        end
    end

    local roster = {}
    local seenRosterEntries = {}
    local captainOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder("captain") or 13) or 13
    for steamID64, profile in pairs(profilesBySteamID) do
        local playerMeta = metaBySteamID[steamID64] or { steamName = "Unknown", lastPlayed = 0 }
        local steamName = tostring(playerMeta.steamName or "Unknown")
        local characterList = Char_GetCharacterList(profile)

        for _, characterRecord in ipairs(characterList) do
            local normalizedCharacter = Char_NormalizeCharacterRecord(characterRecord)
            local normalizedRankOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(normalizedCharacter.rankID) or 0) or 0
            local normalizedDivision = string.lower(string.Trim(tostring(normalizedCharacter.division or "")))
            if normalizedRankOrder <= captainOrder and normalizedDivision ~= "admiral" then
                local onlinePlayer = onlineLookup[steamID64]
                if mode ~= "crew" or Personnel.CanCrewManageTarget(requester, normalizedCharacter) then
                    local entry = BuildRosterEntry(steamID64, steamName, playerMeta, normalizedCharacter, onlinePlayer)
                    local rosterKey = tostring(entry.steamID64 or "") .. ":" .. tostring(entry.characterID or "")
                    if not seenRosterEntries[rosterKey] then
                        seenRosterEntries[rosterKey] = true

                        local textBlob = string.lower(table.concat({
                            steamID64,
                            steamName,
                            tostring(entry.characterName or ""),
                            tostring(entry.species or ""),
                            tostring(entry.rankName or ""),
                            tostring(entry.position or ""),
                            tostring(entry.department or ""),
                            tostring(entry.activityLabel or "")
                        }, " "))

                        local searchMatches = loweredSearch == "" or string.find(textBlob, loweredSearch, 1, true)
                        local departmentMatches = loweredDepartment == "" or string.find(string.lower(tostring(entry.department or "")), loweredDepartment, 1, true)
                        local rankMatches = loweredRank == "" or string.find(string.lower(tostring(entry.rankName or "")), loweredRank, 1, true)
                        local activityMatches = loweredActivity == "" or string.find(string.lower(tostring(entry.activityLabel or "")), loweredActivity, 1, true)

                        if searchMatches and departmentMatches and rankMatches and activityMatches then
                            table.insert(roster, entry)
                        end
                    end
                end
            end
        end
    end

    table.sort(roster, function(a, b)
        local leftValue = nil
        local rightValue = nil

        if normalizedSort == "name" then
            leftValue = string.lower(tostring(a.characterName or ""))
            rightValue = string.lower(tostring(b.characterName or ""))
        elseif normalizedSort == "position" then
            leftValue = string.lower(tostring(a.position or ""))
            rightValue = string.lower(tostring(b.position or ""))
        elseif normalizedSort == "department" then
            leftValue = string.lower(tostring(a.department or ""))
            rightValue = string.lower(tostring(b.department or ""))
        elseif normalizedSort == "lastactive" then
            leftValue = tonumber(a.lastActive) or 0
            rightValue = tonumber(b.lastActive) or 0
        elseif normalizedSort == "lastjoined" then
            leftValue = tonumber(a.lastJoined) or 0
            rightValue = tonumber(b.lastJoined) or 0
        elseif normalizedSort == "activity" then
            leftValue = string.lower(tostring(a.activityLabel or ""))
            rightValue = string.lower(tostring(b.activityLabel or ""))
        elseif normalizedSort == "promotion" or normalizedSort == "promotiondate" then
            leftValue = tonumber(a.promotionDate) or 0
            rightValue = tonumber(b.promotionDate) or 0
        elseif normalizedSort == "demotion" or normalizedSort == "demotiondate" then
            leftValue = tonumber(a.demotionDate) or 0
            rightValue = tonumber(b.demotionDate) or 0
        else
            leftValue = tonumber(a.rankOrder) or 0
            rightValue = tonumber(b.rankOrder) or 0
        end

        if leftValue == rightValue then
            return string.lower(tostring(a.characterName or "")) < string.lower(tostring(b.characterName or ""))
        end

        if sortDescending then
            return leftValue > rightValue
        end

        return leftValue < rightValue
    end)

    return roster
end

local function BuildTrainingCatalogData()
    local catalog = {}
    for departmentName, courses in pairs(Personnel.TrainingCatalog or {}) do
        catalog[departmentName] = {}
        for _, courseData in ipairs(courses or {}) do
            table.insert(catalog[departmentName], {
                id = tostring(courseData.ID or ""),
                name = tostring(courseData.Name or ""),
                description = tostring(courseData.Description or ""),
                department = tostring(departmentName or "General"),
                requiredRankID = tostring(courseData.RequiredRankID or ""),
                prerequisite = tostring(courseData.Prerequisite or ""),
                requiresInstructor = courseData.RequiresInstructor == true,
                expires = courseData.Expires == true,
                expirationDays = tonumber(courseData.ExpirationDays) or 0
            })
        end
    end

    return catalog
end

local BuildCharacterDetails
local GetProfileForSteamID

local function BuildTrainingManagementData(mode, requester, steamID64, characterID, searchText)
    local roster = BuildPersonnelRosterData("admin", requester, searchText, {}, "rank", "desc")
    local onlineRoster = {}
    for _, entry in ipairs(roster or {}) do
        if entry.online == true then
            table.insert(onlineRoster, entry)
        end
    end
    local details = nil
    local selectedTraining = {}

    if steamID64 ~= "" and characterID ~= "" then
        details = BuildCharacterDetails(steamID64, characterID)
        if details and istable(details.character) then
            local profile = GetProfileForSteamID(steamID64)
            local selectedRecord = FindCharacter(profile, characterID)
            local customData = EnsureCharacterManagementData(selectedRecord or {})
            selectedTraining = {
                records = customData.trainingRecords or {},
                history = customData.trainingHistory or {},
                summary = selectedRecord and GetTrainingSummary(selectedRecord) or { completed = 0, mandatory = 0, total = 0, failed = 0 },
                promotionHistory = customData.promotionHistory or {},
                demotionHistory = customData.demotionHistory or {}
            }
        end
    end

    return {
        roster = onlineRoster,
        selected = details,
        training = selectedTraining,
        catalog = BuildTrainingCatalogData(),
        search = searchText or ""
    }
end

local function AppendHistoryEntry(historyTable, entry)
    if not istable(historyTable) then return end
    table.insert(historyTable, entry)
end

local function CharacterDepartmentMatches(characterRecord, department)
    if not istable(characterRecord) then return false end

    local dept = string.lower(string.Trim(tostring(department or "")))
    if dept == "" then return true end

    local division = string.lower(string.Trim(tostring(characterRecord.division or "")))
    local assignment = string.lower(string.Trim(tostring(characterRecord.customData and characterRecord.customData.assignment or "")))

    local divisionAliases = {
        command = "command",
        operations = "operations",
        science = "sciences",
        sciences = "sciences",
        medical = "sciences",
        tactical = "operations",
        security = "operations",
        engineering = "operations"
    }

    if division == (divisionAliases[dept] or dept) then
        return true
    end

    if assignment ~= "" and string.find(assignment, dept, 1, true) then
        return true
    end

    return false
end

local function CanAssignSecondaryRank(characterRecord, definition)
    if not istable(characterRecord) or not istable(definition) then return false, "Invalid character or rank definition." end

    if definition.enforceRankLimits ~= false then
        local rankOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(characterRecord.rankID) or 0) or 0
        if rankOrder < (definition.minRankOrder or 1) or rankOrder > (definition.maxRankOrder or definition.minRankOrder or 1) then
            return false, "Character rank does not meet secondary rank limits."
        end
    end

    if definition.enforceDepartment ~= false and not CharacterDepartmentMatches(characterRecord, definition.department) then
        return false, "Character department does not match this secondary rank."
    end

    return true
end

local function BuildCharacterSecondaryRanks(characterID)
    if not characterID or characterID == "" then return {} end

    local query = [[
        SELECT
            csr.secondary_rank_id,
            csr.assigned_by_steamid64,
            csr.assigned_at,
            srd.name,
            srd.department,
            srd.min_rank_order,
            srd.max_rank_order
        FROM leopardrp_character_secondary_ranks csr
        INNER JOIN leopardrp_secondary_rank_definitions srd ON srd.id = csr.secondary_rank_id
        WHERE csr.character_id = %s
        ORDER BY srd.department ASC, srd.name ASC
    ]]

    local rows = sql.Query(string.format(query, sql.SQLStr(tostring(characterID))))
    if rows == false then
        print("[LeopardRP Personnel] Secondary rank assignment query failed: " .. tostring(sql.LastError() or "unknown error"))
        return {}
    end

    local list = {}
    for _, row in ipairs(istable(rows) and rows or {}) do
        table.insert(list, {
            id = tonumber(row.secondary_rank_id) or 0,
            name = tostring(row.name or ""),
            department = tostring(row.department or ""),
            minRankOrder = tonumber(row.min_rank_order) or 1,
            maxRankOrder = tonumber(row.max_rank_order) or 1,
            assignedBySteamID64 = tostring(row.assigned_by_steamid64 or ""),
            assignedAt = tonumber(row.assigned_at) or 0
        })
    end

    return list
end

GetPlayerMetaRows = function()
    local metaRows = {}
    local seen = {}

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local steamID64 = tostring(ply:SteamID64() or "")
            if steamID64 ~= "" and not seen[steamID64] then
                seen[steamID64] = true
                metaRows[#metaRows + 1] = {
                    steamid64 = steamID64,
                    steam_name = tostring(ply:Nick() or "Unknown"),
                    last_played = os.time()
                }
            end
        end
    end

    if ix and ix.char and istable(ix.char.loaded) then
        for _, character in pairs(ix.char.loaded) do
            if character and character.GetSteamID then
                local steamID64 = tostring(character:GetSteamID() or "")
                if steamID64 ~= "" and not seen[steamID64] then
                    seen[steamID64] = true
                    metaRows[#metaRows + 1] = {
                        steamid64 = steamID64,
                        steam_name = tostring(character.GetName and character:GetName() or "Unknown"),
                        last_played = tonumber(character.GetLastJoinTime and character:GetLastJoinTime() or os.time()) or os.time()
                    }
                end
            end
        end
    end

    if #metaRows > 0 then
        return metaRows
    end

    local rows = sql.Query("SELECT steamid64, steam_name, last_played FROM leopardrp_personnel_players")
    if rows == false then
        print("[LeopardRP Personnel] Player meta query failed: " .. tostring(sql.LastError() or "unknown error"))
        return {}
    end

    return istable(rows) and rows or {}
end

local function GetProfileRows()
    local rows = {}
    local rowsBySteamID = {}

    local legacyRows = sql.Query("SELECT steamid64, profile_json, updated_at FROM leopardrp_character_profiles")
    if legacyRows ~= false and istable(legacyRows) then
        for _, row in ipairs(legacyRows) do
            local steamID64 = tostring(row.steamid64 or "")
            if steamID64 ~= "" then
                rowsBySteamID[steamID64] = {
                    steamid64 = steamID64,
                    profile_json = tostring(row.profile_json or "{}"),
                    updated_at = tonumber(row.updated_at) or 0
                }
            end
        end
    end

    if ix and ix.char and istable(ix.char.loaded) then
        local grouped = {}

        for _, character in pairs(ix.char.loaded) do
            if character and character.GetID and character.GetSteamID and character.GetName then
                local steamID64 = tostring(character:GetSteamID() or "")
                local charID = tostring(character:GetID() or "")

                if steamID64 ~= "" and charID ~= "" then
                    grouped[steamID64] = grouped[steamID64] or {
                        active = nil,
                        characters = {}
                    }

                    local customData = character.GetData and character:GetData("leopardrpCustomData", {}) or {}
                    local name = tostring(character:GetName() or "Unnamed")
                    local firstName = tostring(character.GetFirstName and character:GetFirstName() or "")
                    local middleName = tostring(character.GetMiddleName and character:GetMiddleName() or "")
                    local lastName = tostring(character.GetLastName and character:GetLastName() or "")

                    if firstName == "" or lastName == "" then
                        local splitFirst, splitLast = string.match(name, "^(%S+)%s+(.+)$")
                        firstName = firstName ~= "" and firstName or tostring(splitFirst or name)
                        lastName = lastName ~= "" and lastName or tostring(splitLast or "")
                    end

                    grouped[steamID64].characters[charID] = {
                        id = charID,
                        name = name,
                        firstName = firstName,
                        middleName = middleName,
                        lastName = lastName,
                        authCode = tostring(character.GetAuthCode and character:GetAuthCode() or ""),
                        personnelNumber = charID,
                        serviceNumber = charID,
                        species = tostring(character.GetSpecies and character:GetSpecies() or "Human"),
                        gender = tostring(character.GetGender and character:GetGender() or "Male"),
                        age = tonumber(character.GetAge and character:GetAge() or 24) or 24,
                        rankID = tostring(character.GetData and character:GetData("leopardrpRankID", "cadet") or "cadet"),
                        division = tostring(character.GetDivision and character:GetDivision() or "Operations"),
                        uniformType = tostring(character.GetUniformType and character:GetUniformType() or "Standard"),
                        bodyModel = tostring(character.GetBodyModel and character:GetBodyModel() or character:GetModel() or ""),
                        headModel = tostring(character.GetHeadModel and character:GetHeadModel() or ""),
                        headIndex = tonumber(character.GetHeadIndex and character:GetHeadIndex() or 1) or 1,
                        createdAt = tonumber(character.GetCreateTime and character:GetCreateTime() or os.time()) or os.time(),
                        updatedAt = tonumber(character.GetLastJoinTime and character:GetLastJoinTime() or os.time()) or os.time(),
                        customData = istable(customData) and table.Copy(customData) or {}
                    }

                    local owner = character.GetPlayer and character:GetPlayer() or nil
                    if IsValid(owner) and owner.GetCharacter and owner:GetCharacter() == character then
                        grouped[steamID64].active = charID
                    elseif grouped[steamID64].active == nil then
                        grouped[steamID64].active = charID
                    end
                end
            end
        end

        for steamID64, profile in pairs(grouped) do
            rowsBySteamID[steamID64] = {
                steamid64 = steamID64,
                profile_json = util.TableToJSON(profile, false) or "{}",
                updated_at = os.time()
            }
        end
    end

    if legacyRows == false then
        print("[LeopardRP Personnel] Profile query failed: " .. tostring(sql.LastError() or "unknown error"))
    end

    for _, row in pairs(rowsBySteamID) do
        rows[#rows + 1] = row
    end

    return rows
end

BuildOnlineLookup = function()
    local lookup = {}
    for _, onlinePlayer in ipairs(player.GetAll()) do
        lookup[onlinePlayer:SteamID64()] = onlinePlayer
    end

    return lookup
end

BuildProfilesBySteamID = function()
    local profilesBySteamID = {}
    for _, row in ipairs(GetProfileRows()) do
        local steamID64 = tostring(row.steamid64 or "")
        if steamID64 ~= "" then
            local decoded = util.JSONToTable(row.profile_json or "{}") or {}
            profilesBySteamID[steamID64] = Char_NormalizeProfile(decoded)
        end
    end

    return profilesBySteamID
end

local function BuildPlayerDirectoryData(searchText)
    local loweredSearch = string.lower(string.Trim(searchText or ""))
    local onlineLookup = BuildOnlineLookup()
    local profilesBySteamID = BuildProfilesBySteamID()

    local metaBySteamID = {}
    for _, row in ipairs(GetPlayerMetaRows()) do
        local steamID64 = tostring(row.steamid64 or "")
        if steamID64 ~= "" then
            metaBySteamID[steamID64] = {
                steamName = tostring(row.steam_name or "Unknown"),
                lastPlayed = tonumber(row.last_played) or 0
            }
        end
    end

    for steamID64, onlinePlayer in pairs(onlineLookup) do
        metaBySteamID[steamID64] = metaBySteamID[steamID64] or {
            steamName = onlinePlayer:Nick(),
            lastPlayed = os.time()
        }
    end

    local directory = {}
    for steamID64, meta in pairs(metaBySteamID) do
        local profile = profilesBySteamID[steamID64] or Char_CreateEmptyProfile()
        local characterList = Char_GetCharacterList(profile)
        local primaryCharacterName = ""
        if #characterList > 0 then
            local activeCharacter = Char_GetActiveCharacter(profile)
            primaryCharacterName = tostring(activeCharacter and activeCharacter.name or characterList[1].name or "")
        end

        local matched = loweredSearch == ""
        if not matched then
            if string.find(string.lower(steamID64), loweredSearch, 1, true) then
                matched = true
            elseif string.find(string.lower(meta.steamName or ""), loweredSearch, 1, true) then
                matched = true
            else
                for _, characterRecord in ipairs(characterList) do
                    if string.find(string.lower(tostring(characterRecord.name or "")), loweredSearch, 1, true) then
                        matched = true
                        break
                    end
                end
            end
        end

        if matched then
            table.insert(directory, {
                steamID64 = steamID64,
                steamName = meta.steamName,
                characterName = primaryCharacterName,
                lastPlayed = meta.lastPlayed,
                online = onlineLookup[steamID64] ~= nil,
                characterCount = #characterList
            })
        end
    end

    table.sort(directory, function(a, b)
        if a.online ~= b.online then
            return a.online
        end

        return (a.lastPlayed or 0) > (b.lastPlayed or 0)
    end)

    return directory
end

local function GetStoredStaffRank(steamID64)
    if IsForcedOwnerSubject(steamID64) then
        return "owner"
    end

    local rankMap = ReadGlobalData(DATAKEY_STAFF_RANKS, {})
    if istable(rankMap) then
        local mapped = rankMap[tostring(steamID64 or "")]
        if mapped ~= nil then
            return Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(mapped) or string.lower(string.Trim(tostring(mapped)))
        end
    end

    if not EnsurePersonnelTables() then return "none" end

    local rows = sql.Query("SELECT staff_rank FROM leopardrp_staff_ranks WHERE steamid64 = " .. sql.SQLStr(tostring(steamID64 or "")) .. " LIMIT 1")
    if rows == false or not istable(rows) or not istable(rows[1]) then
        return "none"
    end

    return Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(rows[1].staff_rank or "player") or string.lower(tostring(rows[1].staff_rank or "player"))
end

local function ApplyStoredRankToPlayer(ply)
    if not IsValid(ply) then return end
    ply:SetNWString("LeopardRP.StaffRank", GetStoredStaffRank(ply:SteamID64()))
end

local function GetPermissionProfile(steamID64)
    if IsForcedOwnerSubject(steamID64) then
        return {
            serverPermission = "owner",
            promotionProfile = "administrators",
            trainingPermission = true
        }
    end

    local profileMap = ReadGlobalData(DATAKEY_PERMISSION_PROFILES, {})
    if istable(profileMap) then
        local entry = profileMap[tostring(steamID64 or "")]
        if istable(entry) then
            return {
                serverPermission = Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(entry.serverPermission or "player") or tostring(entry.serverPermission or "player"),
                promotionProfile = string.lower(string.Trim(tostring(entry.promotionProfile or "commander_plus"))),
                trainingPermission = entry.trainingPermission == true
            }
        end
    end

    if not EnsurePersonnelTables() then
        return {
            serverPermission = "player",
            promotionProfile = "commander_plus",
            trainingPermission = false
        }
    end

    local rows = sql.Query("SELECT server_permission, promotion_profile, training_permission FROM leopardrp_permission_profiles WHERE steamid64 = " .. sql.SQLStr(tostring(steamID64 or "")) .. " LIMIT 1")
    if rows == false or not istable(rows) or not istable(rows[1]) then
        return {
            serverPermission = GetStoredStaffRank(steamID64),
            promotionProfile = "commander_plus",
            trainingPermission = false
        }
    end

    local row = rows[1]
    return {
        serverPermission = Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(row.server_permission or "player") or tostring(row.server_permission or "player"),
        promotionProfile = string.lower(string.Trim(tostring(row.promotion_profile or "commander_plus"))),
        trainingPermission = tonumber(row.training_permission) == 1
    }
end

local function IsWhitelistBypassPermission(permissionID)
    local normalized = Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(permissionID or "player") or tostring(permissionID or "player")
    return normalized == "senior_administrator" or normalized == "community_manager" or normalized == "owner"
end

local function IsWhitelistBypassBySteamID64(steamID64)
    local profile = GetPermissionProfile(steamID64)
    return IsWhitelistBypassPermission(profile and profile.serverPermission or "player")
end

local function CanEditConfigTabSettings(subject)
    if LeopardRP and LeopardRP.Config and isfunction(LeopardRP.Config.IsConfigTabOwner) then
        return LeopardRP.Config.IsConfigTabOwner(subject)
    end

    return false
end

local function NormalizeWhitelistSteamIDList(inputList)
    local out = {}
    local seen = {}

    for _, entry in ipairs(istable(inputList) and inputList or {}) do
        local steamID64 = string.Trim(tostring(entry or ""))
        if steamID64 ~= "" and string.match(steamID64, "^%d+$") and not seen[steamID64] then
            seen[steamID64] = true
            table.insert(out, steamID64)
        end
    end

    table.sort(out)
    return out
end

local function GetDevModeSettings()
    local stored = ReadGlobalData(DATAKEY_DEVMODE_SETTINGS, {
        whitelistEnabled = false,
        whitelistSteamIds = {}
    })

    stored = istable(stored) and stored or {
        whitelistEnabled = false,
        whitelistSteamIds = {}
    }

    return {
        whitelistEnabled = stored.whitelistEnabled == true,
        whitelistSteamIds = NormalizeWhitelistSteamIDList(stored.whitelistSteamIds or {})
    }
end

local function SaveDevModeSettingsData(payload, actorSteamID64)
    local whitelistEnabled = payload and payload.whitelistEnabled == true
    local whitelistSteamIds = NormalizeWhitelistSteamIDList(payload and payload.whitelistSteamIds or {})

    return WriteGlobalData(DATAKEY_DEVMODE_SETTINGS, {
        whitelistEnabled = whitelistEnabled,
        whitelistSteamIds = whitelistSteamIds,
        updatedBySteamID64 = tostring(actorSteamID64 or "system"),
        updatedAt = os.time()
    })
end

local function BuildLogisticsSettingsPayload()
    local stored = ReadGlobalData(DATAKEY_LOGISTICS_SETTINGS, {})
    stored = istable(stored) and stored or {}

    local liveW = math.max(tonumber(ix.config.Get("inventoryWidth", MIN_HELIX_INV_W)) or MIN_HELIX_INV_W, MIN_HELIX_INV_W)
    local liveH = math.max(tonumber(ix.config.Get("inventoryHeight", MIN_HELIX_INV_H)) or MIN_HELIX_INV_H, MIN_HELIX_INV_H)

    return {
        dropExcessAmmo = stored.dropExcessAmmo == true,
        dropOnDeath = stored.dropOnDeath == true,
        pickupFrame0 = stored.pickupFrame0 == true,
        pickupCompat = stored.pickupCompat == true,
        pickupMode = tonumber(stored.pickupMode) or 1,
        defaultCaseSize = tostring(stored.defaultCaseSize or string.format("%d %d", liveW, liveH))
    }
end

local function SaveLogisticsSettingsPayload(payload)
    if not istable(payload) then
        return false
    end

    local pickupMode = math.Clamp(math.floor(tonumber(payload.pickupMode) or 1), -1, 2)
    local pickupTimeMap = {
        [-1] = 0,
        [0] = 0.25,
        [1] = 0.5,
        [2] = 1
    }

    local width, height = string.match(string.Trim(tostring(payload.defaultCaseSize or "6 4")), "^(%d+)%s+(%d+)$")
    local invW = math.Clamp(tonumber(width) or ix.config.Get("inventoryWidth", MIN_HELIX_INV_W), MIN_HELIX_INV_W, 16)
    local invH = math.Clamp(tonumber(height) or ix.config.Get("inventoryHeight", MIN_HELIX_INV_H), MIN_HELIX_INV_H, 16)

    ix.config.Set("itemPickupTime", pickupTimeMap[pickupMode] or 0.5)
    ix.config.Set("inventoryWidth", invW)
    ix.config.Set("inventoryHeight", invH)

    local saved = WriteGlobalData(DATAKEY_LOGISTICS_SETTINGS, {
        dropExcessAmmo = payload.dropExcessAmmo == true,
        dropOnDeath = payload.dropOnDeath == true,
        pickupFrame0 = payload.pickupFrame0 == true,
        pickupCompat = payload.pickupCompat == true,
        pickupMode = pickupMode,
        defaultCaseSize = string.format("%d %d", invW, invH),
        updatedAt = os.time()
    })

    if not saved then
        return false
    end

    return true
end

local function EnforceHelixInventoryMinimums()
    if not ix or not ix.config or not ix.config.Get or not ix.config.Set then
        return
    end

    local width = tonumber(ix.config.Get("inventoryWidth", MIN_HELIX_INV_W)) or MIN_HELIX_INV_W
    local height = tonumber(ix.config.Get("inventoryHeight", MIN_HELIX_INV_H)) or MIN_HELIX_INV_H

    if width < MIN_HELIX_INV_W then
        ix.config.Set("inventoryWidth", MIN_HELIX_INV_W)
    end

    if height < MIN_HELIX_INV_H then
        ix.config.Set("inventoryHeight", MIN_HELIX_INV_H)
    end
end

local function IsWhitelistedSteamID64(steamID64, settings)
    for _, allowedID in ipairs(settings.whitelistSteamIds or {}) do
        if tostring(allowedID) == tostring(steamID64) then
            return true
        end
    end

    return false
end

local function GetWhitelistDeniedRows()
    local rows = sql.Query("SELECT steamid64, last_name, last_denied_at, denied_count FROM leopardrp_whitelist_denied_attempts ORDER BY last_denied_at DESC LIMIT 500")
    if rows == false then
        return {}
    end

    return istable(rows) and rows or {}
end

local function BuildWhitelistCandidateData(settings)
    local candidates = {}
    local seen = {}
    settings = settings or GetDevModeSettings()

    for _, entry in ipairs(BuildPlayerDirectoryData("")) do
        local steamID64 = tostring(entry.steamID64 or "")
        if steamID64 ~= "" and not seen[steamID64] and not IsWhitelistedSteamID64(steamID64, settings) then
            seen[steamID64] = true
            table.insert(candidates, {
                steamID64 = steamID64,
                steamName = tostring(entry.steamName or "Unknown"),
                characterName = tostring(entry.characterName or ""),
                online = entry.online == true,
                characterCount = tonumber(entry.characterCount or 0) or 0,
                lastPlayed = tonumber(entry.lastPlayed or 0) or 0,
                source = "directory",
            })
        end
    end

    for _, deniedRow in ipairs(GetWhitelistDeniedRows()) do
        local steamID64 = tostring(deniedRow.steamid64 or "")
        if steamID64 ~= "" and not seen[steamID64] and not IsWhitelistedSteamID64(steamID64, settings) then
            seen[steamID64] = true
            table.insert(candidates, {
                steamID64 = steamID64,
                steamName = tostring(deniedRow.last_name or "Unknown"),
                characterName = "",
                online = false,
                characterCount = 0,
                lastPlayed = tonumber(deniedRow.last_denied_at or 0) or 0,
                deniedCount = tonumber(deniedRow.denied_count or 1) or 1,
                source = "denied_join",
            })
        end
    end

    table.sort(candidates, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return (tonumber(a.lastPlayed) or 0) > (tonumber(b.lastPlayed) or 0)
    end)

    return candidates
end

local function EnforceWhitelistOnOnlinePlayers()
    local settings = GetDevModeSettings()
    if not settings.whitelistEnabled then return end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local steamID64 = tostring(ply:SteamID64() or "")
            if not IsWhitelistBypassBySteamID64(steamID64) and not IsWhitelistedSteamID64(steamID64, settings) then
                ply:Kick("Server whitelist is enabled. Contact Head Admin+ for access.")
            end
        end
    end
end

hook.Add("InitPostEntity", "LeopardRP.Personnel.DevModeWhitelist.EnforceOnStart", function()
    timer.Simple(1, function()
        EnforceWhitelistOnOnlinePlayers()
    end)
end)

hook.Add("PlayerInitialSpawn", "LeopardRP.Personnel.DevModeWhitelist.EnforceOnJoin", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        local settings = GetDevModeSettings()
        if not settings.whitelistEnabled then
            return
        end

        local steamID64 = tostring(ply:SteamID64() or "")
        if IsWhitelistBypassBySteamID64(steamID64) then
            return
        end

        if not IsWhitelistedSteamID64(steamID64, settings) then
            ply:Kick("Server whitelist is enabled. Contact Head Admin+ for access.")
        end
    end)
end)

local function SavePermissionProfile(steamID64, payload, actorSteamID64)
    local serverPermission = Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(payload.serverPermission or "player") or tostring(payload.serverPermission or "player")
    local promotionProfile = string.lower(string.Trim(tostring(payload.promotionProfile or "commander_plus")))
    local trainingPermission = payload.trainingPermission == true
    local targetID = tostring(steamID64 or "")

    local profileMap = ReadGlobalData(DATAKEY_PERMISSION_PROFILES, {})
    profileMap = istable(profileMap) and profileMap or {}
    profileMap[targetID] = {
        serverPermission = serverPermission,
        promotionProfile = promotionProfile,
        trainingPermission = trainingPermission,
        updatedBySteamID64 = tostring(actorSteamID64 or "system"),
        updatedAt = os.time()
    }

    if not WriteGlobalData(DATAKEY_PERMISSION_PROFILES, profileMap) then
        return false
    end

    local staffRankMap = ReadGlobalData(DATAKEY_STAFF_RANKS, {})
    staffRankMap = istable(staffRankMap) and staffRankMap or {}
    staffRankMap[targetID] = serverPermission
    WriteGlobalData(DATAKEY_STAFF_RANKS, staffRankMap)

    return true
end

local function BuildPermissionManagementData(mode, steamID64, characterID)
    local details = nil
    if steamID64 ~= "" and characterID ~= "" then
        details = BuildCharacterDetails(steamID64, characterID)
    end

    local gmRank = "none"
    if LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank then
        gmRank = tostring(LeopardRP.GameMaster.GetPermissionRank(steamID64) or "none")
    end

    return {
        mode = mode,
        steamID64 = steamID64,
        characterID = characterID,
        details = details,
        profile = GetPermissionProfile(steamID64),
        serverPermissions = Personnel.ServerPermissionLevels or {},
        promotionProfiles = Personnel.PromotionPermissionProfiles or {},
        activityLevels = Personnel.ActivityLevels or {},
        departments = LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.Divisions or {},
        ranks = LeopardRP.GetRankList and LeopardRP.GetRankList() or {},
        gmRanks = LeopardRP.GameMaster and LeopardRP.GameMaster.Ranks or {},
        adminRanks = {},
        gmRank = gmRank,
        adminRank = "none"
    }
end

local function GetPromotionProfileDefinition(profileID)
    local wanted = string.lower(string.Trim(tostring(profileID or "commander_plus")))
    for _, definition in ipairs(Personnel.PromotionPermissionProfiles or {}) do
        if string.lower(tostring(definition.ID or "")) == wanted then
            return definition
        end
    end

    return Personnel.PromotionPermissionProfiles and Personnel.PromotionPermissionProfiles[1] or {
        ID = "commander_plus",
        AllowPromote = false,
        AllowDemote = false,
        AllowPosition = false,
        AllowActivity = false,
        RequireAdmin = false
    }
end

local function BuildStaffRankData(searchText)
    local loweredSearch = string.lower(string.Trim(searchText or ""))
    local directory = BuildPlayerDirectoryData(searchText)
    local list = {}

    for _, playerEntry in ipairs(directory) do
        local steamID64 = tostring(playerEntry.steamID64 or "")
        local staffRank = GetStoredStaffRank(steamID64)
        local onlinePlayer = nil
        for _, candidate in ipairs(player.GetAll()) do
            if candidate:SteamID64() == steamID64 then
                onlinePlayer = candidate
                break
            end
        end
        local gameAdminGroup = IsValid(onlinePlayer) and tostring(onlinePlayer:GetUserGroup() or "") or ""

        local blob = string.lower(table.concat({
            steamID64,
            tostring(playerEntry.steamName or ""),
            tostring(staffRank or ""),
            tostring(gameAdminGroup or "")
        }, " "))

        if loweredSearch == "" or string.find(blob, loweredSearch, 1, true) then
            table.insert(list, {
                steamID64 = steamID64,
                steamName = tostring(playerEntry.steamName or "Unknown"),
                online = playerEntry.online == true,
                staffRank = staffRank,
                gameAdminGroup = gameAdminGroup
            })
        end
    end

    table.sort(list, function(a, b)
        if a.online ~= b.online then
            return a.online
        end
        return string.lower(a.steamName or "") < string.lower(b.steamName or "")
    end)

    return list
end

local function BuildProfileFromHelixCharacters(steamID64)
    if not ix or not ix.char or not istable(ix.char.loaded) then
        return nil
    end

    local profile = {
        active = nil,
        characters = {}
    }

    local foundAny = false

    for _, character in pairs(ix.char.loaded) do
        if character and character.GetSteamID and tostring(character:GetSteamID() or "") == tostring(steamID64 or "") then
            local charID = tostring(character.GetID and character:GetID() or "")
            if charID ~= "" then
                foundAny = true

                local customData = character.GetData and character:GetData("leopardrpCustomData", {}) or {}
                customData = istable(customData) and table.Copy(customData) or {}

                local fullName = tostring(character.GetName and character:GetName() or "Unnamed")
                local firstName = tostring(character.GetFirstName and character:GetFirstName() or "")
                local middleName = tostring(character.GetMiddleName and character:GetMiddleName() or "")
                local lastName = tostring(character.GetLastName and character:GetLastName() or "")

                if firstName == "" or lastName == "" then
                    local splitFirst, splitLast = string.match(fullName, "^(%S+)%s+(.+)$")
                    firstName = firstName ~= "" and firstName or tostring(splitFirst or fullName)
                    lastName = lastName ~= "" and lastName or tostring(splitLast or "")
                end

                local createdAt = tonumber(character.GetCreateTime and character:GetCreateTime() or os.time()) or os.time()
                local updatedAt = tonumber(character.GetLastJoinTime and character:GetLastJoinTime() or createdAt) or createdAt

                profile.characters[charID] = {
                    id = charID,
                    name = fullName,
                    firstName = firstName,
                    middleName = middleName,
                    lastName = lastName,
                    authCode = tostring(character.GetAuthCode and character:GetAuthCode() or ""),
                    personnelNumber = tonumber(character.GetData and character:GetData("leopardrpPersonnelNumber", nil) or nil) or tonumber(charID) or 100,
                    serviceNumber = tonumber(character.GetData and character:GetData("leopardrpServiceNumber", nil) or nil) or tonumber(charID) or 100,
                    species = tostring(character.GetSpecies and character:GetSpecies() or "Human"),
                    gender = tostring(character.GetGender and character:GetGender() or "Male"),
                    age = tonumber(character.GetAge and character:GetAge() or 24) or 24,
                    rankID = tostring(character.GetData and character:GetData("leopardrpRankID", "cadet") or "cadet"),
                    division = tostring(character.GetDivision and character:GetDivision() or "Operations"),
                    uniformType = tostring(character.GetUniformType and character:GetUniformType() or "Standard"),
                    bodyModel = tostring(character.GetBodyModel and character:GetBodyModel() or character.GetModel and character:GetModel() or ""),
                    headModel = tostring(character.GetHeadModel and character:GetHeadModel() or ""),
                    headIndex = tonumber(character.GetHeadIndex and character:GetHeadIndex() or 1) or 1,
                    createdAt = createdAt,
                    updatedAt = updatedAt,
                    creationDate = os.date("%Y-%m-%d", createdAt),
                    creationStardate = tostring(character.GetData and character:GetData("leopardrpCreationStardate", "") or ""),
                    customData = customData,
                }

                local owner = character.GetPlayer and character:GetPlayer() or nil
                if IsValid(owner) and owner.GetCharacter and owner:GetCharacter() == character then
                    profile.active = charID
                elseif not profile.active then
                    profile.active = charID
                end
            end
        end
    end

    if foundAny then
        return Char_NormalizeProfile(profile)
    end

    return nil
end

GetProfileForSteamID = function(steamID64)
    local helixProfile = BuildProfileFromHelixCharacters(steamID64)
    if helixProfile then
        return helixProfile
    end

    return Char_LoadProfile(steamID64) or Char_CreateEmptyProfile()
end

local function ApplyProfileCharacterToHelix(steamID64, characterRecord)
    if not ix or not ix.char or not istable(ix.char.loaded) then
        return
    end

    local targetID = tonumber(characterRecord and characterRecord.id or 0) or 0
    if targetID <= 0 then
        return
    end

    local character = ix.char.loaded[targetID]
    if not character or not character.GetSteamID or tostring(character:GetSteamID() or "") ~= tostring(steamID64 or "") then
        return
    end

    local data = characterRecord or {}
    local customData = istable(data.customData) and data.customData or {}

    if character.SetName and tostring(data.name or "") ~= "" then
        character:SetName(tostring(data.name))
    end
    if character.SetAge and tonumber(data.age) then
        character:SetAge(math.floor(tonumber(data.age) or 24))
    end
    if character.SetSpecies and tostring(data.species or "") ~= "" then
        character:SetSpecies(tostring(data.species))
    end
    if character.SetGender and tostring(data.gender or "") ~= "" then
        character:SetGender(tostring(data.gender))
    end
    if character.SetDivision and tostring(data.division or "") ~= "" then
        character:SetDivision(tostring(data.division))
    end
    if character.SetUniformType and tostring(data.uniformType or "") ~= "" then
        character:SetUniformType(tostring(data.uniformType))
    end
    if character.SetAuthCode and tostring(data.authCode or "") ~= "" then
        character:SetAuthCode(tostring(data.authCode))
    end

    character:SetData("leopardrpRankID", tostring(data.rankID or "cadet"))
    character:SetData("leopardrpCustomData", customData)

    if tostring(data.bodyModel or "") ~= "" then
        if character.SetBodyModel then
            character:SetBodyModel(tostring(data.bodyModel))
        end
        if character.SetModel then
            character:SetModel(tostring(data.bodyModel))
        end
    end

    if tostring(data.headModel or "") ~= "" and character.SetHeadModel then
        character:SetHeadModel(tostring(data.headModel))
    end

    if tonumber(data.headIndex) and character.SetHeadIndex then
        character:SetHeadIndex(math.max(1, math.floor(tonumber(data.headIndex) or 1)))
    end

    local client = character.GetPlayer and character:GetPlayer() or nil
    if IsValid(client) and client.GetCharacter and client:GetCharacter() == character then
        if Schema and Schema.RefreshLiveCharacterAppearance then
            Schema:RefreshLiveCharacterAppearance(client, character)
        else
            character:Sync(client)
        end
    end
end

local function SaveProfileForSteamID(steamID64, profile)
    local normalizedProfile = Char_NormalizeProfile(profile)
    Char_SaveProfile(steamID64, normalizedProfile)

    if istable(normalizedProfile) and istable(normalizedProfile.characters) then
        for _, characterData in pairs(normalizedProfile.characters) do
            if istable(characterData) then
                ApplyProfileCharacterToHelix(steamID64, characterData)
            end
        end
    end

    for _, target in ipairs(player.GetAll()) do
        if target:SteamID64() == steamID64 then
            target.LeopardRPCharacterProfile = normalizedProfile

            if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.SendProfileToPlayer then
                LeopardRP.CharacterCreation.SendProfileToPlayer(target, target.LeopardRPCharacterProfile)
            end

            if LeopardRP.Characters and LeopardRP.Characters.ApplyActiveCharacter then
                LeopardRP.Characters.ApplyActiveCharacter(target)
            end
        end
    end
end

local function BuildCharacterList(steamID64, requester, mode)
    local profile = GetProfileForSteamID(steamID64)
    local list = {}

    for _, characterRecord in ipairs(Char_GetCharacterList(profile)) do
        if mode ~= "crew" or Personnel.CanCrewManageTarget(requester, characterRecord) then
            table.insert(list, {
                id = characterRecord.id,
                name = characterRecord.name,
                rankID = characterRecord.rankID,
                rankName = LeopardRP.GetRankName and LeopardRP.GetRankName(characterRecord.rankID) or tostring(characterRecord.rankID or ""),
                division = characterRecord.division,
                species = characterRecord.species,
                age = characterRecord.age,
                status = Personnel.GetCharacterStatus(characterRecord),
                isEvent = characterRecord.isEvent == true
            })
        end
    end

    return list
end

local function FindCharacter(profile, characterID)
    if not istable(profile) or not istable(profile.characters) then return nil end

    local wantedID = tostring(characterID or "")
    if wantedID == "" then
        return nil
    end

    local direct = profile.characters[wantedID] or profile.characters[tonumber(wantedID)]
    if direct then
        return direct
    end

    for key, record in pairs(profile.characters) do
        if tostring(key) == wantedID or tostring(record and record.id or "") == wantedID then
            return record
        end
    end

    return nil
end

local function FetchDossierEntries(characterID)
    local rows = sql.Query("SELECT id, timestamp, stardate, author_steamid64, author_name, category, entry_text FROM leopardrp_character_dossiers WHERE character_id = " .. sql.SQLStr(characterID) .. " ORDER BY timestamp DESC")
    if rows == false then
        print("[LeopardRP Personnel] Dossier query failed: " .. tostring(sql.LastError() or "unknown error"))
        return {}
    end

    local entries = {}
    for _, row in ipairs(istable(rows) and rows or {}) do
        table.insert(entries, {
            id = tonumber(row.id) or 0,
            timestamp = tonumber(row.timestamp) or 0,
            stardate = tostring(row.stardate or ""),
            authorSteamID64 = tostring(row.author_steamid64 or ""),
            authorName = tostring(row.author_name or "Unknown"),
            category = tostring(row.category or "Service Notes"),
            text = tostring(row.entry_text or "")
        })
    end

    return entries
end

BuildCharacterDetails = function(steamID64, characterID)
    local profile = GetProfileForSteamID(steamID64)
    local characterRecord = FindCharacter(profile, characterID)
    if not characterRecord then return nil end

    local normalized = Char_NormalizeCharacterRecord(characterRecord)

    local details = {
        character = {
            id = normalized.id,
            name = normalized.name,
            firstName = normalized.firstName,
            middleName = normalized.middleName,
            lastName = normalized.lastName,
            authCode = normalized.authCode,
            personnelNumber = normalized.personnelNumber,
            serviceNumber = normalized.id,
            species = normalized.species,
            gender = normalized.gender,
            age = normalized.age,
            rankID = normalized.rankID,
            rankName = LeopardRP.GetRankName and LeopardRP.GetRankName(normalized.rankID) or tostring(normalized.rankID or ""),
            division = normalized.division,
            uniformType = normalized.uniformType,
            creationDate = normalized.creationDate,
            creationStardate = normalized.creationStardate,
            steamID64 = steamID64,
            lastLogin = os.time(),
            status = Personnel.GetCharacterStatus(normalized),
            bodyModel = normalized.bodyModel,
            headModel = normalized.headModel,
            headIndex = normalized.headIndex,
            assignment = (normalized.customData and normalized.customData.assignment) or "Active Duty",
            clearanceWord = (normalized.customData and normalized.customData.clearanceWord) or "Auto",
            activityLevel = (normalized.customData and normalized.customData.activityLevel) or "active_duty",
            position = (normalized.customData and normalized.customData.position) or (normalized.customData and normalized.customData.assignment) or "",
            lastJoined = tonumber(normalized.customData and normalized.customData.lastJoined) or tonumber(normalized.createdAt) or 0,
            lastActive = tonumber(normalized.customData and normalized.customData.lastActive) or tonumber(normalized.updatedAt) or tonumber(normalized.createdAt) or 0,
            backstory = normalized.backstory
        },
        dossierEntries = FetchDossierEntries(normalized.id),
        secondaryRanks = BuildCharacterSecondaryRanks(normalized.id),
        training = {
            records = EnsureCharacterManagementData(normalized).trainingRecords or {},
            history = EnsureCharacterManagementData(normalized).trainingHistory or {},
            summary = GetTrainingSummary(normalized),
            promotionHistory = EnsureCharacterManagementData(normalized).promotionHistory or {},
            demotionHistory = EnsureCharacterManagementData(normalized).demotionHistory or {}
        }
    }

    return details
end

local function SetRankByOrder(characterRecord, order)
    local rankData = LeopardRP.GetRankByOrder and LeopardRP.GetRankByOrder(order)
    if rankData then
        characterRecord.rankID = rankData.ID
    end
end

local function GetHighestRankOrder()
    local highest = 1
    for _, rankData in ipairs(LeopardRP.GetRankList and LeopardRP.GetRankList() or {}) do
        highest = math.max(highest, tonumber(rankData.Order) or 1)
    end
    return highest
end

local function RefreshCharacterAppearance(characterRecord)
    if not istable(characterRecord) then return end

    if LeopardRP.NormalizeRankID then
        characterRecord.rankID = LeopardRP.NormalizeRankID(characterRecord.rankID)
    end

    local captainOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder("fleet_captain") or 14) or 14
    local currentOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(characterRecord.rankID) or 1) or 1

    if currentOrder > captainOrder then
        characterRecord.division = "Admiral"
    end

    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.GetBodyModel then
        local resolvedBody = LeopardRP.CharacterCreation.GetBodyModel(characterRecord.division, characterRecord.gender, characterRecord.uniformType)
        if (not resolvedBody or resolvedBody == "") and characterRecord.division and LeopardRP.CharacterCreation.Bodies and LeopardRP.CharacterCreation.Bodies[characterRecord.division] then
            local divisionTable = LeopardRP.CharacterCreation.Bodies[characterRecord.division]
            if divisionTable.Male and (divisionTable.Male.Standard or divisionTable.Male.Dress) then
                characterRecord.gender = "Male"
                resolvedBody = LeopardRP.CharacterCreation.GetBodyModel(characterRecord.division, characterRecord.gender, characterRecord.uniformType)
            elseif divisionTable.Female and (divisionTable.Female.Standard or divisionTable.Female.Dress) then
                characterRecord.gender = "Female"
                resolvedBody = LeopardRP.CharacterCreation.GetBodyModel(characterRecord.division, characterRecord.gender, characterRecord.uniformType)
            end
        end

        if resolvedBody and resolvedBody ~= "" then
            characterRecord.bodyModel = resolvedBody
        end
    end
end

local function RefreshCharacterAuthCode(characterRecord)
    if not istable(characterRecord) then return end

    characterRecord.customData = istable(characterRecord.customData) and characterRecord.customData or {}

    local lastName = string.Trim(tostring(characterRecord.lastName or ""))
    if lastName == "" then
        local fullName = string.Trim(tostring(characterRecord.name or ""))
        local parts = string.Explode(" ", fullName)
        lastName = string.Trim(tostring(parts[#parts] or fullName or "Unknown"))
    end

    local authLib = ix and ix.leopardrp and ix.leopardrp.auth or nil
    local legacyUtil = LeopardRP and LeopardRP.Util or nil

    local personnelNumber = math.Clamp(tonumber(characterRecord.personnelNumber)
        or (authLib and authLib.GetPersonnelNumber and authLib.GetPersonnelNumber(characterRecord.name or lastName))
        or (legacyUtil and legacyUtil.GetPersonnelNumber and legacyUtil:GetPersonnelNumber(characterRecord.name or lastName))
        or 100, 100, 999)
    characterRecord.personnelNumber = personnelNumber

    local assignment = tostring(characterRecord.customData.assignment or characterRecord.division or "")
    local clearance = tostring(characterRecord.customData.clearanceWord or "Auto")

    if authLib and authLib.GenerateAuthCode then
        characterRecord.authCode = authLib.GenerateAuthCode(
            lastName,
            personnelNumber,
            tostring(characterRecord.name or ""),
            tostring(characterRecord.rankID or "cadet"),
            assignment,
            clearance
        )
    elseif legacyUtil and legacyUtil.GenerateAuthCode then
        characterRecord.authCode = legacyUtil:GenerateAuthCode(
            lastName,
            personnelNumber,
            tostring(characterRecord.name or ""),
            tostring(characterRecord.rankID or "cadet"),
            assignment,
            clearance
        )
    end
end

local function ApplyCharacterAction(ply, payload)
    if not istable(payload) then return false, "Invalid action payload." end

    local mode = tostring(payload.mode or "crew")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")
    local action = tostring(payload.action or "")

    if steamID64 == "" or characterID == "" or action == "" then
        return false, "Missing action data."
    end

    local isAdmin = Personnel.CanAccessAdminPanel(ply)
    local isCrew = Personnel.CanAccessCrewManager(ply)

    if mode == "admin" and not isAdmin then
        return false, "Administrative permissions required."
    end

    if mode == "crew" and not isCrew then
        return false, "Command permissions required."
    end

    local profile = GetProfileForSteamID(steamID64)
    local characterRecord = FindCharacter(profile, characterID)
    if not characterRecord then
        return false, "Character not found."
    end

    local normalized = Char_NormalizeCharacterRecord(characterRecord)

    if mode == "crew" and not Personnel.CanCrewManageTarget(ply, normalized) then
        return false, "You are not authorized to manage this character."
    end

    if mode == "crew" and tostring(ply:SteamID64()) == steamID64 and (action == "promote" or action == "demote") then
        return false, "You cannot promote or demote your own character in Crew Manager."
    end

    normalized.customData = istable(normalized.customData) and normalized.customData or {}

    local actorProfile = IsValid(ply) and GetPermissionProfile(ply:SteamID64()) or {
        serverPermission = "owner",
        promotionProfile = "administrators",
        trainingPermission = true
    }
    local actorPermission = Personnel.GetServerPermissionDefinition and Personnel.GetServerPermissionDefinition(actorProfile.serverPermission) or { Flags = {} }
    local promotionProfile = GetPromotionProfileDefinition(actorProfile.promotionProfile)
    local hasAdminOverride = isAdmin or (actorPermission.Flags and actorPermission.Flags.override == true)
    local canManageTraining = hasAdminOverride or actorProfile.trainingPermission == true or (actorPermission.Flags and actorPermission.Flags.training == true)

    local function requirePromotionPermission(permissionKey, failureMessage)
        if hasAdminOverride then return true end
        if promotionProfile.RequireAdmin then
            return false, "This permission profile requires administrative access."
        end
        if promotionProfile[permissionKey] ~= true then
            return false, failureMessage
        end
        return true
    end

    if action == "save_changes" or action == "edit_character" then
        normalized.name = string.Trim(tostring(payload.fields and payload.fields.name or normalized.name))
        normalized.age = math.max(0, tonumber(payload.fields and payload.fields.age) or tonumber(normalized.age) or 0)
        normalized.gender = string.Trim(tostring(payload.fields and payload.fields.gender or normalized.gender))
        normalized.species = string.Trim(tostring(payload.fields and payload.fields.species or normalized.species))
        normalized.uniformType = string.Trim(tostring(payload.fields and payload.fields.uniformType or normalized.uniformType))
        normalized.division = string.Trim(tostring(payload.fields and payload.fields.division or normalized.division))
        normalized.customData.assignment = string.Trim(tostring(payload.fields and payload.fields.assignment or normalized.customData.assignment or "Active Duty"))
        if mode == "admin" then
            normalized.customData.clearanceWord = string.Trim(tostring(payload.fields and payload.fields.clearanceWord or normalized.customData.clearanceWord or "Auto"))
        end
        RefreshCharacterAppearance(normalized)
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("edit", ply, normalized.name, steamID64, "Updated character fields.")
    elseif action == "set_activity" or action == "change_activity" then
        local allowed, errorMessage = requirePromotionPermission("AllowActivity", "Your permission profile cannot edit activity levels.")
        if not allowed then return false, errorMessage end
        normalized.customData.activityLevel = string.lower(string.Trim(tostring(payload.fields and (payload.fields.activityLevel or payload.fields.activity) or payload.activityLevel or normalized.customData.activityLevel or "active_duty")))
        LogPersonnelEvent("activity_change", ply, normalized.name, steamID64, "Set activity to " .. tostring(normalized.customData.activityLevel))
    elseif action == "assign_position" then
        local allowed, errorMessage = requirePromotionPermission("AllowPosition", "Your permission profile cannot edit character positions.")
        if not allowed then return false, errorMessage end
        normalized.customData.position = string.Trim(tostring(payload.fields and payload.fields.position or payload.position or normalized.customData.position or ""))
        normalized.customData.assignment = normalized.customData.position ~= "" and normalized.customData.position or normalized.customData.assignment
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("position_change", ply, normalized.name, steamID64, "Assigned position " .. tostring(normalized.customData.position))
    elseif action == "add_training" then
        if not canManageTraining then
            return false, "Training management permission is required."
        end
        local trainingName = string.Trim(tostring(payload.fields and payload.fields.trainingName or payload.trainingName or ""))
        if trainingName ~= "" then
            normalized.customData.trainingRecords = istable(normalized.customData.trainingRecords) and normalized.customData.trainingRecords or {}
            normalized.customData.trainingHistory = istable(normalized.customData.trainingHistory) and normalized.customData.trainingHistory or {}
            local trainingEntry = {
                id = util.CRC(string.format("%s:%s:%d", tostring(characterID), trainingName, os.time())),
                name = trainingName,
                status = string.Trim(tostring(payload.fields and payload.fields.status or payload.status or "Not Started")),
                assignedBy = IsValid(ply) and ply:Nick() or "System",
                assignedInstructor = string.Trim(tostring(payload.fields and payload.fields.instructor or payload.instructor or "")),
                dateAssigned = os.time(),
                dueDate = tonumber(payload.fields and payload.fields.dueDate or payload.dueDate) or 0,
                completionDate = tonumber(payload.fields and payload.fields.completionDate or payload.completionDate) or 0,
                completionStardate = tostring(payload.fields and payload.fields.completionStardate or payload.completionStardate or ""),
                notes = string.Trim(tostring(payload.fields and payload.fields.notes or payload.notes or "")),
                mandatory = payload.fields and payload.fields.mandatory == true or payload.mandatory == true
            }
            table.insert(normalized.customData.trainingRecords, trainingEntry)
            AppendHistoryEntry(normalized.customData.trainingHistory, {
                id = util.CRC(string.format("history:%s:%s:%d", tostring(characterID), trainingName, os.time())),
                timestamp = os.time(),
                stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
                event = "added",
                courseName = trainingName,
                status = trainingEntry.status,
                actor = IsValid(ply) and ply:Nick() or "System"
            })
            LogPersonnelEvent("training_add", ply, normalized.name, steamID64, "Added training course " .. trainingName)
        end
    elseif action == "complete_training" or action == "fail_training" or action == "remove_training" or action == "set_mandatory" or action == "schedule_retraining" or action == "add_training_notes" or action == "assign_instructor" then
        if not canManageTraining then
            return false, "Training management permission is required."
        end
        local trainingName = string.Trim(tostring(payload.fields and payload.fields.trainingName or payload.trainingName or ""))
        local records = istable(normalized.customData.trainingRecords) and normalized.customData.trainingRecords or {}
        local selectedRecord = nil
        for _, record in ipairs(records) do
            if string.lower(tostring(record.name or "")) == string.lower(trainingName) or tostring(record.id or "") == tostring(payload.trainingID or payload.trainingId or "") then
                selectedRecord = record
                break
            end
        end

        if selectedRecord then
            if action == "complete_training" then
                selectedRecord.status = "Completed"
                selectedRecord.completionDate = os.time()
                selectedRecord.completionStardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time())
                LogPersonnelEvent("training_complete", ply, normalized.name, steamID64, "Marked training completed: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "fail_training" then
                selectedRecord.status = "Failed"
                LogPersonnelEvent("training_failed", ply, normalized.name, steamID64, "Marked training failed: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "remove_training" then
                for index = #records, 1, -1 do
                    if records[index] == selectedRecord then
                        table.remove(records, index)
                        break
                    end
                end
                LogPersonnelEvent("training_remove", ply, normalized.name, steamID64, "Removed training course: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "set_mandatory" then
                selectedRecord.mandatory = payload.fields and payload.fields.mandatory == true or payload.mandatory == true
                LogPersonnelEvent("training_mandatory", ply, normalized.name, steamID64, "Updated mandatory flag for: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "schedule_retraining" then
                selectedRecord.status = "Mandatory"
                selectedRecord.dueDate = tonumber(payload.fields and payload.fields.dueDate or payload.dueDate) or 0
                LogPersonnelEvent("training_retrain", ply, normalized.name, steamID64, "Scheduled retraining for: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "add_training_notes" then
                selectedRecord.notes = string.Trim(tostring(payload.fields and payload.fields.notes or payload.notes or selectedRecord.notes or ""))
                LogPersonnelEvent("training_notes", ply, normalized.name, steamID64, "Updated training notes for: " .. tostring(selectedRecord.name or trainingName))
            elseif action == "assign_instructor" then
                selectedRecord.assignedInstructor = string.Trim(tostring(payload.fields and payload.fields.instructor or payload.instructor or selectedRecord.assignedInstructor or ""))
                LogPersonnelEvent("training_instructor", ply, normalized.name, steamID64, "Assigned instructor for: " .. tostring(selectedRecord.name or trainingName))
            end

            AppendHistoryEntry(normalized.customData.trainingHistory, {
                id = util.CRC(string.format("history:%s:%s:%d", tostring(characterID), tostring(selectedRecord.name or trainingName), os.time())),
                timestamp = os.time(),
                stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
                event = action,
                courseName = tostring(selectedRecord.name or trainingName),
                status = tostring(selectedRecord.status or ""),
                actor = IsValid(ply) and ply:Nick() or "System"
            })
        end
    elseif action == "promote" then
        local allowed, errorMessage = requirePromotionPermission("AllowPromote", "Your permission profile cannot promote characters.")
        if not allowed then return false, errorMessage end
        local order = LeopardRP.GetRankOrder and LeopardRP.GetRankOrder(normalized.rankID) or 1
        SetRankByOrder(normalized, math.min((order or 1) + 1, GetHighestRankOrder()))
        normalized.customData.promotionHistory = istable(normalized.customData.promotionHistory) and normalized.customData.promotionHistory or {}
        table.insert(normalized.customData.promotionHistory, {
            timestamp = os.time(),
            stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
            previousRank = tostring(payload.previousRank or ""),
            newRank = tostring(normalized.rankID or ""),
            authorizedBy = IsValid(ply) and ply:Nick() or "System",
            reason = tostring(payload.reason or "Promotion")
        })
        RefreshCharacterAppearance(normalized)
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("promote", ply, normalized.name, steamID64, "Promoted character to " .. tostring(normalized.rankID))
    elseif action == "demote" then
        local allowed, errorMessage = requirePromotionPermission("AllowDemote", "Your permission profile cannot demote characters.")
        if not allowed then return false, errorMessage end
        local order = LeopardRP.GetRankOrder and LeopardRP.GetRankOrder(normalized.rankID) or 1
        SetRankByOrder(normalized, math.max((order or 1) - 1, 1))
        normalized.customData.demotionHistory = istable(normalized.customData.demotionHistory) and normalized.customData.demotionHistory or {}
        table.insert(normalized.customData.demotionHistory, {
            timestamp = os.time(),
            stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
            previousRank = tostring(payload.previousRank or ""),
            newRank = tostring(normalized.rankID or ""),
            authorizedBy = IsValid(ply) and ply:Nick() or "System",
            reason = tostring(payload.reason or "Demotion")
        })
        RefreshCharacterAppearance(normalized)
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("demote", ply, normalized.name, steamID64, "Demoted character to " .. tostring(normalized.rankID))
    elseif action == "set_rank" then
        local allowPromote = promotionProfile.AllowPromote == true
        local allowDemote = promotionProfile.AllowDemote == true
        if not hasAdminOverride and promotionProfile.RequireAdmin then
            return false, "This permission profile requires administrative access."
        end
        if not hasAdminOverride and not (allowPromote or allowDemote) then
            return false, "Your permission profile cannot set RP ranks."
        end

        local requestedRankID = string.Trim(tostring(payload.fields and (payload.fields.rankID or payload.fields.rankId) or payload.rankID or payload.rankId or ""))
        local normalizedRankID = LeopardRP.NormalizeRankID and LeopardRP.NormalizeRankID(requestedRankID) or requestedRankID
        if normalizedRankID == "" or (LeopardRP.GetRankOrder and not LeopardRP.GetRankOrder(normalizedRankID)) then
            return false, "Invalid rank selection."
        end

        normalized.rankID = normalizedRankID
        RefreshCharacterAppearance(normalized)
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("set_rank", ply, normalized.name, steamID64, "Set character rank to " .. tostring(normalized.rankID))
    elseif action == "transfer_division" then
        normalized.division = string.Trim(tostring(payload.fields and payload.fields.division or normalized.division))
        normalized.gender = string.Trim(tostring(payload.fields and payload.fields.gender or normalized.gender))
        -- Keep existing body/head models when transferring division to avoid forcing a model swap.
        normalized.bodyModel = tostring(targetCharacter.bodyModel or normalized.bodyModel or "")
        normalized.headModel = tostring(targetCharacter.headModel or normalized.headModel or "")
        RefreshCharacterAuthCode(normalized)
        LogPersonnelEvent("transfer", ply, normalized.name, steamID64, "Transferred character to division " .. tostring(normalized.division))
    elseif action == "delete_character" then
        if mode ~= "admin" then
            return false, "Only administrators can delete characters."
        end

        normalized.customData.deleted = true
        LogPersonnelEvent("delete_character", ply, normalized.name, steamID64, "Marked character as deleted.")
    elseif action == "restore_character" then
        if mode ~= "admin" then
            return false, "Only administrators can restore characters."
        end

        normalized.customData.deleted = false
        LogPersonnelEvent("restore_character", ply, normalized.name, steamID64, "Restored character status.")
    elseif action == "delete_player_data" then
        if mode ~= "admin" then
            return false, "Only administrators can remove player data."
        end

        local deleteResult = sql.Query("DELETE FROM leopardrp_character_profiles WHERE steamid64 = " .. sql.SQLStr(steamID64))
        if deleteResult == false then
            return false, "Failed to remove player profile data."
        end

        sql.Query("DELETE FROM leopardrp_personnel_players WHERE steamid64 = " .. sql.SQLStr(steamID64))
        if istable(profile.characters) then
            for _, characterData in pairs(profile.characters) do
                if characterData and characterData.id then
                    sql.Query("DELETE FROM leopardrp_character_dossiers WHERE character_id = " .. sql.SQLStr(characterData.id))
                end
            end
        end

        LogPersonnelEvent("delete_player_data", ply, steamID64, steamID64, "Deleted all player profile data.")
        return true, "Player data deleted."
    else
        return false, "Unknown action."
    end

    profile.characters[characterID] = normalized
    SaveProfileForSteamID(steamID64, profile)

    return true, "Action applied."
end

local function AddDossierEntry(ply, payload)
    if not istable(payload) then return false, "Invalid dossier payload." end

    local mode = tostring(payload.mode or "crew")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")
    local category = string.Trim(tostring(payload.category or "Service Notes"))
    local entryText = string.Trim(tostring(payload.text or ""))

    if steamID64 == "" or characterID == "" or entryText == "" then
        return false, "Missing dossier entry fields."
    end

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            return false, "Administrative permissions required."
        end
    else
        if not Personnel.CanAccessCrewManager(ply) then
            return false, "Command permissions required."
        end
    end

    local profile = GetProfileForSteamID(steamID64)
    local characterRecord = FindCharacter(profile, characterID)
    if not characterRecord then
        return false, "Character not found."
    end

    if mode == "crew" and not Personnel.CanCrewManageTarget(ply, characterRecord) then
        return false, "You are not authorized to manage this character."
    end

    local timestamp = os.time()
    local stardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(timestamp)) or tostring(timestamp)
    local authorName = IsValid(ply) and ply:Nick() or "System"
    local authorSteamID64 = IsValid(ply) and ply:SteamID64() or "0"

    local insertQuery = string.format(
        "INSERT INTO leopardrp_character_dossiers (character_id, timestamp, stardate, author_steamid64, author_name, category, entry_text) VALUES (%s, %d, %s, %s, %s, %s, %s)",
        sql.SQLStr(characterID),
        timestamp,
        sql.SQLStr(stardate),
        sql.SQLStr(authorSteamID64),
        sql.SQLStr(authorName),
        sql.SQLStr(category ~= "" and category or "Service Notes"),
        sql.SQLStr(entryText)
    )

    local result = sql.Query(insertQuery)
    if result == false then
        return false, "Failed to add dossier entry."
    end

    LogPersonnelEvent("dossier_add", ply, tostring(characterRecord.name or characterID), steamID64, "Added dossier entry in category " .. tostring(category))

    return true, "Dossier entry added."
end

local function SendDirectory(ply, mode, searchText)
    local payload = {
        mode = mode,
        players = BuildPlayerDirectoryData(searchText),
        search = searchText or ""
    }

    SendJSON(ply, Personnel.NetworkStrings.ReceiveDirectory, payload)
end

hook.Add("PlayerInitialSpawn", "LeopardRP.Personnel.IndexPlayer", function(ply)
    if not EnsurePersonnelTables() then return end

    ply.LeopardRPJoinTimestamp = os.time()

    local steamID64 = ply:SteamID64()
    local query = string.format(
        "REPLACE INTO leopardrp_personnel_players (steamid64, steam_name, last_played) VALUES (%s, %s, %d)",
        sql.SQLStr(steamID64),
        sql.SQLStr(ply:Nick()),
        os.time()
    )

    sql.Query(query)
    ApplyStoredRankToPlayer(ply)
    local _, _, characterName = GetActorIdentity(ply)
    LogPersonnelEvent("player_join", ply, characterName, ply:SteamID64(), "Player joined the server.")
end)

hook.Add("Initialize", "LeopardRP.Personnel.SeedSecondaryRanks", function()
    EnsurePersonnelTables()
    EnsureSecondaryRankDefaults()
    EnforceHelixInventoryMinimums()
end)

hook.Add("CheckPassword", "LeopardRP.Personnel.DevModeWhitelist", function(steamID64)
    local settings = GetDevModeSettings()
    if not settings.whitelistEnabled then
        return
    end

    local normalizedSteamID64 = tostring(steamID64 or "")
    if IsWhitelistBypassBySteamID64(normalizedSteamID64) then
        return
    end

    if IsWhitelistedSteamID64(normalizedSteamID64, settings) then
        return
    end

    local deniedName = "Unknown"
    if isfunction(util.SteamIDFrom64) then
        local legacyID = tostring(util.SteamIDFrom64(normalizedSteamID64) or "")
        if legacyID ~= "" then
            deniedName = legacyID
        end
    end

    local existingRows = sql.Query("SELECT denied_count FROM leopardrp_whitelist_denied_attempts WHERE steamid64 = " .. sql.SQLStr(normalizedSteamID64) .. " LIMIT 1")
    local nextCount = 1
    if istable(existingRows) and istable(existingRows[1]) then
        nextCount = (tonumber(existingRows[1].denied_count) or 0) + 1
    end

    sql.Query(string.format(
        "REPLACE INTO leopardrp_whitelist_denied_attempts (steamid64, last_name, last_denied_at, denied_count) VALUES (%s, %s, %d, %d)",
        sql.SQLStr(normalizedSteamID64),
        sql.SQLStr(deniedName),
        os.time(),
        nextCount
    ))

    return false, "Server whitelist is enabled. Contact Head Admin+ for access."
end)

local function BuildRosterDataForRequest(mode, requester, searchText, filters, sortKey, sortDirection)
    return {
        mode = mode,
        search = searchText or "",
        filters = istable(filters) and filters or {},
        sortKey = sortKey or "rank",
        sortDirection = sortDirection or "desc",
        roster = BuildPersonnelRosterData(mode, requester, searchText, filters, sortKey, sortDirection)
    }
end

hook.Add("PlayerDisconnected", "LeopardRP.Personnel.UpdateLastPlayed", function(ply)
    if not EnsurePersonnelTables() then return end
    if not IsValid(ply) then return end

    local query = string.format(
        "REPLACE INTO leopardrp_personnel_players (steamid64, steam_name, last_played) VALUES (%s, %s, %d)",
        sql.SQLStr(ply:SteamID64()),
        sql.SQLStr(ply:Nick()),
        os.time()
    )

    sql.Query(query)
    local _, _, characterName = GetActorIdentity(ply)
    LogPersonnelEvent("player_leave", ply, characterName, ply:SteamID64(), "Player left the server.")
end)

hook.Add("PlayerSay", "LeopardRP.Personnel.LogChat", function(ply, text)
    if not IsValid(ply) or not text then return end
    local _, _, characterName = GetActorIdentity(ply)
    local trimmed = string.Trim(tostring(text or ""))
    local category = string.sub(trimmed, 1, 1) == "!" and "command" or "chat"
    LogPersonnelEvent(category, ply, characterName, ply:SteamID64(), trimmed)
end)

net.Receive(Personnel.NetworkStrings.RequestCrewManager, function(_, ply)
    if not EnsurePersonnelTables() then return end

    if not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required for Crew Manager.")
        return
    end

    net.Start(Personnel.NetworkStrings.OpenCrewManager)
    net.Send(ply)
    LogPersonnelEvent("crew_panel_open", ply, "", ply:SteamID64(), "Opened Crew Manager panel.")
end)

net.Receive(Personnel.NetworkStrings.RequestAdminPanel, function(_, ply)
    if not EnsurePersonnelTables() then return end
    Notify(ply, "Administration panel is disabled. Use ULX for administrative actions.")
end)

net.Receive(Personnel.NetworkStrings.RequestMenuAccess, function(_, ply)
    if not IsValid(ply) then return end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveMenuAccess, {
        canGameMasterMenu = CanAccessGMMenu(ply),
        canAdministrationMenu = false,
        canCrewManager = Personnel.CanAccessCrewManager(ply),
        canAdminPanel = false
    })
end)

net.Receive(Personnel.NetworkStrings.RequestDirectory, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local searchText = tostring(net.ReadString() or "")

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    SendDirectory(ply, mode, searchText)
    LogPersonnelEvent("panel_directory", ply, mode, ply:SteamID64(), "Requested directory data.")
end)

net.Receive(Personnel.NetworkStrings.RequestCharacterList, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local steamID64 = tostring(net.ReadString() or "")

    if steamID64 == "" then return end

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    local payload = {
        mode = mode,
        steamID64 = steamID64,
        characters = BuildCharacterList(steamID64, ply, mode)
    }

    SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterList, payload)
    LogPersonnelEvent("panel_character_list", ply, steamID64, steamID64, "Requested character list.")
end)

net.Receive(Personnel.NetworkStrings.RequestCharacterDetails, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local steamID64 = tostring(net.ReadString() or "")
    local characterID = tostring(net.ReadString() or "")

    if steamID64 == "" or characterID == "" then return end

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    local details = BuildCharacterDetails(steamID64, characterID)
    if not details then
        Notify(ply, "Character details unavailable.")
        return
    end

    if mode == "crew" and not Personnel.CanCrewManageTarget(ply, details.character) then
        Notify(ply, "You are not authorized to view this character.")
        return
    end

    local payload = {
        mode = mode,
        steamID64 = steamID64,
        characterID = characterID,
        details = details
    }

    SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterDetails, payload)
    LogPersonnelEvent("panel_character_details", ply, characterID, steamID64, "Requested character details.")
end)

net.Receive(Personnel.NetworkStrings.RequestLogs, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local searchText = tostring(net.ReadString() or "")
    local categoryFilter = tostring(net.ReadString() or "all")
    local sortMode = tostring(net.ReadString() or "newest")
    SendJSON(ply, Personnel.NetworkStrings.ReceiveLogs, {
        logs = BuildLogData(searchText, categoryFilter, sortMode),
        search = searchText,
        category = categoryFilter,
        sort = sortMode
    })
    LogPersonnelEvent("admin_logger", ply, "", ply:SteamID64(), "Requested logger data.")
end)

net.Receive(Personnel.NetworkStrings.RequestStaffRanks, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local searchText = tostring(net.ReadString() or "")
    SendJSON(ply, Personnel.NetworkStrings.ReceiveStaffRanks, {
        ranks = BuildStaffRankData(searchText),
        search = searchText
    })
    LogPersonnelEvent("admin_rank_management", ply, "", ply:SteamID64(), "Requested rank management data.")
end)

net.Receive(Personnel.NetworkStrings.SetStaffRank, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local targetSteamID64 = string.Trim(tostring(net.ReadString() or ""))
    local targetRank = Personnel.NormalizeServerPermission and Personnel.NormalizeServerPermission(net.ReadString() or "player") or string.lower(string.Trim(tostring(net.ReadString() or "player")))
    local validRanks = {
        player = true,
        trainer = true,
        moderator = true,
        administrator = true,
        senior_administrator = true,
        game_master = true,
        community_manager = true,
        owner = true
    }

    if targetSteamID64 == "" or not validRanks[targetRank] then
        Notify(ply, "Invalid rank management payload.")
        return
    end

    if IsForcedOwnerSubject(targetSteamID64) then
        targetRank = "owner"
    end

    local staffRankMap = ReadGlobalData(DATAKEY_STAFF_RANKS, {})
    staffRankMap = istable(staffRankMap) and staffRankMap or {}
    staffRankMap[targetSteamID64] = targetRank

    if not WriteGlobalData(DATAKEY_STAFF_RANKS, staffRankMap) then
        Notify(ply, "Failed to update staff rank.")
        return
    end

    local targetPlayer = player.GetBySteamID64(targetSteamID64)
    if not IsValid(targetPlayer) then
        for _, candidate in ipairs(player.GetAll()) do
            if candidate:SteamID64() == targetSteamID64 then
                targetPlayer = candidate
                break
            end
        end
    end
    if IsValid(targetPlayer) then
        ApplyStoredRankToPlayer(targetPlayer)
    end

    Notify(ply, "Staff rank updated for " .. targetSteamID64 .. ".")
    LogPersonnelEvent("admin_rank_set", ply, targetSteamID64, targetSteamID64, "Set staff rank to " .. targetRank)
end)

hook.Add("DoPlayerDeath", "LeopardRP.Personnel.HelixDropInventoryOnDeath", function(ply)
    if not IsValid(ply) then return end

    local settings = BuildLogisticsSettingsPayload()
    if settings.dropOnDeath ~= true then
        return
    end

    local character = ply.GetCharacter and ply:GetCharacter() or nil
    local inventory = character and character.GetInventory and character:GetInventory() or nil
    if not inventory then return end

    local toDrop = {}
    for _, item in inventory:Iter() do
        if item and item.id then
            toDrop[#toDrop + 1] = item.id
        end
    end

    for _, itemID in ipairs(toDrop) do
        local item = ix.item.instances[itemID]
        if item and item.invID == inventory:GetID() then
            item:Transfer(0, nil, nil, ply)
        end
    end
end)

local lastSafeWalkPositions = {}

local function HasStaffNoClipAccess(ply)
    if not IsValid(ply) then
        return false
    end

    if IsForcedOwnerSubject(ply) then
        return true
    end

    if LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank and LeopardRP.GameMaster.IsClockedIn and LeopardRP.GameMaster.HasRankAtLeast then
        local gmRank = tostring(LeopardRP.GameMaster.GetPermissionRank(ply:SteamID64()) or "none")
        if LeopardRP.GameMaster.IsClockedIn(ply) and LeopardRP.GameMaster.HasRankAtLeast(gmRank, "game_master") then
            return true
        end
    end

    if Personnel.CanAccessAdminPanel and Personnel.CanAccessAdminPanel(ply) then
        return true
    end

    return false
end

hook.Add("Think", "LeopardRP.Personnel.NoclipExploitGuard", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local steamID64 = tostring(ply:SteamID64() or "")

            if ply:GetMoveType() ~= MOVETYPE_NOCLIP then
                lastSafeWalkPositions[steamID64] = ply:GetPos()
            elseif not HasStaffNoClipAccess(ply) then
                local rollbackPos = lastSafeWalkPositions[steamID64] or ply:GetPos()
                ply:SetMoveType(MOVETYPE_WALK)
                ply:SetPos(rollbackPos)
                ply:SetVelocity(-ply:GetVelocity())
            end
        end
    end
end)

net.Receive(Personnel.NetworkStrings.RequestSecondaryRanks, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local steamID64 = tostring(net.ReadString() or "")
    local characterID = tostring(net.ReadString() or "")
    local searchText = tostring(net.ReadString() or "")

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    if mode == "crew" and steamID64 ~= "" and characterID ~= "" then
        local details = BuildCharacterDetails(steamID64, characterID)
        if not details or not Personnel.CanCrewManageTarget(ply, details.character) then
            Notify(ply, "You are not authorized to view secondary ranks for this character.")
            return
        end
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveSecondaryRanks, {
        mode = mode,
        steamID64 = steamID64,
        characterID = characterID,
        definitions = BuildSecondaryRankDefinitions(searchText),
        assignments = BuildCharacterSecondaryRanks(characterID),
        search = searchText
    })
end)

net.Receive(Personnel.NetworkStrings.RequestRoster, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local searchText = tostring(net.ReadString() or "")
    local filters = util.JSONToTable(net.ReadString() or "{}") or {}
    local sortKey = tostring(net.ReadString() or "rank")
    local sortDirection = tostring(net.ReadString() or "desc")

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveRoster, BuildRosterDataForRequest(mode, ply, searchText, filters, sortKey, sortDirection))
end)

net.Receive(Personnel.NetworkStrings.RequestTrainingManagement, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local mode = tostring(net.ReadString() or "crew")
    local steamID64 = tostring(net.ReadString() or "")
    local characterID = tostring(net.ReadString() or "")
    local searchText = tostring(net.ReadString() or "")

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveTrainingManagement, BuildTrainingManagementData(mode, ply, steamID64, characterID, searchText))
end)

net.Receive(Personnel.NetworkStrings.RequestPermissionManagement, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local mode = tostring(net.ReadString() or "admin")
    local steamID64 = tostring(net.ReadString() or "")
    local characterID = tostring(net.ReadString() or "")

    if steamID64 == "" then return end

    SendJSON(ply, Personnel.NetworkStrings.ReceivePermissionManagement, BuildPermissionManagementData(mode, steamID64, characterID))
end)

net.Receive(Personnel.NetworkStrings.RequestDevModeSettings, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    if not CanEditConfigTabSettings(ply) then
        Notify(ply, "Config tab owner permissions are required for Dev Mode settings.")
        return
    end

    local settings = GetDevModeSettings()
    SendJSON(ply, Personnel.NetworkStrings.ReceiveDevModeSettings, {
        whitelistEnabled = settings.whitelistEnabled,
        whitelistSteamIds = settings.whitelistSteamIds,
        whitelistCandidates = BuildWhitelistCandidateData(settings),
        canEdit = true,
    })
end)

net.Receive(Personnel.NetworkStrings.SaveDevModeSettings, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    if not CanEditConfigTabSettings(ply) then
        Notify(ply, "Config tab owner permissions are required for Dev Mode settings.")
        return
    end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local ok = SaveDevModeSettingsData(payload, ply:SteamID64())
    if not ok then
        Notify(ply, "Failed to save Dev Mode settings.")
        return
    end

    EnforceWhitelistOnOnlinePlayers()

    local settings = GetDevModeSettings()
    SendJSON(ply, Personnel.NetworkStrings.ReceiveDevModeSettings, {
        whitelistEnabled = settings.whitelistEnabled,
        whitelistSteamIds = settings.whitelistSteamIds,
        whitelistCandidates = BuildWhitelistCandidateData(settings),
        canEdit = true,
    })

    Notify(ply, "Dev Mode whitelist settings saved.")
    LogPersonnelEvent("dev_mode_whitelist", ply, "", ply:SteamID64(), string.format("Whitelist %s (%d entries)", settings.whitelistEnabled and "enabled" or "disabled", #settings.whitelistSteamIds))
end)

net.Receive(Personnel.NetworkStrings.RequestLogisticsSettings, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    if not CanEditConfigTabSettings(ply) then
        Notify(ply, "Config tab owner permissions are required for logistics settings.")
        return
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveLogisticsSettings, {
        canEdit = true,
        settings = BuildLogisticsSettingsPayload()
    })
end)

net.Receive(Personnel.NetworkStrings.SaveLogisticsSettings, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    if not CanEditConfigTabSettings(ply) then
        Notify(ply, "Config tab owner permissions are required for logistics settings.")
        return
    end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local ok = SaveLogisticsSettingsPayload(payload.settings or payload)
    if not ok then
        Notify(ply, "Failed to save logistics settings.")
        return
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveLogisticsSettings, {
        canEdit = true,
        settings = BuildLogisticsSettingsPayload()
    })

    Notify(ply, "Logistics settings saved globally.")
    LogPersonnelEvent("logistics_settings", ply, "", ply:SteamID64(), "Updated global inventory logistics settings.")
end)

net.Receive(Personnel.NetworkStrings.SavePermissionManagement, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local mode = tostring(payload.mode or "admin")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")
    local serverPermission = tostring(payload.serverPermission or "player")
    local promotionProfile = tostring(payload.promotionProfile or "commander_plus")
    local trainingPermission = payload.trainingPermission == true
    local gmRank = tostring(payload.gmRank or "none")

    if steamID64 == "" then
        Notify(ply, "Missing target player.")
        return
    end

    local saved = SavePermissionProfile(steamID64, {
        serverPermission = serverPermission,
        promotionProfile = promotionProfile,
        trainingPermission = trainingPermission
    }, IsValid(ply) and ply:SteamID64() or "system")

    if not saved then
        Notify(ply, "Failed to save permission profile.")
        return
    end

    if LeopardRP.GameMaster and LeopardRP.GameMaster.SetPermissionRank then
        LeopardRP.GameMaster.SetPermissionRank(steamID64, gmRank, IsValid(ply) and ply:Nick() or "System")
    end

    local targetPly = player.GetBySteamID64(steamID64)
    if IsValid(targetPly) then
        ApplyStoredRankToPlayer(targetPly)
    end

    if characterID ~= "" and istable(payload.roleplay) then
        local roleplay = payload.roleplay

        if tostring(roleplay.position or "") ~= "" then
            ApplyCharacterAction(ply, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                action = "assign_position",
                fields = { position = tostring(roleplay.position or "") }
            })
        end

        if tostring(roleplay.department or "") ~= "" then
            ApplyCharacterAction(ply, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                action = "transfer_division",
                fields = { division = tostring(roleplay.department or "") }
            })
        end

        if tostring(roleplay.activityLevel or "") ~= "" then
            ApplyCharacterAction(ply, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                action = "change_activity",
                fields = { activityLevel = tostring(roleplay.activityLevel or "") }
            })
        end

        if tostring(roleplay.rankID or "") ~= "" then
            ApplyCharacterAction(ply, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                action = "set_rank",
                fields = { rankID = tostring(roleplay.rankID or "") }
            })
        end

        if IsValid(targetPly) and targetPly.GetCharacter then
            local targetCharacter = targetPly:GetCharacter()
            if targetCharacter and tostring(targetCharacter:GetID() or "") == tostring(characterID) and Schema and Schema.RefreshLiveCharacterAppearance then
                Schema:RefreshLiveCharacterAppearance(targetPly, targetCharacter)
            end
        end
    end

    Notify(ply, "Permission profile saved.")
    SendJSON(ply, Personnel.NetworkStrings.ReceivePermissionManagement, BuildPermissionManagementData(mode, steamID64, characterID))
end)

net.Receive(Personnel.NetworkStrings.CreateSecondaryRank, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local mode = tostring(payload.mode or "crew")
    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    local name = string.Trim(tostring(payload.name or ""))
    local department = string.Trim(tostring(payload.department or ""))
    local minRankID = string.Trim(tostring(payload.minRankID or ""))
    local maxRankID = string.Trim(tostring(payload.maxRankID or ""))
    local enforceDepartment = payload.enforceDepartment == true
    local enforceRankLimits = payload.enforceRankLimits == true

    if name == "" then
        Notify(ply, "Secondary rank name is required.")
        return
    end

    if enforceDepartment and department == "" then
        Notify(ply, "Department is required when department matching is enabled.")
        return
    end

    local minOrder = FindRankOrder(minRankID, 1)
    local maxOrder = FindRankOrder(maxRankID, minOrder)
    if maxOrder < minOrder then
        minOrder, maxOrder = maxOrder, minOrder
    end

    local insertResult = sql.Query(string.format(
        "INSERT INTO leopardrp_secondary_rank_definitions (name, department, min_rank_order, max_rank_order, enforce_department, enforce_rank_limits, created_by_steamid64, created_at) VALUES (%s, %s, %d, %d, %d, %d, %s, %d)",
        sql.SQLStr(name),
        sql.SQLStr(enforceDepartment and department or ""),
        minOrder,
        maxOrder,
        enforceDepartment and 1 or 0,
        enforceRankLimits and 1 or 0,
        sql.SQLStr(ply:SteamID64()),
        os.time()
    ))

    if insertResult == false then
        Notify(ply, "Failed to create secondary rank definition.")
        return
    end

    Notify(ply, "Secondary rank definition created.")
    LogPersonnelEvent("secondary_rank_create", ply, name, ply:SteamID64(), "Created secondary rank definition.")

    SendJSON(ply, Personnel.NetworkStrings.ReceiveSecondaryRanks, {
        mode = mode,
        steamID64 = tostring(payload.steamID64 or ""),
        characterID = tostring(payload.characterID or ""),
        definitions = BuildSecondaryRankDefinitions(tostring(payload.search or "")),
        assignments = BuildCharacterSecondaryRanks(tostring(payload.characterID or "")),
        search = tostring(payload.search or "")
    })
end)

net.Receive(Personnel.NetworkStrings.SetCharacterSecondaryRank, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local mode = tostring(payload.mode or "crew")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")
    local definitionID = tonumber(payload.secondaryRankID) or 0
    local operation = string.lower(string.Trim(tostring(payload.operation or "assign")))

    if steamID64 == "" or characterID == "" or definitionID <= 0 then
        Notify(ply, "Invalid secondary rank payload.")
        return
    end

    if mode == "admin" then
        if not Personnel.CanAccessAdminPanel(ply) then
            Notify(ply, "Administrative permissions are required.")
            return
        end
    elseif not Personnel.CanAccessCrewManager(ply) then
        Notify(ply, "Commander-level permissions are required.")
        return
    end

    local profile = GetProfileForSteamID(steamID64)
    local characterRecord = FindCharacter(profile, characterID)
    if not characterRecord then
        Notify(ply, "Character not found.")
        return
    end

    if mode == "crew" and not Personnel.CanCrewManageTarget(ply, characterRecord) then
        Notify(ply, "You are not authorized to manage this character.")
        return
    end

    local definition = GetSecondaryRankDefinition(definitionID)
    if not definition then
        Notify(ply, "Secondary rank definition not found.")
        return
    end

    if operation == "remove" then
        local result = sql.Query("DELETE FROM leopardrp_character_secondary_ranks WHERE character_id = " .. sql.SQLStr(characterID) .. " AND secondary_rank_id = " .. sql.SQLStr(tostring(definitionID)))
        if result == false then
            Notify(ply, "Failed to remove secondary rank.")
            return
        end

        Notify(ply, "Secondary rank removed.")
        LogPersonnelEvent("secondary_rank_remove", ply, tostring(characterRecord.name or characterID), steamID64, "Removed secondary rank " .. tostring(definition.name))
    else
        local normalizedCharacter = Char_NormalizeCharacterRecord(characterRecord)
        local canAssign, reason = CanAssignSecondaryRank(normalizedCharacter, definition)
        if not canAssign then
            Notify(ply, reason or "Character does not meet constraints for this secondary rank.")
            return
        end

        local result = sql.Query(string.format(
            "REPLACE INTO leopardrp_character_secondary_ranks (character_id, secondary_rank_id, assigned_by_steamid64, assigned_at) VALUES (%s, %s, %s, %d)",
            sql.SQLStr(characterID),
            sql.SQLStr(tostring(definitionID)),
            sql.SQLStr(ply:SteamID64()),
            os.time()
        ))
        if result == false then
            Notify(ply, "Failed to assign secondary rank.")
            return
        end

        Notify(ply, "Secondary rank assigned.")
        LogPersonnelEvent("secondary_rank_assign", ply, tostring(characterRecord.name or characterID), steamID64, "Assigned secondary rank " .. tostring(definition.name))
    end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveSecondaryRanks, {
        mode = mode,
        steamID64 = steamID64,
        characterID = characterID,
        definitions = BuildSecondaryRankDefinitions(tostring(payload.search or "")),
        assignments = BuildCharacterSecondaryRanks(characterID),
        search = tostring(payload.search or "")
    })

    local details = BuildCharacterDetails(steamID64, characterID)
    if details then
        SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterDetails, {
            mode = mode,
            steamID64 = steamID64,
            characterID = characterID,
            details = details
        })
    end
end)

net.Receive(Personnel.NetworkStrings.SubmitAction, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    LogPersonnelEvent("panel_action_submit", ply, tostring(payload.action or ""), tostring(payload.steamID64 or ""), "Submitted panel action.")
    local ok, message = ApplyCharacterAction(ply, payload)

    if message and message ~= "" then
        Notify(ply, message)
    end

    if not ok then return end

    local mode = tostring(payload.mode or "crew")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")

    if steamID64 ~= "" then
        local listPayload = {
            mode = mode,
            steamID64 = steamID64,
            characters = BuildCharacterList(steamID64, ply, mode)
        }
        SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterList, listPayload)
    end

    if steamID64 ~= "" and characterID ~= "" then
        local details = BuildCharacterDetails(steamID64, characterID)
        if details then
            SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterDetails, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                details = details
            })
        end
    end

    SendDirectory(ply, mode, "")
end)

net.Receive(Personnel.NetworkStrings.AddDossierEntry, function(_, ply)
    if not EnsurePersonnelTables() then return end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    LogPersonnelEvent("panel_dossier_submit", ply, tostring(payload.characterID or ""), tostring(payload.steamID64 or ""), "Submitted dossier entry.")
    local ok, message = AddDossierEntry(ply, payload)

    if message and message ~= "" then
        Notify(ply, message)
    end

    if not ok then return end

    local mode = tostring(payload.mode or "crew")
    local steamID64 = tostring(payload.steamID64 or "")
    local characterID = tostring(payload.characterID or "")

    if steamID64 ~= "" and characterID ~= "" then
        local details = BuildCharacterDetails(steamID64, characterID)
        if details then
            SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterDetails, {
                mode = mode,
                steamID64 = steamID64,
                characterID = characterID,
                details = details
            })
        end
    end
end)

net.Receive(Personnel.NetworkStrings.DeleteDossierEntry, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not Personnel.CanAccessAdminPanel(ply) then
        Notify(ply, "Administrative permissions are required.")
        return
    end

    local entryID = tonumber(net.ReadString() or "0") or 0
    local steamID64 = tostring(net.ReadString() or "")
    local characterID = tostring(net.ReadString() or "")
    if entryID <= 0 or steamID64 == "" or characterID == "" then return end

    local deleteResult = sql.Query("DELETE FROM leopardrp_character_dossiers WHERE id = " .. sql.SQLStr(tostring(entryID)))
    if deleteResult == false then
        Notify(ply, "Failed to delete dossier entry.")
        return
    end

    LogPersonnelEvent("dossier_delete", ply, characterID, steamID64, "Deleted dossier entry ID " .. tostring(entryID))
    Notify(ply, "Dossier entry deleted.")

    local details = BuildCharacterDetails(steamID64, characterID)
    if details then
        SendJSON(ply, Personnel.NetworkStrings.ReceiveCharacterDetails, {
            mode = "admin",
            steamID64 = steamID64,
            characterID = characterID,
            details = details
        })
    end
end)

net.Receive(Personnel.NetworkStrings.RequestManifest, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not IsValid(ply) then return end

    SendJSON(ply, Personnel.NetworkStrings.ReceiveManifest, buildManifestData())
end)

net.Receive(Personnel.NetworkStrings.SubmitPlayerReport, function(_, ply)
    if not EnsurePersonnelTables() then return end
    if not IsValid(ply) then return end

    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    local targetSteamID64 = string.Trim(tostring(payload.targetSteamID64 or ""))
    local category = string.lower(string.Trim(tostring(payload.category or "other")))
    local description = string.Trim(tostring(payload.description or ""))

    if targetSteamID64 == "" then
        Notify(ply, "Report failed: missing target.")
        return
    end

    if not REPORT_CATEGORIES[category] then
        category = "other"
    end

    if description == "" then
        Notify(ply, "Report failed: description is required.")
        return
    end

    if #description > 800 then
        description = string.sub(description, 1, 800)
    end

    local reporterSteamName, reporterSteamID64, reporterCharacterName = GetActorIdentity(ply)

    local targetPlayer = player.GetBySteamID64(targetSteamID64)
    if not IsValid(targetPlayer) then
        for _, candidate in ipairs(player.GetAll()) do
            if IsValid(candidate) and candidate:SteamID64() == targetSteamID64 then
                targetPlayer = candidate
                break
            end
        end
    end

    local targetSteamName = IsValid(targetPlayer) and tostring(targetPlayer:Nick() or "Unknown") or "Offline/Unknown"
    local targetCharacterName = IsValid(targetPlayer) and getCharacterDisplayName(targetPlayer, getActiveCharacterForPlayer(targetPlayer)) or targetSteamName

    local adminsOnline = notifyAdminReviewers(reporterCharacterName, targetCharacterName, category, description)
    local pendingReview = adminsOnline <= 0 and 1 or 0

    local query = string.format(
        "INSERT INTO leopardrp_player_reports (timestamp, reporter_steamid64, reporter_name, reporter_character_name, target_steamid64, target_steam_name, target_character_name, category, description, admins_online, pending_review) VALUES (%d, %s, %s, %s, %s, %s, %s, %s, %s, %d, %d)",
        os.time(),
        sql.SQLStr(tostring(reporterSteamID64 or "0")),
        sql.SQLStr(tostring(reporterSteamName or "Unknown")),
        sql.SQLStr(tostring(reporterCharacterName or reporterSteamName or "Unknown")),
        sql.SQLStr(targetSteamID64),
        sql.SQLStr(targetSteamName),
        sql.SQLStr(targetCharacterName),
        sql.SQLStr(category),
        sql.SQLStr(description),
        tonumber(adminsOnline) or 0,
        pendingReview
    )

    if sql.Query(query) == false then
        Notify(ply, "Report failed to save.")
        return
    end

    LogPersonnelEvent("player_report", ply, targetCharacterName, targetSteamID64, string.format("Submitted report (%s)", category))
    if pendingReview == 1 then
        Notify(ply, "Report submitted. No admins are currently clocked in; it has been saved for review.")
    else
        Notify(ply, "Report submitted and forwarded to online administrators.")
    end
end)

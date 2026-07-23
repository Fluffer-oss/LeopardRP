LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

LeopardRP.Modules["PersonnelManagement"] = true

local Personnel = LeopardRP.Personnel

Personnel.ForcedOwnerSteamID64 = Personnel.ForcedOwnerSteamID64 or "76561199122465449"

function Personnel.IsForcedOwner(subject)
    local steamID64 = ""

    if IsValid(subject) and subject.SteamID64 then
        steamID64 = tostring(subject:SteamID64() or "")
    else
        steamID64 = tostring(subject or "")
    end

    return steamID64 ~= "" and steamID64 == tostring(Personnel.ForcedOwnerSteamID64 or "")
end

Personnel.NetworkStrings = Personnel.NetworkStrings or {
    RequestCrewManager = "LeopardRP.Personnel.RequestCrewManager",
    RequestAdminPanel = "LeopardRP.Personnel.RequestAdminPanel",
    RequestMenuAccess = "LeopardRP.Personnel.RequestMenuAccess",
    OpenCrewManager = "LeopardRP.Personnel.OpenCrewManager",
    OpenAdminPanel = "LeopardRP.Personnel.OpenAdminPanel",
    ReceiveMenuAccess = "LeopardRP.Personnel.ReceiveMenuAccess",
    RequestDirectory = "LeopardRP.Personnel.RequestDirectory",
    ReceiveDirectory = "LeopardRP.Personnel.ReceiveDirectory",
    RequestCharacterList = "LeopardRP.Personnel.RequestCharacterList",
    ReceiveCharacterList = "LeopardRP.Personnel.ReceiveCharacterList",
    RequestCharacterDetails = "LeopardRP.Personnel.RequestCharacterDetails",
    ReceiveCharacterDetails = "LeopardRP.Personnel.ReceiveCharacterDetails",
    RequestLogs = "LeopardRP.Personnel.RequestLogs",
    ReceiveLogs = "LeopardRP.Personnel.ReceiveLogs",
    RequestStaffRanks = "LeopardRP.Personnel.RequestStaffRanks",
    ReceiveStaffRanks = "LeopardRP.Personnel.ReceiveStaffRanks",
    SetStaffRank = "LeopardRP.Personnel.SetStaffRank",
    RequestSecondaryRanks = "LeopardRP.Personnel.RequestSecondaryRanks",
    ReceiveSecondaryRanks = "LeopardRP.Personnel.ReceiveSecondaryRanks",
    CreateSecondaryRank = "LeopardRP.Personnel.CreateSecondaryRank",
    SetCharacterSecondaryRank = "LeopardRP.Personnel.SetCharacterSecondaryRank",
    RequestManifest = "LeopardRP.Personnel.RequestManifest",
    ReceiveManifest = "LeopardRP.Personnel.ReceiveManifest",
    SubmitPlayerReport = "LeopardRP.Personnel.SubmitPlayerReport",
    RequestRoster = "LeopardRP.Personnel.RequestRoster",
    ReceiveRoster = "LeopardRP.Personnel.ReceiveRoster",
    RequestTrainingManagement = "LeopardRP.Personnel.RequestTrainingManagement",
    ReceiveTrainingManagement = "LeopardRP.Personnel.ReceiveTrainingManagement",
    RequestPermissionManagement = "LeopardRP.Personnel.RequestPermissionManagement",
    ReceivePermissionManagement = "LeopardRP.Personnel.ReceivePermissionManagement",
    SavePermissionManagement = "LeopardRP.Personnel.SavePermissionManagement",
    RequestDevModeSettings = "LeopardRP.Personnel.RequestDevModeSettings",
    ReceiveDevModeSettings = "LeopardRP.Personnel.ReceiveDevModeSettings",
    SaveDevModeSettings = "LeopardRP.Personnel.SaveDevModeSettings",
    RequestLogisticsSettings = "LeopardRP.Personnel.RequestLogisticsSettings",
    ReceiveLogisticsSettings = "LeopardRP.Personnel.ReceiveLogisticsSettings",
    SaveLogisticsSettings = "LeopardRP.Personnel.SaveLogisticsSettings",
    UpdateRosterRecord = "LeopardRP.Personnel.UpdateRosterRecord",
    UpdateTrainingRecord = "LeopardRP.Personnel.UpdateTrainingRecord",
    SubmitAction = "LeopardRP.Personnel.SubmitAction",
    AddDossierEntry = "LeopardRP.Personnel.AddDossierEntry",
    DeleteDossierEntry = "LeopardRP.Personnel.DeleteDossierEntry",
    Notification = "LeopardRP.Personnel.Notification"
}

Personnel.ActivityLevels = Personnel.ActivityLevels or {
    { ID = "active_duty", Name = "Active Duty", Color = Color(120, 240, 170, 255) },
    { ID = "highly_active", Name = "Highly Active", Color = Color(145, 230, 255, 255) },
    { ID = "active", Name = "Active", Color = Color(150, 205, 255, 255) },
    { ID = "semi_active", Name = "Semi-Active", Color = Color(190, 205, 255, 255) },
    { ID = "low_activity", Name = "Low Activity", Color = Color(255, 205, 120, 255) },
    { ID = "leave_of_absence", Name = "Leave of Absence", Color = Color(255, 170, 110, 255) },
    { ID = "reserve_duty", Name = "Reserve Duty", Color = Color(200, 160, 255, 255) },
    { ID = "inactive", Name = "Inactive", Color = Color(235, 135, 135, 255) }
}

Personnel.TrainingCatalog = Personnel.TrainingCatalog or {
    General = {
        { ID = "basic_starfleet_training", Name = "Basic Starfleet Training", RequiresInstructor = false, Expires = false },
        { ID = "bridge_officer_qualification", Name = "Bridge Officer Qualification", RequiresInstructor = true, Expires = false }
    },
    Command = {
        { ID = "command_certification", Name = "Command Certification", RequiresInstructor = true, Expires = true, ExpirationDays = 365 },
        { ID = "command_simulation", Name = "Command Simulation", RequiresInstructor = true, Expires = false }
    },
    Engineering = {
        { ID = "engineering_certification", Name = "Engineering Certification", RequiresInstructor = true, Expires = false },
        { ID = "warp_core_operations", Name = "Warp Core Operations", RequiresInstructor = true, Expires = false }
    },
    Operations = {
        { ID = "operations_certification", Name = "Operations Certification", RequiresInstructor = true, Expires = false },
        { ID = "transporter_operations", Name = "Transporter Operations", RequiresInstructor = true, Expires = false }
    },
    Tactical = {
        { ID = "tactical_certification", Name = "Tactical Certification", RequiresInstructor = true, Expires = false },
        { ID = "weapon_systems", Name = "Weapons Systems", RequiresInstructor = true, Expires = false }
    },
    Security = {
        { ID = "security_certification", Name = "Security Certification", RequiresInstructor = true, Expires = false },
        { ID = "brig_procedures", Name = "Brig Procedures", RequiresInstructor = false, Expires = false }
    },
    Science = {
        { ID = "science_certification", Name = "Science Certification", RequiresInstructor = true, Expires = false },
        { ID = "sensor_operations", Name = "Sensor Operations", RequiresInstructor = true, Expires = false }
    },
    Medical = {
        { ID = "medical_certification", Name = "Medical Certification", RequiresInstructor = true, Expires = false },
        { ID = "emergency_medical_procedures", Name = "Emergency Medical Procedures", RequiresInstructor = true, Expires = false }
    }
}

Personnel.ServerPermissionLevels = Personnel.ServerPermissionLevels or {
    { ID = "player", Name = "Player", Flags = {} },
    { ID = "trainer", Name = "Trainer", Flags = { training = true } },
    { ID = "moderator", Name = "Moderator", Flags = { crew = true } },
    { ID = "administrator", Name = "Administrator", Flags = { crew = true, admin = true, override = true } },
    { ID = "senior_administrator", Name = "Senior Administrator", Flags = { crew = true, admin = true, override = true } },
    { ID = "game_master", Name = "Game Master", Flags = { training = true, crew = true } },
    { ID = "community_manager", Name = "Community Manager", Flags = { training = true, crew = true, admin = true, override = true } },
    { ID = "owner", Name = "Owner", Flags = { training = true, crew = true, admin = true, override = true, owner = true } }
}

Personnel.ServerPermissionAliases = Personnel.ServerPermissionAliases or {
    none = "player",
    mod = "moderator",
    admin = "administrator",
    superadmin = "owner"
}

Personnel.PromotionPermissionProfiles = Personnel.PromotionPermissionProfiles or {
    { ID = "commander_plus", Name = "Commander+", MinRankOrder = 12, AllowPromote = false, AllowDemote = false, AllowPosition = false, AllowActivity = false },
    { ID = "captain_plus", Name = "Captain+", MinRankOrder = 13, AllowPromote = true, AllowDemote = true, AllowPosition = true, AllowActivity = true },
    { ID = "trainer_only", Name = "Trainer Only", MinRankOrder = 1, AllowPromote = false, AllowDemote = false, AllowPosition = false, AllowActivity = false },
    { ID = "administrators", Name = "Administrators", MinRankOrder = 1, AllowPromote = true, AllowDemote = true, AllowPosition = true, AllowActivity = true, RequireAdmin = true }
}

Personnel.KeybindActions = Personnel.KeybindActions or {
    { ID = "main_menu", Label = "Open Main Menu", ConfigKey = "KeybindOpenMainMenu", Default = KEY_F2 },
    { ID = "character_selection", Label = "Open Character Selection", ConfigKey = "KeybindOpenCharacterSelection", Default = KEY_NONE },
    { ID = "game_master_menu", Label = "Open Game Master Menu", ConfigKey = "KeybindOpenGameMasterMenu", Default = KEY_F4 },
    { ID = "personnel_menu", Label = "Open Personnel Menu", ConfigKey = "KeybindOpenAdminPanel", Default = KEY_F10 },
    { ID = "inventory_open", Label = "Open Inventory", ConfigKey = "KeybindOpenInventory", Default = KEY_I },
    { ID = "voice_range_cycle", Label = "Cycle Voice Range", ConfigKey = "KeybindVoiceRangeCycle", Default = KEY_COMMA },
    { ID = "crew_manager", Label = "Open Crew Manager", ConfigKey = "KeybindOpenCrewManager", Default = KEY_F9 },
    { ID = "training_management", Label = "Open Training Management", ConfigKey = "KeybindOpenTrainingManagement", Default = KEY_NONE }
}

local function GetServerPermissionDefinition(permissionID)
    local normalized = string.lower(string.Trim(tostring(permissionID or "player")))
    normalized = Personnel.ServerPermissionAliases[normalized] or normalized

    for _, entry in ipairs(Personnel.ServerPermissionLevels or {}) do
        if string.lower(tostring(entry.ID or "")) == normalized then
            return entry
        end
    end

    return Personnel.ServerPermissionLevels and Personnel.ServerPermissionLevels[1] or { ID = "player", Name = "Player", Flags = {} }
end

function Personnel.NormalizeServerPermission(permissionID)
    return tostring(GetServerPermissionDefinition(permissionID).ID or "player")
end

function Personnel.GetServerPermissionDefinition(permissionID)
    return GetServerPermissionDefinition(permissionID)
end

function Personnel.GetActiveCharacter(ply)
    if not IsValid(ply) then return nil end
    if not LeopardRP.Characters or not LeopardRP.Characters.GetPlayerProfile then return nil end

    local profile = LeopardRP.Characters.GetPlayerProfile(ply)
    if not profile or not LeopardRP.Characters.GetActiveCharacter then return nil end

    return LeopardRP.Characters.GetActiveCharacter(profile)
end

function Personnel.GetPlayerRankOrder(ply)
    local activeCharacter = Personnel.GetActiveCharacter(ply)
    if not activeCharacter then return 0 end

    return LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(activeCharacter.rankID) or 0) or 0
end

function Personnel.IsCommandStaff(ply)
    local minimumOrder = tonumber(LeopardRP.Config.CommandStaffMinimumRankOrder) or 6
    return Personnel.GetPlayerRankOrder(ply) >= minimumOrder
end

function Personnel.CanAccessCrewManager(ply)
    if not IsValid(ply) then return false end
    if Personnel.IsForcedOwner(ply) then return true end
    if not LeopardRP.Config.EnableCrewManager then return false end

    local managedRank = Personnel.NormalizeServerPermission((ply.GetNWString and ply:GetNWString("LeopardRP.StaffRank", "")) or "")
    local definition = Personnel.GetServerPermissionDefinition(managedRank)
    if definition and definition.Flags and definition.Flags.crew then
        return true
    end

    return Personnel.IsCommandStaff(ply)
end

function Personnel.CanAccessAdminPanel(ply)
    if not IsValid(ply) then return false end
    if Personnel.IsForcedOwner(ply) then return true end
    if LeopardRP.Config.EnableAdministrationPanel == false then return false end

    if ULib and ULib.ucl then
        if ply.GetUserGroup then
            local userGroup = string.lower(tostring(ply:GetUserGroup() or ""))
            if userGroup == "superadmin" or userGroup == "admin" or string.find(userGroup, "owner", 1, true) or string.find(userGroup, "staff", 1, true) then
                return true
            end
        end

        if isfunction(ULib.ucl.query) then
            if ULib.ucl.query(ply, "ulx adduser") or ULib.ucl.query(ply, "ulx ban") or ULib.ucl.query(ply, "ulx gag") then
                return true
            end
        end
    end

    return ply:IsSuperAdmin() or ply:IsAdmin()
end

function Personnel.CanAccessTrainingManagement(ply)
    if not IsValid(ply) then return false end
    if Personnel.IsForcedOwner(ply) then return true end

    local managedRank = Personnel.NormalizeServerPermission((ply.GetNWString and ply:GetNWString("LeopardRP.StaffRank", "")) or "")
    local definition = Personnel.GetServerPermissionDefinition(managedRank)
    if definition and definition.Flags and definition.Flags.training then
        return true
    end

    return Personnel.CanAccessAdminPanel(ply)
end

function Personnel.GetCharacterStatus(characterRecord)
    if not istable(characterRecord) then return "Unknown" end
    if characterRecord.isEvent then return "Event" end

    local customData = istable(characterRecord.customData) and characterRecord.customData or {}
    if customData.deleted then return "Deleted" end

    return "Active"
end

function Personnel.CanCrewManageTarget(ply, targetCharacter)
    if not Personnel.CanAccessCrewManager(ply) then return false end
    if Personnel.CanAccessAdminPanel(ply) then return true end
    if not istable(targetCharacter) then return false end

    local managerOrder = Personnel.GetPlayerRankOrder(ply)
    local targetOrder = LeopardRP.GetRankOrder and (LeopardRP.GetRankOrder(targetCharacter.rankID) or 0) or 0

    return targetOrder <= managerOrder
end

if SERVER then
    for _, networkString in pairs(Personnel.NetworkStrings) do
        util.AddNetworkString(networkString)
    end
end

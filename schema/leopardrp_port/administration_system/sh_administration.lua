LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.Administration = LeopardRP.Administration or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

LeopardRP.Modules["AdministrationSystem"] = true

local Admin = LeopardRP.Administration
local Personnel = LeopardRP.Personnel

Admin.NetworkStrings = Admin.NetworkStrings or {
    RequestOpenMenu = "LeopardRP.Admin.RequestOpenMenu",
    OpenMenu = "LeopardRP.Admin.OpenMenu",
    RequestInitialData = "LeopardRP.Admin.RequestInitialData",
    ReceiveInitialData = "LeopardRP.Admin.ReceiveInitialData",
    ClockToggle = "LeopardRP.Admin.ClockToggle",
    ClockStatus = "LeopardRP.Admin.ClockStatus",
    SubmitAction = "LeopardRP.Admin.SubmitAction",
    ActionResult = "LeopardRP.Admin.ActionResult",
    WarnOverlay = "LeopardRP.Admin.WarnOverlay"
}

Admin.Ranks = Admin.Ranks or {
    { ID = "none", Name = "No Admin Permissions", Weight = 0 },
    { ID = "moderator", Name = "Moderator", Weight = 1 },
    { ID = "senior_moderator", Name = "Senior Moderator", Weight = 2 },
    { ID = "administrator", Name = "Administrator", Weight = 3 },
    { ID = "senior_administrator", Name = "Senior Administrator", Weight = 4 },
    { ID = "head_administrator", Name = "Head Administrator", Weight = 5 }
}

Admin.Punishments = Admin.Punishments or {
    "warn",
    "kick",
    "temp_ban",
    "perm_ban",
    "mute",
    "gag",
    "jail",
    "freeze",
    "spectate",
    "teleport",
    "bring",
    "return"
}

local rankByID = {}
for _, entry in ipairs(Admin.Ranks) do
    rankByID[entry.ID] = entry
end

function Admin.GetRankDefinition(rankID)
    return rankByID[tostring(rankID or "none")] or rankByID.none
end

function Admin.NormalizeRank(rankID)
    return Admin.GetRankDefinition(rankID).ID
end

function Admin.GetRankWeight(rankID)
    local def = Admin.GetRankDefinition(rankID)
    return tonumber(def.Weight) or 0
end

function Admin.HasRankAtLeast(rankID, requiredRank)
    return Admin.GetRankWeight(rankID) >= Admin.GetRankWeight(requiredRank)
end

if Personnel.KeybindActions and istable(Personnel.KeybindActions) then
    local hasAction = false
    for _, action in ipairs(Personnel.KeybindActions) do
        if tostring(action.ID) == "administration_menu" then
            hasAction = true
            break
        end
    end

    if not hasAction then
        table.insert(Personnel.KeybindActions, {
            ID = "administration_menu",
            Label = "Open Administration Menu",
            ConfigKey = "KeybindOpenAdministrationMenu",
            Default = KEY_F6
        })
    end
end

if SERVER then
    for _, networkString in pairs(Admin.NetworkStrings) do
        util.AddNetworkString(networkString)
    end
end

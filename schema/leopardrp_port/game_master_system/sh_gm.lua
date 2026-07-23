LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.GameMaster = LeopardRP.GameMaster or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

LeopardRP.Modules["GameMasterSystem"] = true

local GM = LeopardRP.GameMaster
local Personnel = LeopardRP.Personnel

GM.NetworkStrings = GM.NetworkStrings or {
    RequestOpenMenu = "LeopardRP.GM.RequestOpenMenu",
    OpenMenu = "LeopardRP.GM.OpenMenu",
    RequestInitialData = "LeopardRP.GM.RequestInitialData",
    ReceiveInitialData = "LeopardRP.GM.ReceiveInitialData",
    ClockToggle = "LeopardRP.GM.ClockToggle",
    ClockStatus = "LeopardRP.GM.ClockStatus",
    SubmitAction = "LeopardRP.GM.SubmitAction",
    ActionResult = "LeopardRP.GM.ActionResult"
}

GM.Ranks = GM.Ranks or {
    { ID = "none", Name = "No GM Permissions", Weight = 0 },
    { ID = "game_master", Name = "Game Master", Weight = 1 },
    { ID = "senior_game_master", Name = "Senior Game Master", Weight = 2 },
    { ID = "chief_game_master", Name = "Chief Game Master", Weight = 3 }
}

GM.EventUtilities = GM.EventUtilities or {
    "spawn_prop",
    "spawn_npc",
    "spawn_vehicle",
    "spawn_effect",
    "spawn_sent",
    "teleport_to",
    "bring_player",
    "return_player",
    "freeze_player",
    "unfreeze_player",
    "cleanup_event_props",
    "cleanup_event_npcs",
    "cleanup_entire_event",
    "save_event_setup",
    "load_event_setup"
}

local rankByID = {}
for _, entry in ipairs(GM.Ranks) do
    rankByID[entry.ID] = entry
end

function GM.GetRankDefinition(rankID)
    return rankByID[tostring(rankID or "none")] or rankByID.none
end

function GM.NormalizeRank(rankID)
    return GM.GetRankDefinition(rankID).ID
end

function GM.GetRankWeight(rankID)
    local def = GM.GetRankDefinition(rankID)
    return tonumber(def.Weight) or 0
end

function GM.HasRankAtLeast(rankID, requiredRank)
    return GM.GetRankWeight(rankID) >= GM.GetRankWeight(requiredRank)
end

if Personnel.KeybindActions and istable(Personnel.KeybindActions) then
    local hasAction = false
    for _, action in ipairs(Personnel.KeybindActions) do
        if tostring(action.ID) == "game_master_menu" then
            hasAction = true
            break
        end
    end

    if not hasAction then
        table.insert(Personnel.KeybindActions, {
            ID = "game_master_menu",
            Label = "Open Game Master Menu",
            ConfigKey = "KeybindOpenGameMasterMenu",
            Default = KEY_F4
        })
    end
end

if SERVER then
    for _, networkString in pairs(GM.NetworkStrings) do
        util.AddNetworkString(networkString)
    end
end

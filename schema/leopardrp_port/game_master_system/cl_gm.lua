LeopardRP = LeopardRP or {}
LeopardRP.GameMaster = LeopardRP.GameMaster or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local GM = LeopardRP.GameMaster

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

GM.State = GM.State or {
    clock = {},
    onlinePlayers = {},
    eventCharacters = {},
    logs = {},
    gmRanks = {}
}

local function ReadPayload()
    return util.JSONToTable(net.ReadString() or "{}") or {}
end

local function Notify(payload)
    if not istable(payload) then return end
    local text = tostring(payload.message or "")
    if text == "" then return end

    notification.AddLegacy(text, payload.ok and NOTIFY_HINT or NOTIFY_ERROR, 3)
end


function GM.CloseActivePanel()
    if IsValid(GM.ActivePanel) then
        GM.ActivePanel:Remove()
    end

    GM.ActivePanel = nil

    local hasCharacterMenu = LeopardRP.CharacterCreation and IsValid(LeopardRP.CharacterCreation.ActiveMenuFrame)
    local hasPersonnelMenu = LeopardRP.Personnel and IsValid(LeopardRP.Personnel.ActivePanel)
    local hasAdminMenu = LeopardRP.Administration and IsValid(LeopardRP.Administration.ActivePanel)

    if not hasCharacterMenu and not hasPersonnelMenu and not hasAdminMenu then
        SetMenuInteractionEnabled(false)
    end
end

function GM.OpenPanel()
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.CloseActiveMenu then
        LeopardRP.CharacterCreation.CloseActiveMenu()
    end

    if LeopardRP.Personnel and LeopardRP.Personnel.CloseActivePanel then
        LeopardRP.Personnel.CloseActivePanel()
    end

    GM.CloseActivePanel()

    local panel = vgui.Create("LeopardRPGameMasterMenu")
    GM.ActivePanel = panel

    return panel
end

function GM.RequestOpenMenu()
    net.Start(GM.NetworkStrings.RequestOpenMenu)
    net.SendToServer()
end

function GM.RequestInitialData()
    net.Start(GM.NetworkStrings.RequestInitialData)
    net.SendToServer()
end

function GM.ToggleClock(clockIn)
    net.Start(GM.NetworkStrings.ClockToggle)
    net.WriteBool(clockIn and true or false)
    net.SendToServer()
end

function GM.SubmitAction(payload)
    net.Start(GM.NetworkStrings.SubmitAction)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

net.Receive(GM.NetworkStrings.OpenMenu, function()
    GM.OpenPanel()
    GM.RequestInitialData()
end)

net.Receive(GM.NetworkStrings.ReceiveInitialData, function()
    local payload = ReadPayload()
    GM.State.clock = payload.clock or {}
    GM.State.onlinePlayers = payload.onlinePlayers or {}
    GM.State.eventCharacters = payload.eventCharacters or {}
    GM.State.logs = payload.logs or {}
    GM.State.gmRanks = payload.gmRanks or {}

    if IsValid(GM.ActivePanel) and GM.ActivePanel.OnDataUpdated then
        GM.ActivePanel:OnDataUpdated(GM.State)
    end
end)

net.Receive(GM.NetworkStrings.ClockStatus, function()
    GM.State.clock = ReadPayload() or {}
    if IsValid(GM.ActivePanel) and GM.ActivePanel.OnDataUpdated then
        GM.ActivePanel:OnDataUpdated(GM.State)
    end
end)

net.Receive(GM.NetworkStrings.ActionResult, function()
    Notify(ReadPayload())
end)


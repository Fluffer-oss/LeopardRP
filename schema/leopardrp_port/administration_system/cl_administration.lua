LeopardRP = LeopardRP or {}
LeopardRP.Administration = LeopardRP.Administration or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Admin = LeopardRP.Administration

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

Admin.State = Admin.State or {
    clock = {},
    onlinePlayers = {},
    adminRanks = {},
    logs = {},
    punishments = {},
    rulebook = {},
    guidelines = {}
}

local warnOverlayState = {
    active = false,
    reason = "",
    staffName = "Administration",
    heldFor = 0,
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

function Admin.CloseActivePanel()
    if IsValid(Admin.ActivePanel) then
        Admin.ActivePanel:Remove()
    end

    Admin.ActivePanel = nil

    local hasCharacterMenu = LeopardRP.CharacterCreation and IsValid(LeopardRP.CharacterCreation.ActiveMenuFrame)
    local hasPersonnelMenu = LeopardRP.Personnel and IsValid(LeopardRP.Personnel.ActivePanel)
    local hasGMMenu = LeopardRP.GameMaster and IsValid(LeopardRP.GameMaster.ActivePanel)

    if not hasCharacterMenu and not hasPersonnelMenu and not hasGMMenu then
        SetMenuInteractionEnabled(false)
    end
end

function Admin.OpenPanel()
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.CloseActiveMenu then
        LeopardRP.CharacterCreation.CloseActiveMenu()
    end

    if LeopardRP.Personnel and LeopardRP.Personnel.CloseActivePanel then
        LeopardRP.Personnel.CloseActivePanel()
    end

    Admin.CloseActivePanel()

    local panel = vgui.Create("LeopardRPAdministrationMenu")
    Admin.ActivePanel = panel

    return panel
end

function Admin.RequestOpenMenu()
    net.Start(Admin.NetworkStrings.RequestOpenMenu)
    net.SendToServer()
end

function Admin.RequestInitialData()
    net.Start(Admin.NetworkStrings.RequestInitialData)
    net.SendToServer()
end

function Admin.ToggleClock(clockIn)
    net.Start(Admin.NetworkStrings.ClockToggle)
    net.WriteBool(clockIn and true or false)
    net.SendToServer()
end

function Admin.SubmitAction(payload)
    net.Start(Admin.NetworkStrings.SubmitAction)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

net.Receive(Admin.NetworkStrings.OpenMenu, function()
    Admin.OpenPanel()
    Admin.RequestInitialData()
end)

net.Receive(Admin.NetworkStrings.ReceiveInitialData, function()
    local payload = ReadPayload()
    Admin.State.clock = payload.clock or {}
    Admin.State.onlinePlayers = payload.onlinePlayers or {}
    Admin.State.adminRanks = payload.adminRanks or {}
    Admin.State.logs = payload.logs or {}
    Admin.State.punishments = payload.punishments or {}
    Admin.State.rulebook = payload.rulebook or {}
    Admin.State.guidelines = payload.guidelines or {}

    if IsValid(Admin.ActivePanel) and Admin.ActivePanel.OnDataUpdated then
        Admin.ActivePanel:OnDataUpdated(Admin.State)
    end
end)

net.Receive(Admin.NetworkStrings.ClockStatus, function()
    Admin.State.clock = ReadPayload() or {}
    if IsValid(Admin.ActivePanel) and Admin.ActivePanel.OnDataUpdated then
        Admin.ActivePanel:OnDataUpdated(Admin.State)
    end
end)

net.Receive(Admin.NetworkStrings.ActionResult, function()
    Notify(ReadPayload())
end)

net.Receive(Admin.NetworkStrings.WarnOverlay, function()
    warnOverlayState.active = true
    warnOverlayState.reason = string.Trim(tostring(net.ReadString() or ""))
    warnOverlayState.staffName = string.Trim(tostring(net.ReadString() or "Administration"))
    warnOverlayState.heldFor = 0
end)

hook.Add("Think", "LeopardRP.Admin.WarnOverlayHold", function()
    if not warnOverlayState.active then return end

    if input.IsKeyDown(KEY_SPACE) then
        warnOverlayState.heldFor = warnOverlayState.heldFor + FrameTime()
    else
        warnOverlayState.heldFor = math.max(0, warnOverlayState.heldFor - (FrameTime() * 1.2))
    end

    if warnOverlayState.heldFor >= 5 then
        warnOverlayState.active = false
        warnOverlayState.heldFor = 0
    end
end)

hook.Add("HUDPaint", "LeopardRP.Admin.WarnOverlayDraw", function()
    if not warnOverlayState.active then return end

    local w, h = ScrW(), ScrH()
    local progress = math.Clamp((warnOverlayState.heldFor or 0) / 5, 0, 1)

    surface.SetDrawColor(120, 10, 10, 205)
    surface.DrawRect(0, 0, w, h)

    draw.SimpleText("ADMINISTRATIVE WARNING", "Trebuchet24", w * 0.5, h * 0.30, Color(255, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("Issued by: " .. tostring(warnOverlayState.staffName or "Administration"), "Trebuchet18", w * 0.5, h * 0.36, Color(255, 210, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.DrawText(string.Trim(tostring(warnOverlayState.reason or "Rule violation.")) ~= "" and tostring(warnOverlayState.reason) or "Rule violation.", "Trebuchet24", w * 0.25, h * 0.42, Color(255, 255, 255), TEXT_ALIGN_LEFT)

    local barW, barH = math.min(460, w * 0.7), 20
    local barX, barY = (w - barW) * 0.5, h * 0.70
    draw.RoundedBox(6, barX, barY, barW, barH, Color(35, 0, 0, 220))
    draw.RoundedBox(6, barX, barY, barW * progress, barH, Color(255, 90, 90, 230))

    draw.SimpleText("Hold SPACE for 5 seconds to dismiss", "Trebuchet18", w * 0.5, barY + 34, Color(255, 225, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(string.format("%.1f / 5.0", warnOverlayState.heldFor or 0), "Trebuchet18", w * 0.5, barY + 56, Color(255, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

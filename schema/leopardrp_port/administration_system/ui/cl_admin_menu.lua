LeopardRP = LeopardRP or {}
LeopardRP.Administration = LeopardRP.Administration or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Admin = LeopardRP.Administration
local LCARS_ORANGE = Color(255, 164, 72, 235)

local PANEL = {}

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

local function CreateStyledButton(parent, text, accent)
    local button = vgui.Create("LeopardRPMenuButton", parent)
    button:SetText("")
    button:SetButtonText(text)
    if accent and button.SetAccentColor then
        button:SetAccentColor(accent)
    end
    return button
end

local function CreateStyledEntry(parent, placeholder)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetTall(34)
    entry:SetPlaceholderText(placeholder or "")
    if entry.SetPlaceholderColor then
        entry:SetPlaceholderColor(LCARS_ORANGE)
    end
    if LeopardRP.CharacterCreation.StyleTextEntry then
        LeopardRP.CharacterCreation.StyleTextEntry(entry)
    end
    return entry
end

local function CreateStyledCombo(parent)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetTall(34)
    if LeopardRP.CharacterCreation.StyleComboBox then
        LeopardRP.CharacterCreation.StyleComboBox(combo)
    end
    return combo
end

local function CreateCard(parent)
    local card = vgui.Create("DPanel", parent)
    card.Paint = function(_, w, h)
        draw.RoundedBox(16, 0, 0, w, h, Color(14, 20, 30, 195))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    return card
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
    SetMenuInteractionEnabled(true)

    self.Fade = 0
    self.Slide = 0

    self.Root = LeopardRP.CharacterCreation.CreateFullscreenRoot("ui/MainMenuScreen.png", self)
    self.Root:Dock(FILL)

    self.Header = CreateCard(self.Root)
    self.Header:SetSize(ScrW() * 0.94, ScrH() * 0.095)
    self.Header:SetPos(ScrW() * 0.03, ScrH() * 0.03)

    self.Title = vgui.Create("DLabel", self.Header)
    self.Title:SetFont("LeopardRP.Menu.PanelBold")
    self.Title:SetTextColor(Color(255, 255, 255))
    self.Title:SetText("Administration Moderation Console")
    self.Title:SizeToContents()
    self.Title:SetPos(24, 16)

    self.Subtitle = vgui.Create("DLabel", self.Header)
    self.Subtitle:SetFont("LeopardRP.Menu.Small")
    self.Subtitle:SetTextColor(Color(210, 225, 240, 240))
    self.Subtitle:SetText("Independent moderation permissions, punishments, policy pages, and accountability logs.")
    self.Subtitle:SizeToContents()
    self.Subtitle:SetPos(24, 46)

    self.CloseButton = CreateStyledButton(self.Header, "Close")
    self.CloseButton:SetSize(120, 38)
    self.CloseButton:SetPos(self.Header:GetWide() - 136, 16)
    self.CloseButton.DoClick = function()
        Admin.CloseActivePanel()
    end

    self.TopRightClose = vgui.Create("DButton", self.Header)
    self.TopRightClose:SetSize(32, 32)
    self.TopRightClose:SetPos(self.Header:GetWide() - 40, 8)
    self.TopRightClose:SetText("")
    self.TopRightClose.Paint = function(this, w, h)
        draw.RoundedBox(6, 0, 0, w, h, this:IsHovered() and Color(205, 72, 72, 230) or Color(148, 46, 46, 220))
        draw.SimpleText("X", "LeopardRP.Menu.PanelBold", w * 0.5, h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.TopRightClose.DoClick = function()
        Admin.CloseActivePanel()
    end

    self.Nav = CreateCard(self.Root)
    self.Nav:SetSize(ScrW() * 0.2, ScrH() * 0.78)
    self.Nav:SetPos(ScrW() * 0.03, ScrH() * 0.145)

    self.Content = CreateCard(self.Root)
    self.Content:SetSize(ScrW() * 0.73, ScrH() * 0.78)
    self.Content:SetPos(ScrW() * 0.24, ScrH() * 0.145)

    self.Pages = {}
    self.PageButtons = {}

    local pageList = {
        { id = "dashboard", label = "Duty Dashboard" },
        { id = "punishment_center", label = "Punishment Center" },
        { id = "history", label = "Punishment History" },
        { id = "rulebook", label = "Rulebook" },
        { id = "guidelines", label = "Guidelines" },
        { id = "logs", label = "Admin Logs" }
    }

    local top = 14
    for _, page in ipairs(pageList) do
        local button = CreateStyledButton(self.Nav, page.label)
        button:SetSize(self.Nav:GetWide() - 24, 42)
        button:SetPos(12, top)
        button.DoClick = function()
            self:SetPage(page.id)
        end
        top = top + 52
        self.PageButtons[page.id] = button
    end

    self:BuildDashboardPage()
    self:BuildPunishmentPage()
    self:BuildHistoryPage()
    self:BuildRulebookPage()
    self:BuildGuidelinesPage()
    self:BuildLogsPage()

    self:SetPage("dashboard")
    self:OnDataUpdated(Admin.State or {})
end

function PANEL:Think()
    self.Fade = Lerp(FrameTime() * 7, self.Fade, 1)
    self.Slide = Lerp(FrameTime() * 8, self.Slide, 1)

    self:SetAlpha(math.Clamp(math.floor(self.Fade * 255), 0, 255))

    local navTargetX = ScrW() * 0.03
    local contentTargetX = ScrW() * 0.24
    local offset = (1 - self.Slide) * 36

    self.Nav:SetPos(navTargetX - offset, self.Nav:GetY())
    self.Content:SetPos(contentTargetX + offset, self.Content:GetY())
end

function PANEL:OnRemove()
    if Admin.ActivePanel == self then
        Admin.ActivePanel = nil
    end

    local hasCharacterMenu = LeopardRP.CharacterCreation and IsValid(LeopardRP.CharacterCreation.ActiveMenuFrame)
    local hasPersonnelMenu = LeopardRP.Personnel and IsValid(LeopardRP.Personnel.ActivePanel)
    local hasGMMenu = LeopardRP.GameMaster and IsValid(LeopardRP.GameMaster.ActivePanel)
    if not hasCharacterMenu and not hasPersonnelMenu and not hasGMMenu then
        SetMenuInteractionEnabled(false)
    end
end

function PANEL:CreatePage(id)
    local page = vgui.Create("EditablePanel", self.Content)
    page:SetSize(self.Content:GetWide() - 24, self.Content:GetTall() - 24)
    page:SetPos(12, 12)
    page:SetVisible(false)
    page.Paint = function() end
    self.Pages[id] = page
    return page
end

function PANEL:SetPage(id)
    for pageID, page in pairs(self.Pages) do
        page:SetVisible(pageID == id)
    end

    for pageID, button in pairs(self.PageButtons) do
        if button.SetAccentColor then
            button:SetAccentColor(pageID == id and Color(255, 198, 150, 255) or nil)
        end
    end

    self.ActivePage = id
end

function PANEL:BuildDashboardPage()
    local page = self:CreatePage("dashboard")

    self.ClockCard = CreateCard(page)
    self.ClockCard:SetSize(page:GetWide() * 0.5 - 8, 166)
    self.ClockCard:SetPos(0, 0)

    self.ClockTitle = vgui.Create("DLabel", self.ClockCard)
    self.ClockTitle:SetFont("LeopardRP.Menu.PanelBold")
    self.ClockTitle:SetTextColor(Color(255, 255, 255))
    self.ClockTitle:SetText("Administration Duty Clock")
    self.ClockTitle:SizeToContents()
    self.ClockTitle:SetPos(14, 12)

    self.ClockStatus = vgui.Create("DLabel", self.ClockCard)
    self.ClockStatus:SetFont("LeopardRP.Menu.Small")
    self.ClockStatus:SetTextColor(Color(220, 240, 255, 240))
    self.ClockStatus:SetText("Status: Offline")
    self.ClockStatus:SizeToContents()
    self.ClockStatus:SetPos(14, 46)

    self.ClockButton = CreateStyledButton(self.ClockCard, "Clock In", Color(255, 200, 150, 255))
    self.ClockButton:SetSize(220, 34)
    self.ClockButton:SetPos(14, 118)
    self.ClockButton.DoClick = function()
        local isClockedIn = tobool((Admin.State.clock or {}).clockedIn)
        Admin.ToggleClock(not isClockedIn)
    end

    self.ItemManagerButton = CreateStyledButton(self.ClockCard, "Open Item Management", Color(150, 210, 255, 255))
    self.ItemManagerButton:SetSize(self.ClockCard:GetWide() - 28, 30)
    self.ItemManagerButton:SetPos(14, 84)
    self.ItemManagerButton.DoClick = function()
        if LeopardRP.Personnel and LeopardRP.Personnel.OpenHelixInventory then
            LeopardRP.Personnel.OpenHelixInventory()
            return
        end

        if not IsValid(ix.gui.menu) then
            vgui.Create("ixMenu")
        end
    end

    self.RankCard = CreateCard(page)
    self.RankCard:SetSize(page:GetWide() * 0.5 - 8, 166)
    self.RankCard:SetPos(page:GetWide() * 0.5 + 8, 0)

    self.RankTitle = vgui.Create("DLabel", self.RankCard)
    self.RankTitle:SetFont("LeopardRP.Menu.PanelBold")
    self.RankTitle:SetTextColor(Color(255, 255, 255))
    self.RankTitle:SetText("Administration Permissions")
    self.RankTitle:SizeToContents()
    self.RankTitle:SetPos(14, 12)

    self.RankDetail = vgui.Create("DLabel", self.RankCard)
    self.RankDetail:SetFont("LeopardRP.Menu.Small")
    self.RankDetail:SetTextColor(Color(220, 240, 255, 240))
    self.RankDetail:SetText("Admin Rank: Unknown")
    self.RankDetail:SizeToContents()
    self.RankDetail:SetPos(14, 46)

    self.RankTargetCombo = CreateStyledCombo(self.RankCard)
    self.RankTargetCombo:SetPos(14, 84)
    self.RankTargetCombo:SetSize(self.RankCard:GetWide() * 0.54, 30)

    self.RankValueCombo = CreateStyledCombo(self.RankCard)
    self.RankValueCombo:SetPos(self.RankCard:GetWide() * 0.56, 84)
    self.RankValueCombo:SetSize(self.RankCard:GetWide() * 0.4, 30)

    self.RankApplyButton = CreateStyledButton(self.RankCard, "Apply Rank", Color(255, 198, 150, 255))
    self.RankApplyButton:SetSize(self.RankCard:GetWide() - 28, 30)
    self.RankApplyButton:SetPos(14, 122)
    self.RankApplyButton:SetEnabled(false)
    self.RankApplyButton.DoClick = function()
        local targetSteamID64 = self.RankTargetCombo:GetOptionData(self.RankTargetCombo:GetSelectedID() or 0)
        local rankID = self.RankValueCombo:GetOptionData(self.RankValueCombo:GetSelectedID() or 0)
        if not targetSteamID64 or targetSteamID64 == "" then return end

        Admin.SubmitAction({
            type = "set_rank",
            targetSteamID64 = targetSteamID64,
            rankID = tostring(rankID or "none")
        })
    end

    self.OverviewCard = CreateCard(page)
    self.OverviewCard:SetSize(page:GetWide(), page:GetTall() - 184)
    self.OverviewCard:SetPos(0, 184)

    self.OverviewList = vgui.Create("DScrollPanel", self.OverviewCard)
    self.OverviewList:SetPos(10, 10)
    self.OverviewList:SetSize(self.OverviewCard:GetWide() - 20, self.OverviewCard:GetTall() - 20)
end

function PANEL:BuildPunishmentPage()
    local page = self:CreatePage("punishment_center")

    local card = CreateCard(page)
    card:SetSize(page:GetWide(), page:GetTall())
    card:SetPos(0, 0)

    local function addFieldLabel(text, x, y)
        local label = vgui.Create("DLabel", card)
        label:SetFont("LeopardRP.Menu.Small")
        label:SetTextColor(Color(225, 238, 248, 240))
        label:SetText(tostring(text or ""))
        label:SizeToContents()
        label:SetPos(x, y)
        return label
    end

    addFieldLabel("Target Player", 12, 10)

    self.PunishTarget = CreateStyledCombo(card)
    self.PunishTarget:SetPos(12, 32)
    self.PunishTarget:SetSize(card:GetWide() - 24, 30)

    local leftWidth = math.floor(card:GetWide() * 0.5) - 18
    local rightWidth = card:GetWide() - leftWidth - 30

    local moderationCard = CreateCard(card)
    moderationCard:SetPos(12, 72)
    moderationCard:SetSize(leftWidth, card:GetTall() - 84)

    local banCard = CreateCard(card)
    banCard:SetPos(18 + leftWidth, 72)
    banCard:SetSize(rightWidth, math.floor((card:GetTall() - 96) * 0.54))

    local movementCard = CreateCard(card)
    movementCard:SetPos(18 + leftWidth, 84 + banCard:GetTall())
    movementCard:SetSize(rightWidth, card:GetTall() - banCard:GetTall() - 96)

    local moderationTitle = vgui.Create("DLabel", moderationCard)
    moderationTitle:SetFont("LeopardRP.Menu.PanelBold")
    moderationTitle:SetTextColor(Color(235, 245, 255))
    moderationTitle:SetText("Warnings & Moderation")
    moderationTitle:SizeToContents()
    moderationTitle:SetPos(10, 8)

    self.PunishType = CreateStyledCombo(moderationCard)
    self.PunishType:SetPos(10, 34)
    self.PunishType:SetSize(moderationCard:GetWide() - 20, 30)

    local moderationReasonLabel = vgui.Create("DLabel", moderationCard)
    moderationReasonLabel:SetFont("LeopardRP.Menu.Small")
    moderationReasonLabel:SetTextColor(Color(225, 238, 248, 240))
    moderationReasonLabel:SetText("Reason")
    moderationReasonLabel:SizeToContents()
    moderationReasonLabel:SetPos(10, 66)
    self.PunishReason = CreateStyledEntry(moderationCard, "Reason (required)")
    self.PunishReason:SetPos(10, 82)
    self.PunishReason:SetSize(moderationCard:GetWide() - 20, 30)

    local moderationDurationLabel = vgui.Create("DLabel", moderationCard)
    moderationDurationLabel:SetFont("LeopardRP.Menu.Small")
    moderationDurationLabel:SetTextColor(Color(225, 238, 248, 240))
    moderationDurationLabel:SetText("Duration: Years / Days / Seconds")
    moderationDurationLabel:SizeToContents()
    moderationDurationLabel:SetPos(10, 102)
    self.PunishYears = CreateStyledEntry(moderationCard, "Years")
    self.PunishYears:SetPos(10, 118)
    self.PunishYears:SetSize(math.floor((moderationCard:GetWide() - 28) / 3), 30)

    self.PunishDays = CreateStyledEntry(moderationCard, "Days")
    self.PunishDays:SetPos(14 + math.floor((moderationCard:GetWide() - 28) / 3), 118)
    self.PunishDays:SetSize(math.floor((moderationCard:GetWide() - 28) / 3), 30)

    self.PunishSeconds = CreateStyledEntry(moderationCard, "Seconds")
    self.PunishSeconds:SetPos(18 + math.floor((moderationCard:GetWide() - 28) * 2 / 3), 118)
    self.PunishSeconds:SetSize(math.floor((moderationCard:GetWide() - 28) / 3), 30)

    self.PunishNotes = CreateStyledEntry(moderationCard, "Staff notes (optional)")
    self.PunishNotes:SetPos(10, 154)
    self.PunishNotes:SetSize(moderationCard:GetWide() - 20, 30)

    self.PunishExecute = CreateStyledButton(moderationCard, "Execute Moderation Action", Color(255, 198, 150, 255))
    self.PunishExecute:SetPos(10, 192)
    self.PunishExecute:SetSize(moderationCard:GetWide() - 20, 34)

    self.PunishExecute.DoClick = function()
        local targetSteamID64 = self.PunishTarget:GetOptionData(self.PunishTarget:GetSelectedID() or 0)
        local selectedType = self.PunishType:GetOptionData(self.PunishType:GetSelectedID() or 0)

        Admin.SubmitAction({
            type = "punishment",
            targetSteamID64 = targetSteamID64 or "",
            targetName = self.PunishTarget:GetValue() or "",
            punishmentType = tostring(selectedType or ""),
            durationYears = tonumber(self.PunishYears:GetValue()) or 0,
            durationDays = tonumber(self.PunishDays:GetValue()) or 0,
            durationSeconds = tonumber(self.PunishSeconds:GetValue()) or 0,
            reason = self.PunishReason:GetValue(),
            notes = self.PunishNotes:GetValue()
        })
    end

    local banTitle = vgui.Create("DLabel", banCard)
    banTitle:SetFont("LeopardRP.Menu.PanelBold")
    banTitle:SetTextColor(Color(235, 245, 255))
    banTitle:SetText("Kick / Ban / Unban")
    banTitle:SizeToContents()
    banTitle:SetPos(10, 8)

    self.BanReason = CreateStyledEntry(banCard, "Reason")
    self.BanReason:SetPos(10, 34)
    self.BanReason:SetSize(banCard:GetWide() - 20, 30)

    self.BanManualSteamID = CreateStyledEntry(banCard, "SteamID64 (for offline/unban targets)")
    self.BanManualSteamID:SetPos(10, 68)
    self.BanManualSteamID:SetSize(banCard:GetWide() - 20, 30)

    self.BanYears = CreateStyledEntry(banCard, "Years")
    self.BanYears:SetPos(10, 102)
    self.BanYears:SetSize(math.floor((banCard:GetWide() - 28) / 3), 30)

    self.BanDays = CreateStyledEntry(banCard, "Days")
    self.BanDays:SetPos(14 + math.floor((banCard:GetWide() - 28) / 3), 102)
    self.BanDays:SetSize(math.floor((banCard:GetWide() - 28) / 3), 30)

    self.BanSeconds = CreateStyledEntry(banCard, "Seconds")
    self.BanSeconds:SetPos(18 + math.floor((banCard:GetWide() - 28) * 2 / 3), 102)
    self.BanSeconds:SetSize(math.floor((banCard:GetWide() - 28) / 3), 30)

    local function submitBanAction(action)
        local selectedSteamID64 = tostring(self.PunishTarget:GetOptionData(self.PunishTarget:GetSelectedID() or 0) or "")
        local manualSteamID64 = string.Trim(tostring(self.BanManualSteamID:GetValue() or ""))
        Admin.SubmitAction({
            type = "punishment",
            punishmentType = action,
            targetSteamID64 = manualSteamID64 ~= "" and manualSteamID64 or selectedSteamID64,
            targetName = self.PunishTarget:GetValue() or "",
            durationYears = tonumber(self.BanYears:GetValue()) or 0,
            durationDays = tonumber(self.BanDays:GetValue()) or 0,
            durationSeconds = tonumber(self.BanSeconds:GetValue()) or 0,
            reason = self.BanReason:GetValue(),
            notes = "",
            manualTargetSteamID64 = manualSteamID64,
        })
    end

    self.KickButton = CreateStyledButton(banCard, "Kick", Color(255, 205, 145, 255))
    self.KickButton:SetPos(10, 140)
    self.KickButton:SetSize(math.floor((banCard:GetWide() - 24) / 2), 30)
    self.KickButton.DoClick = function() submitBanAction("kick") end

    self.TempBanButton = CreateStyledButton(banCard, "Temporary Ban", Color(255, 175, 120, 255))
    self.TempBanButton:SetPos(14 + math.floor((banCard:GetWide() - 24) / 2), 140)
    self.TempBanButton:SetSize(math.floor((banCard:GetWide() - 24) / 2), 30)
    self.TempBanButton.DoClick = function() submitBanAction("temp_ban") end

    self.PermBanButton = CreateStyledButton(banCard, "Permanent Ban", Color(255, 135, 120, 255))
    self.PermBanButton:SetPos(10, 174)
    self.PermBanButton:SetSize(math.floor((banCard:GetWide() - 24) / 2), 30)
    self.PermBanButton.DoClick = function() submitBanAction("perm_ban") end

    self.UnbanButton = CreateStyledButton(banCard, "Unban", Color(160, 225, 200, 255))
    self.UnbanButton:SetPos(14 + math.floor((banCard:GetWide() - 24) / 2), 174)
    self.UnbanButton:SetSize(math.floor((banCard:GetWide() - 24) / 2), 30)
    self.UnbanButton.DoClick = function() submitBanAction("unban") end

    local movementTitle = vgui.Create("DLabel", movementCard)
    movementTitle:SetFont("LeopardRP.Menu.PanelBold")
    movementTitle:SetTextColor(Color(235, 245, 255))
    movementTitle:SetText("Bring / Teleport")
    movementTitle:SizeToContents()
    movementTitle:SetPos(10, 8)

    local movementHint = vgui.Create("DLabel", movementCard)
    movementHint:SetFont("LeopardRP.Menu.Micro")
    movementHint:SetTextColor(Color(205, 225, 240, 235))
    movementHint:SetText("Uses selected target above. Return sends target back to their pre-bring position.")
    movementHint:SetPos(10, 30)
    movementHint:SetSize(movementCard:GetWide() - 20, 28)
    movementHint:SetWrap(true)

    local function submitMoveAction(action)
        local targetSteamID64 = self.PunishTarget:GetOptionData(self.PunishTarget:GetSelectedID() or 0)
        Admin.SubmitAction({
            type = "punishment",
            punishmentType = action,
            targetSteamID64 = targetSteamID64 or "",
            targetName = self.PunishTarget:GetValue() or "",
            reason = "Movement utility",
            notes = "",
            durationYears = 0,
            durationDays = 0,
            durationSeconds = 0,
        })
    end

    self.BringButton = CreateStyledButton(movementCard, "Bring Target", Color(150, 210, 255, 255))
    self.BringButton:SetPos(10, 66)
    self.BringButton:SetSize(movementCard:GetWide() - 20, 30)
    self.BringButton.DoClick = function() submitMoveAction("bring") end

    self.TeleportButton = CreateStyledButton(movementCard, "Teleport To Target", Color(145, 220, 180, 255))
    self.TeleportButton:SetPos(10, 100)
    self.TeleportButton:SetSize(movementCard:GetWide() - 20, 30)
    self.TeleportButton.DoClick = function() submitMoveAction("teleport") end

    self.ReturnButton = CreateStyledButton(movementCard, "Return Target", Color(255, 198, 150, 255))
    self.ReturnButton:SetPos(10, 134)
    self.ReturnButton:SetSize(movementCard:GetWide() - 20, 30)
    self.ReturnButton.DoClick = function() submitMoveAction("return") end

    local punishmentTypes = {
        { id = "warn", text = "Warn" },
        { id = "mute", text = "Mute" },
        { id = "gag", text = "Gag" },
        { id = "jail", text = "Jail" },
        { id = "freeze", text = "Freeze" },
        { id = "spectate", text = "Spectate" },
    }

    for _, punishment in ipairs(punishmentTypes) do
        self.PunishType:AddChoice(punishment.text, punishment.id)
    end
end

function PANEL:BuildHistoryPage()
    local page = self:CreatePage("history")
    local card = CreateCard(page)
    card:SetSize(page:GetWide(), page:GetTall())
    card:SetPos(0, 0)

    self.HistorySearch = CreateStyledEntry(card, "Search player, staff, reason, punishment")
    self.HistorySearch:SetPos(12, 12)
    self.HistorySearch:SetSize(card:GetWide() * 0.6, 30)

    self.HistoryFilter = CreateStyledCombo(card)
    self.HistoryFilter:SetPos(card:GetWide() * 0.6 + 16, 12)
    self.HistoryFilter:SetSize(card:GetWide() * 0.4 - 28, 30)
    self.HistoryFilter:AddChoice("All", "all")
    self.HistoryFilter:AddChoice("Warn", "warn")
    self.HistoryFilter:AddChoice("Kick", "kick")
    self.HistoryFilter:AddChoice("Ban", "ban")
    self.HistoryFilter:AddChoice("Mute/Gag", "voice")

    self.HistoryList = vgui.Create("DScrollPanel", card)
    self.HistoryList:SetPos(12, 52)
    self.HistoryList:SetSize(card:GetWide() - 24, card:GetTall() - 64)
end

function PANEL:BuildRulebookPage()
    local page = self:CreatePage("rulebook")
    local card = CreateCard(page)
    card:SetSize(page:GetWide(), page:GetTall())
    card:SetPos(0, 0)

    self.RulebookEditor = vgui.Create("DTextEntry", card)
    self.RulebookEditor:SetMultiline(true)
    self.RulebookEditor:SetPos(12, 12)
    self.RulebookEditor:SetSize(card:GetWide() - 24, card:GetTall() - 60)
    if LeopardRP.CharacterCreation.StyleTextEntry then
        LeopardRP.CharacterCreation.StyleTextEntry(self.RulebookEditor)
    end

    self.RulebookSave = CreateStyledButton(card, "Save Rulebook", Color(255, 198, 150, 255))
    self.RulebookSave:SetPos(12, card:GetTall() - 40)
    self.RulebookSave:SetSize(card:GetWide() - 24, 30)
    self.RulebookSave.DoClick = function()
        local lines = string.Explode("\n", self.RulebookEditor:GetValue() or "")
        local sections = {}
        for _, line in ipairs(lines) do
            line = string.Trim(line)
            if line ~= "" then
                table.insert(sections, { title = "Rule", body = line })
            end
        end

        Admin.SubmitAction({
            type = "update_rulebook",
            rulebook = { sections = sections }
        })
    end
end

function PANEL:BuildGuidelinesPage()
    local page = self:CreatePage("guidelines")
    local card = CreateCard(page)
    card:SetSize(page:GetWide(), page:GetTall())
    card:SetPos(0, 0)

    self.GuidelinesEditor = vgui.Create("DTextEntry", card)
    self.GuidelinesEditor:SetMultiline(true)
    self.GuidelinesEditor:SetPos(12, 12)
    self.GuidelinesEditor:SetSize(card:GetWide() - 24, card:GetTall() - 60)
    if LeopardRP.CharacterCreation.StyleTextEntry then
        LeopardRP.CharacterCreation.StyleTextEntry(self.GuidelinesEditor)
    end

    self.GuidelinesSave = CreateStyledButton(card, "Save Guidelines", Color(255, 198, 150, 255))
    self.GuidelinesSave:SetPos(12, card:GetTall() - 40)
    self.GuidelinesSave:SetSize(card:GetWide() - 24, 30)
    self.GuidelinesSave.DoClick = function()
        local entries = {}
        for _, line in ipairs(string.Explode("\n", self.GuidelinesEditor:GetValue() or "")) do
            line = string.Trim(line)
            if line ~= "" then
                table.insert(entries, {
                    key = line,
                    description = line,
                    recommended = "Refer to policy",
                    escalation = "Escalate for repeats",
                    notes = ""
                })
            end
        end

        Admin.SubmitAction({
            type = "update_guidelines",
            guidelines = { entries = entries }
        })
    end
end

function PANEL:BuildLogsPage()
    local page = self:CreatePage("logs")
    local card = CreateCard(page)
    card:SetSize(page:GetWide(), page:GetTall())
    card:SetPos(0, 0)

    self.LogList = vgui.Create("DScrollPanel", card)
    self.LogList:SetPos(10, 10)
    self.LogList:SetSize(card:GetWide() - 20, card:GetTall() - 20)
end

local function RowMatchesFilters(row, searchText, filterMode)
    searchText = string.Trim(string.lower(tostring(searchText or "")))
    filterMode = tostring(filterMode or "all")

    if filterMode == "warn" and tostring(row.punishmentType) ~= "warn" then return false end
    if filterMode == "kick" and tostring(row.punishmentType) ~= "kick" then return false end
    if filterMode == "ban" and tostring(row.punishmentType) ~= "temp_ban" and tostring(row.punishmentType) ~= "perm_ban" then return false end
    if filterMode == "voice" and tostring(row.punishmentType) ~= "mute" and tostring(row.punishmentType) ~= "gag" then return false end

    if searchText == "" then return true end

    local haystack = string.lower(table.concat({
        tostring(row.targetName or ""),
        tostring(row.targetSteamID64 or ""),
        tostring(row.staffName or ""),
        tostring(row.punishmentType or ""),
        tostring(row.reason or ""),
        tostring(row.notes or "")
    }, " "))

    return string.find(haystack, searchText, 1, true) ~= nil
end

local function FormatActionText(actionID)
    local action = string.Trim(tostring(actionID or ""))
    if action == "" then
        return "Unknown"
    end

    action = string.Replace(action, "_", " ")
    return string.upper(string.sub(action, 1, 1)) .. string.sub(action, 2)
end

local function BuildAdminLogDetails(details)
    if not istable(details) then
        return ""
    end

    local parts = {}
    local reason = string.Trim(tostring(details.reason or ""))
    local duration = string.Trim(tostring(details.duration or ""))
    local notes = string.Trim(tostring(details.notes or ""))
    local backend = string.Trim(tostring(details.backend or ""))
    local rankID = string.Trim(tostring(details.rankID or ""))
    local actionsPerformed = tonumber(details.actionsPerformed)
    local sessionLength = tonumber(details.sessionLengthSeconds)

    if reason ~= "" then
        table.insert(parts, "Reason: " .. reason)
    end
    if duration ~= "" then
        table.insert(parts, "Duration: " .. duration)
    end
    if notes ~= "" then
        table.insert(parts, "Notes: " .. notes)
    end
    if backend ~= "" then
        table.insert(parts, "Backend: " .. backend)
    end
    if rankID ~= "" then
        table.insert(parts, "Rank: " .. rankID)
    end
    if actionsPerformed and actionsPerformed >= 0 then
        table.insert(parts, "Actions: " .. tostring(actionsPerformed))
    end
    if sessionLength and sessionLength >= 0 then
        table.insert(parts, "Session: " .. string.NiceTime(sessionLength))
    end

    return table.concat(parts, " | ")
end

function PANEL:RenderPunishmentHistory(state)
    self.HistoryList:Clear()

    local searchText = self.HistorySearch:GetValue() or ""
    local filterMode = self.HistoryFilter:GetOptionData(self.HistoryFilter:GetSelectedID() or 0) or "all"

    for _, row in ipairs(state.punishments or {}) do
        if RowMatchesFilters(row, searchText, filterMode) then
            local card = CreateCard(self.HistoryList)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 8)
            card:SetTall(90)

            local top = vgui.Create("DLabel", card)
            top:SetFont("LeopardRP.Menu.Small")
            top:SetTextColor(Color(240, 246, 255, 245))
            top:SetText(string.format("%s -> %s (%s)", tostring(row.staffName or "Unknown"), tostring(row.targetName or "Unknown"), tostring(row.punishmentType or "unknown")))
            top:SetWrap(true)
            top:SetAutoStretchVertical(true)

            local mid = vgui.Create("DLabel", card)
            mid:SetFont("LeopardRP.Menu.Micro")
            mid:SetTextColor(Color(200, 222, 242, 235))
            mid:SetText(string.format("Reason: %s | Duration: %s", tostring(row.reason or ""), tostring(row.duration or "N/A")))
            mid:SetWrap(true)
            mid:SetAutoStretchVertical(true)

            local bottom = vgui.Create("DLabel", card)
            bottom:SetFont("LeopardRP.Menu.Micro")
            bottom:SetTextColor(Color(188, 208, 230, 220))
            bottom:SetText(string.format("%s %s | Stardate %s", tostring(row.date or ""), tostring(row.time or ""), tostring(row.stardate or "")))
            bottom:SetWrap(true)
            bottom:SetAutoStretchVertical(true)

            card.PerformLayout = function(panel, w)
                local contentW = math.max(120, w - 24)

                top:SetPos(12, 8)
                top:SetSize(contentW, 24)
                top:SizeToContentsY()

                local midY = 8 + math.max(22, top:GetTall()) + 2
                mid:SetPos(12, midY)
                mid:SetSize(contentW, 20)
                mid:SizeToContentsY()

                local bottomY = midY + math.max(20, mid:GetTall()) + 4
                bottom:SetPos(12, bottomY)
                bottom:SetSize(contentW, 18)
                bottom:SizeToContentsY()

                local desiredTall = math.max(90, bottomY + math.max(18, bottom:GetTall()) + 8)
                if panel:GetTall() ~= desiredTall then
                    panel:SetTall(desiredTall)
                end
            end
        end
    end
end

function PANEL:OnDataUpdated(state)
    state = state or {}
    local function sortByWeightDescending(list)
        local sorted = table.Copy(list or {})
        table.sort(sorted, function(a, b)
            local aWeight = tonumber(a and (a.Weight or a.weight)) or 0
            local bWeight = tonumber(b and (b.Weight or b.weight)) or 0
            if aWeight == bWeight then
                return string.lower(tostring(a and (a.Name or a.ID) or "")) < string.lower(tostring(b and (b.Name or b.ID) or ""))
            end
            return aWeight > bWeight
        end)
        return sorted
    end
    local clock = state.clock or {}

    local isClockedIn = tobool(clock.clockedIn)
    self.ClockStatus:SetText("Status: " .. (isClockedIn and "Clocked In" or "Clocked Out"))
    self.ClockStatus:SizeToContents()
    self.ClockButton:SetButtonText(isClockedIn and "Clock Out" or "Clock In")
    self.RankDetail:SetText("Admin Rank: " .. tostring(clock.rankName or "Unknown"))
    self.RankDetail:SizeToContents()

    self.RankTargetCombo:Clear()
    self.PunishTarget:Clear()
    for _, playerData in ipairs(state.onlinePlayers or {}) do
        local label = string.format("%s (%s)", tostring(playerData.name or "Unknown"), tostring(playerData.characterName or "No Character"))
        self.RankTargetCombo:AddChoice(label, playerData.steamID64)
        self.PunishTarget:AddChoice(label, playerData.steamID64)
    end

    self.RankValueCombo:Clear()
    for _, rankData in ipairs(sortByWeightDescending(state.adminRanks or {})) do
        self.RankValueCombo:AddChoice(tostring(rankData.Name or rankData.ID), tostring(rankData.ID or "none"))
    end

    local canManage = tobool(clock.canManageStaff)
    self.RankApplyButton:SetEnabled(canManage)
    self.RankTargetCombo:SetEnabled(canManage)
    self.RankValueCombo:SetEnabled(canManage)

    local canEditPolicy = tobool(clock.canEditPolicy)
    self.RulebookSave:SetEnabled(canEditPolicy)
    self.GuidelinesSave:SetEnabled(canEditPolicy)
    self.RulebookEditor:SetEditable(canEditPolicy)
    self.GuidelinesEditor:SetEditable(canEditPolicy)

    self.OverviewList:Clear()
    local overviewRows = {
        "Administration permissions are fully separate from RP and Game Master permissions.",
        "Clock In enables moderation authority and accountability logging.",
        "Punishment center requires reason, duration where applicable, and staff origin.",
        "Rulebook and guideline edits are restricted to Head Administrator and Owner."
    }

    for _, text in ipairs(overviewRows) do
        local row = CreateCard(self.OverviewList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetTall(52)

        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Small")
        label:SetTextColor(Color(228, 240, 255, 245))
        label:SetText(text)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)

        row.PerformLayout = function(panel, w)
            label:SetPos(12, 10)
            label:SetSize(math.max(120, w - 24), 24)
            label:SizeToContentsY()

            local desiredTall = math.max(52, label:GetTall() + 20)
            if panel:GetTall() ~= desiredTall then
                panel:SetTall(desiredTall)
            end
        end
    end

    local ruleSections = (state.rulebook and state.rulebook.sections) or {}
    local ruleLines = {}
    for _, section in ipairs(ruleSections) do
        table.insert(ruleLines, tostring(section.title or "Rule") .. ": " .. tostring(section.body or ""))
    end
    self.RulebookEditor:SetValue(table.concat(ruleLines, "\n"))

    local guidelineEntries = (state.guidelines and state.guidelines.entries) or {}
    local guidelineLines = {}
    for _, row in ipairs(guidelineEntries) do
        table.insert(guidelineLines, string.format("%s | %s | %s | %s", tostring(row.key or "guideline"), tostring(row.description or ""), tostring(row.recommended or ""), tostring(row.escalation or "")))
    end
    self.GuidelinesEditor:SetValue(table.concat(guidelineLines, "\n"))

    self:RenderPunishmentHistory(state)

    self.LogList:Clear()
    for _, logEntry in ipairs(state.logs or {}) do
        local card = CreateCard(self.LogList)
        card:Dock(TOP)
        card:DockMargin(0, 0, 0, 8)
        card:SetTall(92)

        local header = vgui.Create("DLabel", card)
        header:SetFont("LeopardRP.Menu.Small")
        header:SetTextColor(Color(240, 246, 255, 245))
        header:SetText(string.format("%s | %s | %s", tostring(logEntry.staffName or "Unknown"), FormatActionText(logEntry.action), tostring(logEntry.targetName or "No target")))
        header:SetWrap(true)
        header:SetAutoStretchVertical(true)

        local detailsText = BuildAdminLogDetails(logEntry.details)
        if detailsText == "" then
            detailsText = "No additional details."
        end

        local details = vgui.Create("DLabel", card)
        details:SetFont("LeopardRP.Menu.Micro")
        details:SetTextColor(Color(255, 181, 118, 235))
        details:SetWrap(true)
        details:SetAutoStretchVertical(true)
        details:SetText(detailsText)

        local footer = vgui.Create("DLabel", card)
        footer:SetFont("LeopardRP.Menu.Micro")
        footer:SetTextColor(Color(190, 210, 232, 230))
        footer:SetText(string.format("%s %s | Stardate %s", tostring(logEntry.date or ""), tostring(logEntry.time or ""), tostring(logEntry.stardate or "")))
        footer:SetWrap(true)
        footer:SetAutoStretchVertical(true)

        card.PerformLayout = function(panel, w)
            local contentW = math.max(120, w - 24)

            header:SetPos(12, 8)
            header:SetSize(contentW, 24)
            header:SizeToContentsY()

            local detailsY = 8 + math.max(22, header:GetTall()) + 2
            details:SetPos(12, detailsY)
            details:SetSize(contentW, 24)
            details:SizeToContentsY()

            local footerY = detailsY + math.max(22, details:GetTall()) + 4
            footer:SetPos(12, footerY)
            footer:SetSize(contentW, 20)
            footer:SizeToContentsY()

            local desiredTall = math.max(92, footerY + math.max(20, footer:GetTall()) + 8)
            if panel:GetTall() ~= desiredTall then
                panel:SetTall(desiredTall)
            end
        end
    end
end

vgui.Register("LeopardRPAdministrationMenu", PANEL, "EditablePanel")

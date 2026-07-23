LeopardRP = LeopardRP or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Personnel = LeopardRP.Personnel
local Theme = LeopardRP.CharacterCreation.Theme or {}

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

Personnel.Manifest = Personnel.Manifest or {
    Data = {
        serverName = "Server",
        stardate = "--",
        playersOnline = 0,
        maxPlayers = game.MaxPlayers(),
        players = {},
    }
}

local DIVISION_ICONS = {
    Command = "CMD",
    Operations = "OPS",
    Science = "SCI",
    Medical = "MED",
    Security = "SEC",
    Engineering = "ENG",
    Tactical = "TAC",
}

local SORT_FIELDS = {
    { id = "rank", label = "Rank" },
    { id = "division", label = "Division" },
    { id = "characterName", label = "Character Name" },
    { id = "secondaryPosition", label = "Secondary Position" },
    { id = "adminRank", label = "Admin Rank" },
    { id = "gmRank", label = "GM Rank" },
    { id = "joinTime", label = "Join Time" },
    { id = "ping", label = "Ping" },
}

local REPORT_CATEGORIES = {
    { id = "harassment", label = "Harassment" },
    { id = "failrp", label = "FailRP" },
    { id = "metagaming", label = "Metagaming" },
    { id = "rdm", label = "RDM" },
    { id = "exploit", label = "Exploit" },
    { id = "chat_abuse", label = "Chat Abuse" },
    { id = "other", label = "Other" },
}

local function requestManifestData()
    if not Personnel.NetworkStrings or not Personnel.NetworkStrings.RequestManifest then return end

    net.Start(Personnel.NetworkStrings.RequestManifest)
    net.SendToServer()
end

local function readPayload()
    local compressed = net.ReadBool()
    if compressed then
        local length = net.ReadUInt(32)
        local raw = net.ReadData(length)
        return util.JSONToTable(util.Decompress(raw) or "{}") or {}
    end

    return util.JSONToTable(net.ReadString() or "{}") or {}
end

local function getSortFieldLabel(sortField)
    for _, item in ipairs(SORT_FIELDS) do
        if item.id == sortField then
            return item.label
        end
    end

    return "Rank"
end

local function formatStaffTag(rankText, isClocked)
    rankText = string.Trim(tostring(rankText or ""))

    if (rankText == "" or string.lower(rankText) == "none") then
        return ""
    end

    return isClocked and (rankText .. " [ON]") or (rankText .. " [OFF]")
end

local PANEL = {}

function PANEL:Init()
    local panelWidth = math.Clamp(math.floor(ScrW() * 0.72), 860, 1420)
    local panelHeight = math.Clamp(math.floor(ScrH() * 0.74), 520, 920)

    self:SetSize(panelWidth, panelHeight)
    self:Center()
    self:MakePopup()
    self:SetKeyboardInputEnabled(true)
    self:SetMouseInputEnabled(true)

    self.SearchText = ""
    self.SortField = "rank"
    self.SortAscending = false
    self.LastRefreshRequest = 0

    self.Root = vgui.Create("EditablePanel", self)
    self.Root:Dock(FILL)
    self.Root.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(6, 10, 18, 240))
        surface.SetDrawColor(255, 255, 255, 35)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    self.TitleBar = vgui.Create("DPanel", self.Root)
    self.TitleBar:Dock(TOP)
    self.TitleBar:SetTall(82)
    self.TitleBar:DockMargin(16, 16, 16, 8)
    self.TitleBar.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(14, 22, 36, 220))
        surface.SetDrawColor(255, 255, 255, 45)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.SimpleText("Starfleet Personnel Manifest", "LeopardRP.Menu.PanelBold", 14, 12, Color(230, 240, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        local manifestData = Personnel.Manifest.Data or {}
        local serverName = tostring(manifestData.serverName or "Server")
        local stardate = tostring(manifestData.stardate or "--")
        local online = tonumber(manifestData.playersOnline) or 0
        local maxPlayers = tonumber(manifestData.maxPlayers) or game.MaxPlayers()

        draw.SimpleText(serverName, "LeopardRP.Menu.Small", 14, 40, Color(180, 205, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Stardate: " .. stardate, "LeopardRP.Menu.Small", w * 0.55, 14, Color(170, 200, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Online: %d/%d", online, maxPlayers), "LeopardRP.Menu.Small", w * 0.55, 40, Color(170, 220, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    self.Toolbar = vgui.Create("DPanel", self.Root)
    self.Toolbar:Dock(TOP)
    self.Toolbar:SetTall(46)
    self.Toolbar:DockMargin(16, 0, 16, 8)
    self.Toolbar.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(12, 18, 30, 205))
        surface.SetDrawColor(255, 255, 255, 35)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    self.SearchBox = vgui.Create("DTextEntry", self.Toolbar)
    self.SearchBox:SetPlaceholderText("Search name, division, rank, position, admin, GM")
    self.SearchBox.OnValueChange = function(_, value)
        self.SearchText = string.lower(string.Trim(tostring(value or "")))
        self:RefreshRows()
    end

    self.SortCombo = vgui.Create("DComboBox", self.Toolbar)
    for _, item in ipairs(SORT_FIELDS) do
        self.SortCombo:AddChoice(item.label, item.id, item.id == self.SortField)
    end
    self.SortCombo.OnSelect = function(_, _, _, data)
        self.SortField = tostring(data or "rank")
        self:RefreshRows()
    end

    self.SortDirectionButton = vgui.Create("DButton", self.Toolbar)
    self.SortDirectionButton:SetText("")
    self.SortDirectionButton.DoClick = function()
        self.SortAscending = not self.SortAscending
        self:RefreshRows()
    end
    self.SortDirectionButton.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 34, 56, 220))
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        local dirText = self.SortAscending and "Ascending" or "Descending"
        draw.SimpleText("Sort: " .. getSortFieldLabel(self.SortField) .. " (" .. dirText .. ")", "LeopardRP.Menu.Small", 8, 9, Color(220, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    self.Header = vgui.Create("DPanel", self.Root)
    self.Header:Dock(TOP)
    self.Header:SetTall(32)
    self.Header:DockMargin(16, 0, 16, 0)
    self.Header.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(18, 30, 48, 220))
        surface.SetDrawColor(255, 255, 255, 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local columns = {
            { "Character Name", 0.02 },
            { "Division", 0.25 },
            { "Rank", 0.41 },
            { "Secondary Position", 0.56 },
            { "Admin Rank", 0.75 },
            { "GM Rank", 0.88 },
            { "Ping", 0.96 },
        }

        for _, col in ipairs(columns) do
            draw.SimpleText(col[1], "LeopardRP.Menu.Micro", w * col[2], 9, Color(195, 220, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    self.List = vgui.Create("DScrollPanel", self.Root)
    self.List:Dock(FILL)
    self.List:DockMargin(16, 0, 16, 16)

    requestManifestData()
end

function PANEL:PerformLayout(w, h)
    if IsValid(self.SearchBox) then
        self.SearchBox:SetPos(10, 8)
        self.SearchBox:SetSize(w * 0.43, 30)
    end

    if IsValid(self.SortCombo) then
        self.SortCombo:SetPos(w * 0.45 + 18, 8)
        self.SortCombo:SetSize(w * 0.20, 30)
    end

    if IsValid(self.SortDirectionButton) then
        self.SortDirectionButton:SetPos(w * 0.66 + 26, 8)
        self.SortDirectionButton:SetSize(w * 0.31 - 36, 30)
    end
end

function PANEL:PassesFilter(entry)
    if self.SearchText == "" then
        return true
    end

    local blob = string.lower(table.concat({
        tostring(entry.characterName or ""),
        tostring(entry.division or ""),
        tostring(entry.rankName or ""),
        tostring(entry.secondaryPosition or ""),
        tostring(entry.adminRank or ""),
        tostring(entry.gmRank or ""),
    }, " "))

    return string.find(blob, self.SearchText, 1, true) ~= nil
end

function PANEL:GetSortedEntries()
    local source = (Personnel.Manifest.Data and Personnel.Manifest.Data.players) or {}
    local entries = {}

    for _, item in ipairs(source) do
        if self:PassesFilter(item) then
            table.insert(entries, item)
        end
    end

    local sortField = tostring(self.SortField or "rank")
    local asc = self.SortAscending == true

    table.sort(entries, function(a, b)
        local av
        local bv

        if sortField == "rank" then
            av = tonumber(a.rankOrder) or 0
            bv = tonumber(b.rankOrder) or 0
        elseif sortField == "division" then
            av = string.lower(tostring(a.division or ""))
            bv = string.lower(tostring(b.division or ""))
        elseif sortField == "characterName" then
            av = string.lower(tostring(a.characterName or ""))
            bv = string.lower(tostring(b.characterName or ""))
        elseif sortField == "secondaryPosition" then
            av = string.lower(tostring(a.secondaryPosition or ""))
            bv = string.lower(tostring(b.secondaryPosition or ""))
        elseif sortField == "adminRank" then
            av = string.lower(tostring(a.adminRank or ""))
            bv = string.lower(tostring(b.adminRank or ""))
        elseif sortField == "gmRank" then
            av = string.lower(tostring(a.gmRank or ""))
            bv = string.lower(tostring(b.gmRank or ""))
        elseif sortField == "joinTime" then
            av = tonumber(a.joinTimestamp) or 0
            bv = tonumber(b.joinTimestamp) or 0
        elseif sortField == "ping" then
            av = tonumber(a.ping) or 0
            bv = tonumber(b.ping) or 0
        else
            av = string.lower(tostring(a.characterName or ""))
            bv = string.lower(tostring(b.characterName or ""))
        end

        if av == bv then
            local an = string.lower(tostring(a.characterName or ""))
            local bn = string.lower(tostring(b.characterName or ""))
            return asc and an < bn or an > bn
        end

        if type(av) == "number" and type(bv) == "number" then
            return asc and av < bv or av > bv
        end

        return asc and tostring(av) < tostring(bv) or tostring(av) > tostring(bv)
    end)

    return entries
end

function PANEL:OpenReportWindow(entry)
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Report Player")
    frame:SetSize(520, 320)
    frame:Center()
    frame:MakePopup()

    local targetLabel = vgui.Create("DLabel", frame)
    targetLabel:SetPos(14, 34)
    targetLabel:SetSize(490, 22)
    targetLabel:SetFont("LeopardRP.Menu.Small")
    targetLabel:SetText("Reported Player: " .. tostring(entry.characterName ~= "" and entry.characterName or entry.steamName or "Unknown"))

    local category = vgui.Create("DComboBox", frame)
    category:SetPos(14, 64)
    category:SetSize(240, 28)
    for _, item in ipairs(REPORT_CATEGORIES) do
        category:AddChoice(item.label, item.id, item.id == "other")
    end

    local description = vgui.Create("DTextEntry", frame)
    description:SetPos(14, 100)
    description:SetSize(490, 162)
    description:SetMultiline(true)
    description:SetPlaceholderText("Describe what happened...")

    local submit = vgui.Create("DButton", frame)
    submit:SetText("Submit")
    submit:SetPos(14, 272)
    submit:SetSize(110, 34)
    submit.DoClick = function()
        local _, catId = category:GetSelected()
        local payload = {
            targetSteamID64 = tostring(entry.steamID64 or ""),
            category = tostring(catId or "other"),
            description = tostring(description:GetValue() or ""),
        }

        net.Start(Personnel.NetworkStrings.SubmitPlayerReport)
        net.WriteString(util.TableToJSON(payload, false) or "{}")
        net.SendToServer()

        frame:Close()
    end

    local cancel = vgui.Create("DButton", frame)
    cancel:SetText("Cancel")
    cancel:SetPos(132, 272)
    cancel:SetSize(110, 34)
    cancel.DoClick = function()
        frame:Close()
    end
end

function PANEL:OpenContextMenu(entry)
    local menu = DermaMenu()

    menu:AddOption("Copy SteamID", function()
        SetClipboardText(tostring(entry.steamID or ""))
    end)

    menu:AddOption("Copy SteamID64", function()
        SetClipboardText(tostring(entry.steamID64 or ""))
    end)

    menu:AddOption("Copy Character Name", function()
        SetClipboardText(tostring(entry.characterName or ""))
    end)

    menu:AddOption("Open Steam Profile", function()
        local id64 = tostring(entry.steamID64 or "")
        if id64 ~= "" then
            gui.OpenURL("https://steamcommunity.com/profiles/" .. id64)
        end
    end)

    menu:AddOption("Report Player", function()
        self:OpenReportWindow(entry)
    end)

    local viewInfo = menu:AddOption("View Character Information (future)", function() end)
    viewInfo:SetEnabled(false)
    local sendPm = menu:AddOption("Send PM (future)", function() end)
    sendPm:SetEnabled(false)

    menu:Open()
end

function PANEL:AddEntryRow(entry)
    local row = vgui.Create("DButton", self.List)
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, 6)
    row:SetText("")

    local secondary = tostring(entry.secondaryPosition or "")
    local dynamicHeight = 36 + math.max(0, math.floor(#secondary / 42)) * 12
    row:SetTall(dynamicHeight)

    row.Paint = function(panel, w, h)
        local hovered = panel:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, hovered and Color(26, 40, 62, 235) or Color(16, 24, 38, 220))
        surface.SetDrawColor(255, 255, 255, hovered and 70 or 40)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local nameText = tostring(entry.characterName ~= "" and entry.characterName or entry.steamName or "Unknown")
        local divisionName = tostring(entry.division or "")
        local icon = DIVISION_ICONS[divisionName] or "---"
        local divisionText = divisionName ~= "" and ("[" .. icon .. "] " .. divisionName) or ""
        local rankText = string.Trim(tostring(entry.rankName or ""))
        if (rankText == "") then
            rankText = "Unassigned"
        end
        local secondaryText = tostring(entry.secondaryPosition or "")
        local adminText = formatStaffTag(entry.adminRank, entry.adminClockedIn)
        local gmText = formatStaffTag(entry.gmRank, entry.gmClockedIn)
        local pingValue = tonumber(entry.ping) or 0
        local pingText = string.format("%d ms", math.max(math.floor(pingValue), 0))

        draw.SimpleText(nameText, "LeopardRP.Menu.Small", w * 0.02, 9, Color(235, 242, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(divisionText, "LeopardRP.Menu.Micro", w * 0.25, 10, Color(185, 215, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(rankText, "LeopardRP.Menu.Micro", w * 0.41, 10, Color(210, 225, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(secondaryText, "LeopardRP.Menu.Micro", w * 0.56, 10, Color(190, 220, 230), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(adminText, "LeopardRP.Menu.Micro", w * 0.75, 10, Color(255, 210, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(gmText, "LeopardRP.Menu.Micro", w * 0.88, 10, Color(195, 255, 190), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(pingText, "LeopardRP.Menu.Micro", w * 0.96, 10, Color(180, 230, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    end

    row.OnMousePressed = function(_, mouseCode)
        if mouseCode == MOUSE_RIGHT then
            self:OpenContextMenu(entry)
        end
    end
end

function PANEL:RefreshRows()
    if not IsValid(self.List) then return end

    self.List:Clear()
    for _, entry in ipairs(self:GetSortedEntries()) do
        self:AddEntryRow(entry)
    end
end

function PANEL:Think()
    if (!input.IsKeyDown(KEY_TAB)) then
        self:Remove()
        return
    end

    if CurTime() >= (self.LastRefreshRequest or 0) + 2 then
        self.LastRefreshRequest = CurTime()
        requestManifestData()
    end
end

function PANEL:OnRemove()
    if Personnel.Manifest and Personnel.Manifest.ActivePanel == self then
        Personnel.Manifest.ActivePanel = nil
    end

    if (!IsValid(LeopardRP and LeopardRP.Personnel and LeopardRP.Personnel.ActivePanel) and !IsValid(LeopardRP and LeopardRP.GameMaster and LeopardRP.GameMaster.ActivePanel) and !IsValid(LeopardRP and LeopardRP.Administration and LeopardRP.Administration.ActivePanel) and !IsValid(ix and ix.gui and ix.gui.menu)) then
        SetMenuInteractionEnabled(false)
    end
end

vgui.Register("LeopardRPPersonnelManifest", PANEL, "EditablePanel")

net.Receive(Personnel.NetworkStrings.ReceiveManifest, function()
    local payload = readPayload()
    Personnel.Manifest.Data = payload

    if IsValid(Personnel.Manifest.ActivePanel) then
        Personnel.Manifest.ActivePanel:RefreshRows()
    end
end)

hook.Add("ScoreboardShow", "LeopardRP.PersonnelManifest.Show", function()
    if IsValid(Personnel.Manifest.ActivePanel) then
        Personnel.Manifest.ActivePanel:Remove()
    end

    local panel = vgui.Create("LeopardRPPersonnelManifest")
    Personnel.Manifest.ActivePanel = panel
    panel:RefreshRows()
    requestManifestData()

    return false
end)

hook.Add("ScoreboardHide", "LeopardRP.PersonnelManifest.Hide", function()
    if IsValid(Personnel.Manifest.ActivePanel) then
        Personnel.Manifest.ActivePanel:Remove()
    end

    Personnel.Manifest.ActivePanel = nil
    return false
end)

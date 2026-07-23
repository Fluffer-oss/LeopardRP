LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

local PANEL = {}

PANEL.Mode = "admin"
PANEL.BackgroundPath = "ui/adminpage"
PANEL.TitleText = "Administration Panel"
PANEL.SubtitleText = "Starfleet Personnel Database Administration"

local function DrawPanelCard(_, w, h)
    draw.RoundedBox(18, 0, 0, w, h, Color(12, 16, 24, 196))
    surface.SetDrawColor(255, 255, 255, 120)
    surface.DrawOutlinedRect(0, 0, w, h, 1)
end

local function MakeSectionLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:SetFont("LeopardRP.Menu.PanelBold")
    label:SetTextColor(Color(225, 235, 255))
    label:SetText(text or "")
    return label
end

function PANEL:Init()
    self.BaseClass.Init(self)
    self.DirectoryTitle:SetText("Player Directory")
    self.CharacterListTitle:SetText("Character List")
    self.DirectorySearch:SetPlaceholderText("Search by SteamID, Steam Name, Character Name")

    self.DirectorySearch.OnTextChanged = function(entry)
        local query = string.Trim(entry:GetValue() or "")
        if #query < 2 and query ~= "" then return end
        LeopardRP.Personnel.RequestDirectory(self.Mode, query)
    end

    self.PageSwitch = vgui.Create("DPanel", self.HeaderBar)
    self.PageSwitch:SetPaintBackground(false)

    self.PersonnelPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.PersonnelPageButton:SetText("")
    self.PersonnelPageButton:SetButtonText("Personnel")
    self.PersonnelPageButton:SetAccentColor(Color(140, 190, 255, 255))

    self.LogPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.LogPageButton:SetText("")
    self.LogPageButton:SetButtonText("Logger")
    self.LogPageButton:SetAccentColor(Color(170, 220, 255, 255))

    self.PermissionPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.PermissionPageButton:SetText("")
    self.PermissionPageButton:SetButtonText("Permissions & Rank Management")
    self.PermissionPageButton:SetAccentColor(Color(160, 225, 200, 255))

    self.DevModePageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.DevModePageButton:SetText("")
    self.DevModePageButton:SetButtonText("Dev Mode")
    self.DevModePageButton:SetAccentColor(Color(255, 200, 140, 255))

    self.ItemManagerButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.ItemManagerButton:SetText("")
    self.ItemManagerButton:SetButtonText("Logistics")
    self.ItemManagerButton:SetAccentColor(Color(255, 205, 145, 255))
    self.ItemManagerButton.DoClick = function()
        self:SetPageMode("logistics")
        LeopardRP.Personnel.RequestLogisticsSettings()
    end

    self.LogPanel = vgui.Create("DPanel", self.Root)
    self.LogPanel.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(12, 16, 24, 196))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.LogPanel:SetVisible(false)

    self.LogSearch = vgui.Create("DTextEntry", self.LogPanel)
    self.LogSearch:SetPlaceholderText("Search logs (name, steamid, category, message)")
    LeopardRP.CharacterCreation.StyleTextEntry(self.LogSearch)
    self.LogSearch.OnEnter = function(entry)
        self:RequestLogs()
    end

    self.LogRefreshButton = vgui.Create("LeopardRPMenuButton", self.LogPanel)
    self.LogRefreshButton:SetText("")
    self.LogRefreshButton:SetButtonText("Refresh Logs")
    self.LogRefreshButton:SetAccentColor(Color(140, 190, 255, 255))
    self.LogRefreshButton.DoClick = function()
        self:RequestLogs()
    end

    self.LogSortWindowButton = vgui.Create("LeopardRPMenuButton", self.LogPanel)
    self.LogSortWindowButton:SetText("")
    self.LogSortWindowButton:SetButtonText("Sort / Filter")
    self.LogSortWindowButton:SetAccentColor(Color(170, 220, 255, 255))
    self.LogSortWindowButton.DoClick = function()
        self:OpenLogSortWindow()
    end

    self.LogList = vgui.Create("DScrollPanel", self.LogPanel)

    self.PermissionPanel = vgui.Create("DPanel", self.Root)
    self.PermissionPanel.Paint = DrawPanelCard
    self.PermissionPanel:SetVisible(false)

    self.DevModePanel = vgui.Create("DPanel", self.Root)
    self.DevModePanel.Paint = DrawPanelCard
    self.DevModePanel:SetVisible(false)

    self.LogisticsPanel = vgui.Create("DPanel", self.Root)
    self.LogisticsPanel.Paint = DrawPanelCard
    self.LogisticsPanel:SetVisible(false)

    self.LogisticsTitle = vgui.Create("DLabel", self.LogisticsPanel)
    self.LogisticsTitle:SetFont("LeopardRP.Menu.PanelBold")
    self.LogisticsTitle:SetTextColor(Color(230, 238, 255))
    self.LogisticsTitle:SetText("Helix Logistics Settings")

    self.LogisticsHint = vgui.Create("DLabel", self.LogisticsPanel)
    self.LogisticsHint:SetFont("LeopardRP.Menu.Micro")
    self.LogisticsHint:SetTextColor(Color(195, 210, 235))
    self.LogisticsHint:SetText("These settings apply to Helix items and inventories.")

    self.LogisticsDropExcessAmmo = vgui.Create("DCheckBoxLabel", self.LogisticsPanel)
    self.LogisticsDropExcessAmmo:SetText("Enable strict item transfer checks")
    self.LogisticsDropExcessAmmo:SetTextColor(Color(205, 220, 245))
    self.LogisticsDropExcessAmmo:SetFont("LeopardRP.Menu.Small")
    self.LogisticsDropExcessAmmo:SizeToContents()

    self.LogisticsDropOnDeath = vgui.Create("DCheckBoxLabel", self.LogisticsPanel)
    self.LogisticsDropOnDeath:SetText("Drop Helix inventory items on death")
    self.LogisticsDropOnDeath:SetTextColor(Color(205, 220, 245))
    self.LogisticsDropOnDeath:SetFont("LeopardRP.Menu.Small")
    self.LogisticsDropOnDeath:SizeToContents()

    self.LogisticsPickupFrame0 = vgui.Create("DCheckBoxLabel", self.LogisticsPanel)
    self.LogisticsPickupFrame0:SetText("Enable compatibility hook flag A")
    self.LogisticsPickupFrame0:SetTextColor(Color(205, 220, 245))
    self.LogisticsPickupFrame0:SetFont("LeopardRP.Menu.Small")
    self.LogisticsPickupFrame0:SizeToContents()

    self.LogisticsPickupCompat = vgui.Create("DCheckBoxLabel", self.LogisticsPanel)
    self.LogisticsPickupCompat:SetText("Enable compatibility hook flag B")
    self.LogisticsPickupCompat:SetTextColor(Color(205, 220, 245))
    self.LogisticsPickupCompat:SetFont("LeopardRP.Menu.Small")
    self.LogisticsPickupCompat:SizeToContents()

    self.LogisticsPickupModeLabel = MakeSectionLabel(self.LogisticsPanel, "Pickup Mode")
    self.LogisticsPickupModeCombo = vgui.Create("DComboBox", self.LogisticsPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.LogisticsPickupModeCombo)
    self.LogisticsPickupModeCombo:AddChoice("Instant pickup (0.0s)", -1)
    self.LogisticsPickupModeCombo:AddChoice("Fast pickup (0.25s)", 0)
    self.LogisticsPickupModeCombo:AddChoice("Default pickup (0.5s)", 1)
    self.LogisticsPickupModeCombo:AddChoice("Slow pickup (1.0s)", 2)

    self.LogisticsDefaultSizeLabel = MakeSectionLabel(self.LogisticsPanel, "Default Character Inventory Size")
    self.LogisticsDefaultSizeEntry = vgui.Create("DTextEntry", self.LogisticsPanel)
    self.LogisticsDefaultSizeEntry:SetPlaceholderText("Width Height (example: 6 4)")
    LeopardRP.CharacterCreation.StyleTextEntry(self.LogisticsDefaultSizeEntry)

    self.LogisticsRefreshButton = vgui.Create("LeopardRPMenuButton", self.LogisticsPanel)
    self.LogisticsRefreshButton:SetText("")
    self.LogisticsRefreshButton:SetButtonText("Refresh")
    self.LogisticsRefreshButton:SetAccentColor(Color(150, 210, 255, 255))
    self.LogisticsRefreshButton.DoClick = function()
        LeopardRP.Personnel.RequestLogisticsSettings()
    end

    self.LogisticsSaveButton = vgui.Create("LeopardRPMenuButton", self.LogisticsPanel)
    self.LogisticsSaveButton:SetText("")
    self.LogisticsSaveButton:SetButtonText("Save Helix Logistics Settings")
    self.LogisticsSaveButton:SetAccentColor(Color(160, 225, 200, 255))
    self.LogisticsSaveButton.DoClick = function()
        local _, pickupMode = self.LogisticsPickupModeCombo:GetSelected()
        LeopardRP.Personnel.SaveLogisticsSettings({
            settings = {
                dropExcessAmmo = self.LogisticsDropExcessAmmo:GetChecked() == true,
                dropOnDeath = self.LogisticsDropOnDeath:GetChecked() == true,
                pickupFrame0 = self.LogisticsPickupFrame0:GetChecked() == true,
                pickupCompat = self.LogisticsPickupCompat:GetChecked() == true,
                pickupMode = tonumber(pickupMode) or -1,
                defaultCaseSize = string.Trim(tostring(self.LogisticsDefaultSizeEntry:GetValue() or "s"))
            }
        })
    end

    self.LogisticsItemEditorButton = vgui.Create("LeopardRPMenuButton", self.LogisticsPanel)
    self.LogisticsItemEditorButton:SetText("")
    self.LogisticsItemEditorButton:SetButtonText("Open Helix Inventory")
    self.LogisticsItemEditorButton:SetAccentColor(Color(255, 205, 145, 255))
    self.LogisticsItemEditorButton.DoClick = function()
        if LeopardRP.Personnel and LeopardRP.Personnel.OpenHelixInventory then
            LeopardRP.Personnel.OpenHelixInventory()
        end
    end

    self.LogisticsItemSpawnerButton = vgui.Create("LeopardRPMenuButton", self.LogisticsPanel)
    self.LogisticsItemSpawnerButton:SetText("")
    self.LogisticsItemSpawnerButton:SetButtonText("Open Item Spawner")
    self.LogisticsItemSpawnerButton:SetAccentColor(Color(255, 180, 120, 255))
    self.LogisticsItemSpawnerButton.DoClick = function()
        if LeopardRP.Personnel and LeopardRP.Personnel.OpenItemSpawner then
            LeopardRP.Personnel.OpenItemSpawner()
        end
    end

    self.DevWhitelistTitle = vgui.Create("DLabel", self.DevModePanel)
    self.DevWhitelistTitle:SetFont("LeopardRP.Menu.PanelBold")
    self.DevWhitelistTitle:SetTextColor(Color(230, 238, 255))
    self.DevWhitelistTitle:SetText("Server Whitelist (Head Admin+)")

    self.DevWhitelistToggle = vgui.Create("DCheckBoxLabel", self.DevModePanel)
    self.DevWhitelistToggle:SetText("Enable server whitelist")
    self.DevWhitelistToggle:SetTextColor(Color(205, 220, 245))
    self.DevWhitelistToggle:SetFont("LeopardRP.Menu.Small")
    self.DevWhitelistToggle:SizeToContents()

    self.DevWhitelistEntry = vgui.Create("DTextEntry", self.DevModePanel)
    self.DevWhitelistEntry:SetPlaceholderText("SteamID64 to allow (e.g. 7656119...)")
    LeopardRP.CharacterCreation.StyleTextEntry(self.DevWhitelistEntry)

    self.DevWhitelistAddButton = vgui.Create("LeopardRPMenuButton", self.DevModePanel)
    self.DevWhitelistAddButton:SetText("")
    self.DevWhitelistAddButton:SetButtonText("Add SteamID")
    self.DevWhitelistAddButton:SetAccentColor(Color(150, 210, 255, 255))

    self.DevWhitelistSaveButton = vgui.Create("LeopardRPMenuButton", self.DevModePanel)
    self.DevWhitelistSaveButton:SetText("")
    self.DevWhitelistSaveButton:SetButtonText("Save Dev Mode Settings")
    self.DevWhitelistSaveButton:SetAccentColor(Color(160, 225, 200, 255))

    self.DevWhitelistList = vgui.Create("DScrollPanel", self.DevModePanel)
    self.DevWhitelistCandidatesTitle = vgui.Create("DLabel", self.DevModePanel)
    self.DevWhitelistCandidatesTitle:SetFont("LeopardRP.Menu.PanelBold")
    self.DevWhitelistCandidatesTitle:SetTextColor(Color(220, 235, 255))
    self.DevWhitelistCandidatesTitle:SetText("Whitelist Candidates (Offline Characters + Denied Joins)")
    self.DevWhitelistCandidatesTitle:SizeToContents()
    self.DevWhitelistCandidatesList = vgui.Create("DScrollPanel", self.DevModePanel)
    self.DevWhitelistSteamIds = {}
    self.DevWhitelistCandidates = {}

    self.DevWhitelistAddButton.DoClick = function()
        local steamID64 = string.Trim(tostring(self.DevWhitelistEntry:GetValue() or ""))
        if steamID64 == "" then return end
        if not string.match(steamID64, "^%d+$") then return end

        for _, existing in ipairs(self.DevWhitelistSteamIds) do
            if tostring(existing) == steamID64 then
                return
            end
        end

        table.insert(self.DevWhitelistSteamIds, steamID64)
        table.sort(self.DevWhitelistSteamIds)
        self.DevWhitelistEntry:SetText("")
        self:RefreshDevWhitelistList()
        self:RefreshDevWhitelistCandidateList()
    end

    self.DevWhitelistSaveButton.DoClick = function()
        LeopardRP.Personnel.SaveDevModeSettings({
            whitelistEnabled = self.DevWhitelistToggle:GetChecked() == true,
            whitelistSteamIds = self.DevWhitelistSteamIds or {}
        })
    end

    self.PermissionLeft = vgui.Create("DPanel", self.PermissionPanel)
    self.PermissionLeft.Paint = DrawPanelCard
    self.PermissionCenter = vgui.Create("DPanel", self.PermissionPanel)
    self.PermissionCenter.Paint = DrawPanelCard
    self.PermissionRight = vgui.Create("DPanel", self.PermissionPanel)
    self.PermissionRight.Paint = DrawPanelCard

    self.PermissionDirectoryTitle = MakeSectionLabel(self.PermissionLeft, "Player Directory")
    self.PermissionDirectorySearch = vgui.Create("DTextEntry", self.PermissionLeft)
    self.PermissionDirectorySearch:SetPlaceholderText("Search by SteamID, Steam Name, Character")
    LeopardRP.CharacterCreation.StyleTextEntry(self.PermissionDirectorySearch)
    self.PermissionDirectorySearch.OnEnter = function(entry)
        LeopardRP.Personnel.RequestDirectory("admin", entry:GetValue() or "")
    end

    self.PermissionDirectoryList = vgui.Create("DScrollPanel", self.PermissionLeft)

    self.PermissionCharacterTitle = MakeSectionLabel(self.PermissionCenter, "Character List")
    self.PermissionCharacterList = vgui.Create("DScrollPanel", self.PermissionCenter)

    self.PermissionSummaryTitle = MakeSectionLabel(self.PermissionRight, "Permission Profile")
    self.PermissionSummaryLabel = vgui.Create("DLabel", self.PermissionRight)
    self.PermissionSummaryLabel:SetFont("LeopardRP.Menu.Micro")
    self.PermissionSummaryLabel:SetTextColor(Color(195, 210, 235))
    self.PermissionSummaryLabel:SetWrap(true)
    self.PermissionSummaryLabel:SetAutoStretchVertical(true)
    self.PermissionSummaryLabel:SetText("Select a player and character to manage permissions.")

    local function createCombo(labelText)
        local label = vgui.Create("DLabel", self.PermissionRight)
        label:SetFont("LeopardRP.Menu.Small")
        label:SetTextColor(Color(225, 235, 255))
        label:SetText(labelText)

        local combo = vgui.Create("DComboBox", self.PermissionRight)
        LeopardRP.CharacterCreation.StyleComboBox(combo)
        combo:SetTooltip("")
        return label, combo
    end

    self.ServerPermissionLabel, self.ServerPermissionCombo = createCombo("Server Permission")
    self.GMRankLabel, self.GMRankCombo = createCombo("Game Master Rank")
    self.AdminRankLabel, self.AdminRankCombo = createCombo("Administration Rank")
    self.PromotionProfileLabel, self.PromotionProfileCombo = createCombo("Promotion Permission Profile")
    self.RPRankLabel, self.RPRankCombo = createCombo("RP Rank")
    self.RPDepartmentLabel, self.RPDepartmentCombo = createCombo("RP Department")
    self.RPActivityLabel, self.RPActivityCombo = createCombo("RP Activity")

    self.RPPositionLabel = vgui.Create("DLabel", self.PermissionRight)
    self.RPPositionLabel:SetFont("LeopardRP.Menu.Small")
    self.RPPositionLabel:SetTextColor(Color(225, 235, 255))
    self.RPPositionLabel:SetText("RP Position")
    self.RPPositionEntry = vgui.Create("DTextEntry", self.PermissionRight)
    LeopardRP.CharacterCreation.StyleTextEntry(self.RPPositionEntry)

    self.TrainingToggle = vgui.Create("DCheckBoxLabel", self.PermissionRight)
    self.TrainingToggle:SetText("Allow Training Management")
    self.TrainingToggle:SetTextColor(Color(205, 220, 245))
    self.TrainingToggle:SetFont("LeopardRP.Menu.Small")
    self.TrainingToggle:SizeToContents()

    self.PermissionSave = vgui.Create("LeopardRPMenuButton", self.PermissionRight)
    self.PermissionSave:SetText("")
    self.PermissionSave:SetButtonText("Save Permissions")
    self.PermissionSave:SetAccentColor(Color(150, 210, 255, 255))
    self.PermissionSave.DoClick = function()
        if not self.PermissionSelectedSteamID64 or self.PermissionSelectedSteamID64 == "" then return end

        local _, serverPermission = self.ServerPermissionCombo:GetSelected()
        local _, gmRank = self.GMRankCombo:GetSelected()
        local _, adminRank = self.AdminRankCombo:GetSelected()
        local _, promotionProfile = self.PromotionProfileCombo:GetSelected()
        local _, rankID = self.RPRankCombo:GetSelected()
        local _, department = self.RPDepartmentCombo:GetSelected()
        local _, activityLevel = self.RPActivityCombo:GetSelected()

        LeopardRP.Personnel.SavePermissionManagement({
            mode = "admin",
            steamID64 = self.PermissionSelectedSteamID64,
            characterID = self.PermissionSelectedCharacterID or "",
            serverPermission = tostring(serverPermission or "player"),
            gmRank = tostring(gmRank or "none"),
            adminRank = tostring(adminRank or "none"),
            promotionProfile = tostring(promotionProfile or "commander_plus"),
            trainingPermission = self.TrainingToggle:GetChecked() == true,
            roleplay = {
                rankID = tostring(rankID or ""),
                department = tostring(department or ""),
                activityLevel = tostring(activityLevel or ""),
                position = tostring(self.RPPositionEntry:GetValue() or "")
            }
        })
    end

    self.LogCategoryFilter = "all"
    self.LogSortMode = "newest"
    self.RawLogs = {}

    self.PersonnelPageButton.DoClick = function()
        self:SetPageMode("personnel")
    end

    self.LogPageButton.DoClick = function()
        self:SetPageMode("logs")
        self:RequestLogs()
    end

    self.PermissionPageButton.DoClick = function()
        self:SetPageMode("permissions")
        LeopardRP.Personnel.RequestDirectory("admin", self.PermissionDirectorySearch:GetValue() or "")
    end

    self.DevModePageButton.DoClick = function()
        self:SetPageMode("devmode")
        LeopardRP.Personnel.RequestDevModeSettings()
    end

    self:SetPageMode("personnel")
end

function PANEL:SetPageMode(mode)
    self.PageMode = mode or "personnel"
    local showLogs = self.PageMode == "logs"
    local showPermissions = self.PageMode == "permissions"
    local showDevMode = self.PageMode == "devmode"
    local showLogistics = self.PageMode == "logistics"

    self.LeftPanel:SetVisible(not showLogs and not showPermissions and not showDevMode and not showLogistics)
    self.CenterPanel:SetVisible(not showLogs and not showPermissions and not showDevMode and not showLogistics)
    self.RightPanel:SetVisible(not showLogs and not showPermissions and not showDevMode and not showLogistics)
    self.BottomBar:SetVisible(not showLogs and not showPermissions and not showDevMode and not showLogistics)
    self.LogPanel:SetVisible(showLogs)
    self.PermissionPanel:SetVisible(showPermissions)
    self.DevModePanel:SetVisible(showDevMode)
    self.LogisticsPanel:SetVisible(showLogistics)
end

function PANEL:OnLogisticsSettingsData(payload)
    if not istable(payload) then return end
    local settings = payload.settings or payload
    local canEdit = payload.canEdit ~= false

    self.LogisticsDropExcessAmmo:SetChecked(settings.dropExcessAmmo == true)
    self.LogisticsDropOnDeath:SetChecked(settings.dropOnDeath == true)
    self.LogisticsPickupFrame0:SetChecked(settings.pickupFrame0 == true)
    self.LogisticsPickupCompat:SetChecked(settings.pickupCompat == true)

    local pickupMode = tonumber(settings.pickupMode) or -1
    local selected = false
    for index, value in ipairs(self.LogisticsPickupModeCombo.Data or {}) do
        if tonumber(value) == pickupMode then
            self.LogisticsPickupModeCombo:ChooseOptionID(index)
            selected = true
            break
        end
    end
    if not selected then
        self.LogisticsPickupModeCombo:SetValue(tostring(pickupMode))
    end

    self.LogisticsDefaultSizeEntry:SetText(tostring(settings.defaultCaseSize or "s"))

    self.LogisticsDropExcessAmmo:SetEnabled(canEdit)
    self.LogisticsDropOnDeath:SetEnabled(canEdit)
    self.LogisticsPickupFrame0:SetEnabled(canEdit)
    self.LogisticsPickupCompat:SetEnabled(canEdit)
    self.LogisticsPickupModeCombo:SetEnabled(canEdit)
    self.LogisticsDefaultSizeEntry:SetEnabled(canEdit)
    self.LogisticsSaveButton:SetEnabled(canEdit)
    self.LogisticsItemSpawnerButton:SetEnabled(canEdit)
end

function PANEL:RefreshDevWhitelistList()
    self.DevWhitelistList:Clear()

    for _, steamID64 in ipairs(self.DevWhitelistSteamIds or {}) do
        local row = vgui.Create("DPanel", self.DevWhitelistList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(38)
        row.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(18, 24, 36, 198))
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(steamID64), "LeopardRP.Menu.Small", 10, h * 0.5, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local removeButton = vgui.Create("LeopardRPMenuButton", row)
        removeButton:Dock(RIGHT)
        removeButton:DockMargin(0, 4, 6, 4)
        removeButton:SetWide(90)
        removeButton:SetText("")
        removeButton:SetButtonText("Remove")
        removeButton:SetAccentColor(Color(255, 165, 145, 255))
        removeButton.DoClick = function()
            for index, value in ipairs(self.DevWhitelistSteamIds or {}) do
                if tostring(value) == tostring(steamID64) then
                    table.remove(self.DevWhitelistSteamIds, index)
                    break
                end
            end
            self:RefreshDevWhitelistList()
            self:RefreshDevWhitelistCandidateList()
        end
    end
end

function PANEL:RefreshDevWhitelistCandidateList()
    if not IsValid(self.DevWhitelistCandidatesList) then return end
    self.DevWhitelistCandidatesList:Clear()

    local whitelistedLookup = {}
    for _, steamID64 in ipairs(self.DevWhitelistSteamIds or {}) do
        whitelistedLookup[tostring(steamID64)] = true
    end

    for _, candidate in ipairs(self.DevWhitelistCandidates or {}) do
        local steamID64 = tostring(candidate.steamID64 or "")
        if steamID64 ~= "" and not whitelistedLookup[steamID64] then
            local row = vgui.Create("DPanel", self.DevWhitelistCandidatesList)
            row:Dock(TOP)
            row:DockMargin(8, 0, 8, 8)
            row:SetTall(58)
            row.Paint = function(_, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(18, 24, 36, 198))
                surface.SetDrawColor(255, 255, 255, 100)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                local leftTitle = tostring(candidate.steamName or "Unknown")
                if tostring(candidate.characterName or "") ~= "" then
                    leftTitle = leftTitle .. " | " .. tostring(candidate.characterName)
                end

                local status = candidate.online and "Online" or "Offline"
                local sourceText = tostring(candidate.source or "directory") == "denied_join" and "Denied Join" or "Character Record"
                local deniedCount = tonumber(candidate.deniedCount or 0) or 0
                if deniedCount > 0 then
                    sourceText = sourceText .. string.format(" (%dx)", deniedCount)
                end

                draw.SimpleText(leftTitle, "LeopardRP.Menu.Small", 10, 8, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(steamID64, "LeopardRP.Menu.Micro", 10, 30, Color(190, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(status .. " | " .. sourceText, "LeopardRP.Menu.Micro", w - 102, 30, candidate.online and Color(160, 230, 170) or Color(230, 170, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end

            local addButton = vgui.Create("LeopardRPMenuButton", row)
            addButton:Dock(RIGHT)
            addButton:DockMargin(0, 8, 6, 8)
            addButton:SetWide(96)
            addButton:SetText("")
            addButton:SetButtonText("Whitelist")
            addButton:SetAccentColor(Color(150, 210, 255, 255))
            addButton.DoClick = function()
                for _, existing in ipairs(self.DevWhitelistSteamIds or {}) do
                    if tostring(existing) == steamID64 then
                        return
                    end
                end

                table.insert(self.DevWhitelistSteamIds, steamID64)
                table.sort(self.DevWhitelistSteamIds)
                self:RefreshDevWhitelistList()
                self:RefreshDevWhitelistCandidateList()
            end
        end
    end
end

function PANEL:OnDevModeData(payload)
    if not istable(payload) then return end
    local canEdit = payload.canEdit ~= false

    self.DevWhitelistToggle:SetChecked(payload.whitelistEnabled == true)
    self.DevWhitelistSteamIds = table.Copy(payload.whitelistSteamIds or {})
    self.DevWhitelistCandidates = table.Copy(payload.whitelistCandidates or {})
    table.sort(self.DevWhitelistSteamIds)
    self:RefreshDevWhitelistList()
    self:RefreshDevWhitelistCandidateList()

    self.DevWhitelistToggle:SetEnabled(canEdit)
    self.DevWhitelistEntry:SetEnabled(canEdit)
    self.DevWhitelistAddButton:SetEnabled(canEdit)
    self.DevWhitelistSaveButton:SetEnabled(canEdit)
end

function PANEL:RenderPermissionDirectory(payload)
    self.PermissionDirectoryList:Clear()

    for _, playerEntry in ipairs(payload.players or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.PermissionDirectoryList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(62)
        row:SetText("")
        row:SetButtonText(tostring(playerEntry.steamName or "Unknown"))
        row.Paint = function(panel, w, h)
            local hovered = panel:IsHovered()
            local isSelected = tostring(self.PermissionSelectedSteamID64 or "") == tostring(playerEntry.steamID64 or "")
            draw.RoundedBox(12, 0, 0, w, h, isSelected and Color(36, 50, 74, 232) or (hovered and Color(28, 38, 56, 224) or Color(18, 24, 36, 198)))
            surface.SetDrawColor(255, 255, 255, isSelected and 180 or 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(tostring(playerEntry.steamName or "Unknown"), "LeopardRP.Menu.Small", 10, 10, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(playerEntry.characterName or ""), "LeopardRP.Menu.Micro", 10, 30, Color(205, 215, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(playerEntry.steamID64 or ""), "LeopardRP.Menu.Micro", w - 10, 10, Color(190, 200, 220), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(playerEntry.online and "Online" or "Offline", "LeopardRP.Menu.Micro", w - 10, 30, playerEntry.online and Color(160, 230, 170) or Color(230, 170, 170), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end
        row.DoClick = function()
            self.PermissionSelectedSteamID64 = tostring(playerEntry.steamID64 or "")
            self.PermissionSelectedCharacterID = ""
            LeopardRP.Personnel.RequestCharacterList("admin", self.PermissionSelectedSteamID64)
            LeopardRP.Personnel.RequestPermissionManagement("admin", self.PermissionSelectedSteamID64, "")
        end
    end
end

function PANEL:RenderPermissionCharacters(payload)
    self.PermissionCharacterList:Clear()

    for _, characterEntry in ipairs(payload.characters or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.PermissionCharacterList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(70)
        row:SetText("")
        row:SetButtonText(tostring(characterEntry.name or "Unnamed"))
        row.Paint = function(panel, w, h)
            local hovered = panel:IsHovered()
            local isSelected = tostring(self.PermissionSelectedCharacterID or "") == tostring(characterEntry.id or "")
            draw.RoundedBox(12, 0, 0, w, h, isSelected and Color(36, 50, 74, 232) or (hovered and Color(28, 38, 56, 224) or Color(18, 24, 36, 198)))
            surface.SetDrawColor(255, 255, 255, isSelected and 180 or 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(tostring(characterEntry.name or "Unnamed"), "LeopardRP.Menu.Small", 10, 10, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("%s | %s", tostring(characterEntry.rankName or ""), tostring(characterEntry.division or "")), "LeopardRP.Menu.Micro", 10, 30, Color(205, 215, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(characterEntry.id or ""), "LeopardRP.Menu.Micro", 10, 48, Color(180, 190, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        row.DoClick = function()
            self.PermissionSelectedCharacterID = tostring(characterEntry.id or "")
            LeopardRP.Personnel.RequestPermissionManagement("admin", self.PermissionSelectedSteamID64 or "", self.PermissionSelectedCharacterID)
        end
    end
end

function PANEL:OnDirectoryData(payload)
    if self.PageMode == "permissions" then
        self:RenderPermissionDirectory(payload or {})
        return
    end

    self.BaseClass.OnDirectoryData(self, payload)
end

function PANEL:OnCharacterListData(payload)
    if self.PageMode == "permissions" then
        self:RenderPermissionCharacters(payload or {})
        return
    end

    self.BaseClass.OnCharacterListData(self, payload)
end

function PANEL:OnPermissionManagementData(payload)
    if not istable(payload) then return end

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

    self.ServerPermissionCombo:Clear()
    self.GMRankCombo:Clear()
    self.AdminRankCombo:Clear()
    self.PromotionProfileCombo:Clear()
    self.RPRankCombo:Clear()
    self.RPDepartmentCombo:Clear()
    self.RPActivityCombo:Clear()

    for _, permissionEntry in ipairs(payload.serverPermissions or {}) do
        self.ServerPermissionCombo:AddChoice(tostring(permissionEntry.Name or permissionEntry.ID or "Player"), tostring(permissionEntry.ID or "player"))
    end

    for _, profileEntry in ipairs(payload.promotionProfiles or {}) do
        self.PromotionProfileCombo:AddChoice(tostring(profileEntry.Name or profileEntry.ID or "Commander+"), tostring(profileEntry.ID or "commander_plus"))
    end

    for _, gmEntry in ipairs(sortByWeightDescending(payload.gmRanks or {})) do
        self.GMRankCombo:AddChoice(tostring(gmEntry.Name or gmEntry.ID or "No GM Permissions"), tostring(gmEntry.ID or "none"))
    end

    for _, adminEntry in ipairs(sortByWeightDescending(payload.adminRanks or {})) do
        self.AdminRankCombo:AddChoice(tostring(adminEntry.Name or adminEntry.ID or "No Admin Permissions"), tostring(adminEntry.ID or "none"))
    end

    self.RPRankCombo:AddChoice("No Change", "")
    for _, rankEntry in ipairs(payload.ranks or {}) do
        self.RPRankCombo:AddChoice(tostring(rankEntry.Name or rankEntry.ID or "Rank"), tostring(rankEntry.ID or ""))
    end

    self.RPDepartmentCombo:AddChoice("No Change", "")
    for _, departmentName in ipairs(payload.departments or {}) do
        self.RPDepartmentCombo:AddChoice(tostring(departmentName), tostring(departmentName))
    end

    self.RPActivityCombo:AddChoice("No Change", "")
    for _, activityEntry in ipairs(payload.activityLevels or {}) do
        self.RPActivityCombo:AddChoice(tostring(activityEntry.label or activityEntry.id or ""), tostring(activityEntry.id or ""))
    end

    local function chooseComboByData(combo, wanted, fallbackText)
        wanted = tostring(wanted or "")
        for index, data in ipairs(combo.Data or {}) do
            if tostring(data) == wanted then
                combo:ChooseOptionID(index)
                return
            end
        end
        combo:SetValue(tostring(fallbackText or wanted))
    end

    local profile = payload.profile or {}
    chooseComboByData(self.ServerPermissionCombo, profile.serverPermission, "Player")
    chooseComboByData(self.GMRankCombo, payload.gmRank, "No GM Permissions")
    chooseComboByData(self.AdminRankCombo, payload.adminRank, "No Admin Permissions")
    chooseComboByData(self.PromotionProfileCombo, profile.promotionProfile, "Commander+")
    self.TrainingToggle:SetChecked(profile.trainingPermission == true)

    local character = payload.details and payload.details.character or {}
    chooseComboByData(self.RPRankCombo, character.rankID, "No Change")
    chooseComboByData(self.RPDepartmentCombo, character.division, "No Change")
    chooseComboByData(self.RPActivityCombo, character.activityLevel, "No Change")
    self.RPPositionEntry:SetText(tostring(character.position or ""))

    self.PermissionSummaryLabel:SetText(string.format(
        "SteamID: %s\nCharacter: %s\n\nServer Permission: %s\nGame Master Rank: %s\nAdministration Rank: %s\nPromotion Profile: %s\nTraining Access: %s\n\nRoleplay fields below only apply to the selected character.",
        tostring(payload.steamID64 or ""),
        tostring(character.name or "(none selected)"),
        tostring(profile.serverPermission or "player"),
        tostring(payload.gmRank or "none"),
        tostring(payload.adminRank or "none"),
        tostring(profile.promotionProfile or "commander_plus"),
        profile.trainingPermission and "Enabled" or "Disabled"
    ))

    self.PermissionSelectedSteamID64 = tostring(payload.steamID64 or self.PermissionSelectedSteamID64 or "")
    self.PermissionSelectedCharacterID = tostring(payload.characterID or self.PermissionSelectedCharacterID or "")
end

function PANEL:RequestLogs()
    LeopardRP.Personnel.RequestLogs(self.LogSearch:GetValue() or "", self.LogCategoryFilter or "all", self.LogSortMode or "newest")
end

function PANEL:OpenLogSortWindow()
    if IsValid(self.LogSortWindow) then
        self.LogSortWindow:Remove()
    end

    self.LogSortWindow = vgui.Create("DPanel", self.Root)
    self.LogSortWindow:SetSize(420, 200)
    self.LogSortWindow:SetPos((ScrW() - 420) * 0.5, (ScrH() - 200) * 0.5)
    self.LogSortWindow.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(12, 18, 28, 230))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("Logger Sort & Filter", "LeopardRP.Menu.PanelBold", 14, 10, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local categoryCombo = vgui.Create("DComboBox", self.LogSortWindow)
    categoryCombo:SetPos(14, 50)
    categoryCombo:SetSize(392, 28)
    LeopardRP.CharacterCreation.StyleComboBox(categoryCombo)
    categoryCombo:AddChoice("All", "all")
    for categoryName in pairs(self.LogCategoryChoices or {}) do
        categoryCombo:AddChoice(categoryName, string.lower(categoryName))
    end

    local selectedCategory = self.LogCategoryFilter or "all"
    categoryCombo:SetValue(selectedCategory == "all" and "All" or selectedCategory)

    local sortCombo = vgui.Create("DComboBox", self.LogSortWindow)
    sortCombo:SetPos(14, 92)
    sortCombo:SetSize(392, 28)
    LeopardRP.CharacterCreation.StyleComboBox(sortCombo)
    sortCombo:AddChoice("Newest First", "newest")
    sortCombo:AddChoice("Oldest First", "oldest")
    sortCombo:AddChoice("Category", "category")
    sortCombo:AddChoice("Actor", "actor")
    sortCombo:AddChoice("Target", "target")
    sortCombo:SetValue(self.LogSortMode or "newest")

    local applyButton = vgui.Create("LeopardRPMenuButton", self.LogSortWindow)
    applyButton:SetText("")
    applyButton:SetButtonText("Apply")
    applyButton:SetAccentColor(Color(145, 210, 255, 255))
    applyButton:SetSize(190, 32)
    applyButton:SetPos(14, 152)
    applyButton.DoClick = function()
        local _, categoryValue = categoryCombo:GetSelected()
        local _, sortValue = sortCombo:GetSelected()

        self.LogCategoryFilter = tostring(categoryValue or self.LogCategoryFilter or "all")
        self.LogSortMode = tostring(sortValue or self.LogSortMode or "newest")
        if IsValid(self.LogSortWindow) then
            self.LogSortWindow:Remove()
        end
        self:RequestLogs()
    end

    local cancelButton = vgui.Create("LeopardRPMenuButton", self.LogSortWindow)
    cancelButton:SetText("")
    cancelButton:SetButtonText("Cancel")
    cancelButton:SetSize(190, 32)
    cancelButton:SetPos(216, 152)
    cancelButton.DoClick = function()
        if IsValid(self.LogSortWindow) then
            self.LogSortWindow:Remove()
        end
    end
end

function PANEL:RenderLogs(logs)
    self.LogList:Clear()
    for _, logEntry in ipairs(logs or {}) do
        local row = vgui.Create("DPanel", self.LogList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(86)
        row.Paint = function(_, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(16, 24, 36, 188))
            surface.SetDrawColor(255, 255, 255, 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(string.format("[%s] %s", tostring(logEntry.category or "general"), os.date("%Y-%m-%d %H:%M:%S", tonumber(logEntry.timestamp) or 0)), "LeopardRP.Menu.Micro", 10, 8, Color(220, 230, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Actor: %s (%s) [%s]", tostring(logEntry.actorCharacterName or ""), tostring(logEntry.actorName or ""), tostring(logEntry.actorSteamID64 or "")), "LeopardRP.Menu.Micro", 10, 26, Color(210, 220, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Target: %s [%s]", tostring(logEntry.targetName or ""), tostring(logEntry.targetSteamID64 or "")), "LeopardRP.Menu.Micro", 10, 42, Color(205, 215, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(logEntry.message or ""), "LeopardRP.Menu.Micro", 10, 60, Color(190, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

function PANEL:OnLogsData(payload)
    if not istable(payload) then return end

    self.RawLogs = payload.logs or {}
    self.LogCategoryChoices = {}
    for _, logEntry in ipairs(self.RawLogs) do
        local category = tostring(logEntry.category or "general")
        self.LogCategoryChoices[category] = true
    end

    self:RenderLogs(self.RawLogs)
end

function PANEL:OnStaffRanksData(payload)
    if not istable(payload) then return end

    self.RankList:Clear()
    for _, rankEntry in ipairs(payload.ranks or {}) do
        local row = vgui.Create("DPanel", self.RankList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(70)
        row.Paint = function(_, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(16, 24, 36, 188))
            surface.SetDrawColor(255, 255, 255, 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(string.format("%s [%s]", tostring(rankEntry.steamName or "Unknown"), tostring(rankEntry.steamID64 or "")), "LeopardRP.Menu.Small", 10, 10, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("In-game group: %s", tostring(rankEntry.gameAdminGroup or "none")), "LeopardRP.Menu.Micro", 10, 34, Color(188, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local combo = vgui.Create("DComboBox", row)
        combo:SetPos(row:GetWide() - 210, 12)
        combo:SetSize(120, 28)
        combo:Dock(RIGHT)
        combo:DockMargin(0, 12, 8, 0)
        LeopardRP.CharacterCreation.StyleComboBox(combo)
        for _, permissionEntry in ipairs(LeopardRP.Personnel.ServerPermissionLevels or {}) do
            combo:AddChoice(tostring(permissionEntry.Name or permissionEntry.ID or "Player"), tostring(permissionEntry.ID or "player"))
        end
        combo:SetValue(tostring(rankEntry.staffRank or "player"))

        local applyButton = vgui.Create("LeopardRPMenuButton", row)
        applyButton:SetText("")
        applyButton:SetButtonText("Apply")
        applyButton:SetAccentColor(Color(145, 210, 255, 255))
        applyButton:Dock(RIGHT)
        applyButton:DockMargin(0, 12, 8, 8)
        applyButton:SetWide(74)
        applyButton.DoClick = function()
            local _, value = combo:GetSelected()
            LeopardRP.Personnel.SetStaffRank(tostring(rankEntry.steamID64 or ""), tostring(value or "player"))
            timer.Simple(0.1, function()
                if IsValid(self) then
                    LeopardRP.Personnel.RequestStaffRanks(self.RankSearch:GetValue() or "")
                end
            end)
        end
    end
end

function PANEL:PerformLayout(w, h)
    self.BaseClass.PerformLayout(self, w, h)

    self.PageSwitch:SetPos(20, 8)
    self.PageSwitch:SetSize(950, 32)

    self.PersonnelPageButton:SetPos(0, 0)
    self.PersonnelPageButton:SetSize(146, 32)

    self.LogPageButton:SetPos(154, 0)
    self.LogPageButton:SetSize(146, 32)

    self.PermissionPageButton:SetPos(308, 0)
    self.PermissionPageButton:SetSize(312, 32)

    self.DevModePageButton:SetPos(628, 0)
    self.DevModePageButton:SetSize(154, 32)

    self.ItemManagerButton:SetPos(790, 0)
    self.ItemManagerButton:SetSize(162, 32)

    local headerHeight = self.HeaderBar:GetTall()
    local contentTop = 24 + headerHeight + 16
    local contentBottom = 24

    self.LogPanel:SetPos(24, contentTop)
    self.LogPanel:SetSize(w - 48, h - contentTop - contentBottom)

    self.LogSearch:SetPos(12, 12)
    self.LogSearch:SetSize(math.max(220, self.LogPanel:GetWide() - 346), 32)

    self.LogSortWindowButton:SetPos(self.LogPanel:GetWide() - 314, 12)
    self.LogSortWindowButton:SetSize(146, 32)

    self.LogRefreshButton:SetPos(self.LogPanel:GetWide() - 160, 12)
    self.LogRefreshButton:SetSize(148, 32)

    self.LogList:SetPos(0, 54)
    self.LogList:SetSize(self.LogPanel:GetWide(), self.LogPanel:GetTall() - 58)

    self.PermissionPanel:SetPos(24, contentTop)
    self.PermissionPanel:SetSize(w - 48, h - contentTop - contentBottom)

    self.DevModePanel:SetPos(24, contentTop)
    self.DevModePanel:SetSize(w - 48, h - contentTop - contentBottom)

    self.LogisticsPanel:SetPos(24, contentTop)
    self.LogisticsPanel:SetSize(w - 48, h - contentTop - contentBottom)

    self.LogisticsTitle:SetPos(14, 12)
    self.LogisticsTitle:SizeToContents()
    self.LogisticsHint:SetPos(14, 36)
    self.LogisticsHint:SizeToContents()

    self.LogisticsDropExcessAmmo:SetPos(14, 70)
    self.LogisticsDropOnDeath:SetPos(14, 96)
    self.LogisticsPickupFrame0:SetPos(14, 122)
    self.LogisticsPickupCompat:SetPos(14, 148)

    self.LogisticsPickupModeLabel:SetPos(14, 184)
    self.LogisticsPickupModeLabel:SizeToContents()
    self.LogisticsPickupModeCombo:SetPos(14, 208)
    self.LogisticsPickupModeCombo:SetSize(360, 30)

    self.LogisticsDefaultSizeLabel:SetPos(14, 248)
    self.LogisticsDefaultSizeLabel:SizeToContents()
    self.LogisticsDefaultSizeEntry:SetPos(14, 272)
    self.LogisticsDefaultSizeEntry:SetSize(360, 30)

    self.LogisticsRefreshButton:SetPos(14, 320)
    self.LogisticsRefreshButton:SetSize(132, 32)
    self.LogisticsSaveButton:SetPos(154, 320)
    self.LogisticsSaveButton:SetSize(290, 32)

    self.LogisticsItemEditorButton:SetPos(14, 362)
    self.LogisticsItemEditorButton:SetSize(220, 32)

    self.LogisticsItemSpawnerButton:SetPos(242, 362)
    self.LogisticsItemSpawnerButton:SetSize(202, 32)

    self.DevWhitelistTitle:SetPos(14, 12)
    self.DevWhitelistTitle:SizeToContents()
    self.DevWhitelistToggle:SetPos(14, 42)
    self.DevWhitelistToggle:SizeToContents()
    self.DevWhitelistEntry:SetPos(14, 74)
    self.DevWhitelistEntry:SetSize(self.DevModePanel:GetWide() - 200, 32)
    self.DevWhitelistAddButton:SetPos(self.DevModePanel:GetWide() - 176, 74)
    self.DevWhitelistAddButton:SetSize(162, 32)
    self.DevWhitelistSaveButton:SetPos(14, 114)
    self.DevWhitelistSaveButton:SetSize(240, 32)
    local listStartY = 154
    local totalListHeight = self.DevModePanel:GetTall() - listStartY - 10
    local allowedListHeight = math.max(120, math.floor(totalListHeight * 0.45))
    local candidateListY = listStartY + allowedListHeight + 28
    local candidateListHeight = math.max(120, self.DevModePanel:GetTall() - candidateListY - 10)

    self.DevWhitelistList:SetPos(0, listStartY)
    self.DevWhitelistList:SetSize(self.DevModePanel:GetWide(), allowedListHeight)
    self.DevWhitelistCandidatesTitle:SetPos(14, listStartY + allowedListHeight + 2)
    self.DevWhitelistCandidatesTitle:SizeToContents()
    self.DevWhitelistCandidatesList:SetPos(0, candidateListY)
    self.DevWhitelistCandidatesList:SetSize(self.DevModePanel:GetWide(), candidateListHeight)

    local permW = self.PermissionPanel:GetWide()
    local permH = self.PermissionPanel:GetTall()
    local colGap = 12
    local leftW = math.floor(permW * 0.28)
    local centerW = math.floor(permW * 0.28)
    local rightW = permW - leftW - centerW - (colGap * 4)

    self.PermissionLeft:SetPos(colGap, 10)
    self.PermissionLeft:SetSize(leftW, permH - 20)
    self.PermissionCenter:SetPos(colGap * 2 + leftW, 10)
    self.PermissionCenter:SetSize(centerW, permH - 20)
    self.PermissionRight:SetPos(colGap * 3 + leftW + centerW, 10)
    self.PermissionRight:SetSize(rightW, permH - 20)

    self.PermissionDirectoryTitle:SetPos(14, 10)
    self.PermissionDirectoryTitle:SetSize(leftW - 24, 24)
    self.PermissionDirectorySearch:SetPos(14, 38)
    self.PermissionDirectorySearch:SetSize(leftW - 28, 30)
    self.PermissionDirectoryList:SetPos(0, 76)
    self.PermissionDirectoryList:SetSize(leftW, self.PermissionLeft:GetTall() - 84)

    self.PermissionCharacterTitle:SetPos(14, 10)
    self.PermissionCharacterTitle:SetSize(centerW - 24, 24)
    self.PermissionCharacterList:SetPos(0, 38)
    self.PermissionCharacterList:SetSize(centerW, self.PermissionCenter:GetTall() - 46)

    local rightInnerW = rightW - 28
    local y = 10
    self.PermissionSummaryTitle:SetPos(14, y)
    self.PermissionSummaryTitle:SetSize(rightInnerW, 24)
    y = y + 26
    self.PermissionSummaryLabel:SetPos(14, y)
    self.PermissionSummaryLabel:SetSize(rightInnerW, 1)
    self.PermissionSummaryLabel:SizeToContentsY()
    local summaryHeight = math.Clamp(self.PermissionSummaryLabel:GetTall(), 96, 170)
    self.PermissionSummaryLabel:SetSize(rightInnerW, summaryHeight)
    y = y + summaryHeight + 10

    local function placeField(label, control)
        label:SetPos(14, y)
        label:SetSize(rightInnerW, 20)
        y = y + 20
        control:SetPos(14, y)
        control:SetSize(rightInnerW, 28)
        y = y + 32
    end

    placeField(self.ServerPermissionLabel, self.ServerPermissionCombo)
    placeField(self.GMRankLabel, self.GMRankCombo)
    placeField(self.AdminRankLabel, self.AdminRankCombo)
    placeField(self.PromotionProfileLabel, self.PromotionProfileCombo)
    placeField(self.RPRankLabel, self.RPRankCombo)
    placeField(self.RPDepartmentLabel, self.RPDepartmentCombo)
    placeField(self.RPActivityLabel, self.RPActivityCombo)
    placeField(self.RPPositionLabel, self.RPPositionEntry)

    self.TrainingToggle:SetPos(14, y)
    self.TrainingToggle:SizeToContents()
    y = y + 28

    self.PermissionSave:SetPos(14, math.min(y, self.PermissionRight:GetTall() - 42))
    self.PermissionSave:SetSize(rightInnerW, 30)
end

vgui.Register("LeopardRPAdministrationPanel", PANEL, "LeopardRPPersonnelBasePanel")

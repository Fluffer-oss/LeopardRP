LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}

local Personnel = LeopardRP.Personnel
local PANEL = {}

local function BuildCaptainAndBelowRankChoices()
    local captainOrder = tonumber(LeopardRP.GetRankOrder and LeopardRP.GetRankOrder("captain") or 13) or 13
    local groupedRanks = {
        { label = "Enlisted", minOrder = 1, maxOrder = 7 },
        { label = "Junior Officers", minOrder = 8, maxOrder = 10 },
        { label = "Senior Officers", minOrder = 11, maxOrder = captainOrder }
    }

    local choiceEntries = {}
    local validChoiceIndexes = {}
    local rankList = LeopardRP.GetRankList and LeopardRP.GetRankList() or {}

    for _, group in ipairs(groupedRanks) do
        table.insert(choiceEntries, { label = "— " .. tostring(group.label or "Ranks") .. " —", value = "__divider__", divider = true })

        for _, rankData in ipairs(rankList) do
            local order = tonumber(rankData.Order) or 0
            if order >= (group.minOrder or 0) and order <= (group.maxOrder or 0) and order <= captainOrder then
                local display = tostring(rankData.Name or rankData.ID)
                table.insert(choiceEntries, { label = display, value = rankData.ID })
                table.insert(validChoiceIndexes, #choiceEntries)
            end
        end
    end

    return choiceEntries, validChoiceIndexes
end

PANEL.Mode = "crew"
PANEL.BackgroundPath = "ui/crewmanager"
PANEL.TitleText = "Crew Manager"
PANEL.SubtitleText = "Command Staff Personnel Supervision Terminal"

function PANEL:Init()
    self.BaseClass.Init(self)

    self.DirectoryTitle:SetText("Crew Roster")
    self.CharacterListTitle:SetText("Crew Member Characters")

    self.FiltersPanel = vgui.Create("DPanel", self.DirectoryCard)
    self.FiltersPanel:SetPos(16, 82)
    self.FiltersPanel:SetTall(62)
    self.FiltersPanel.Paint = function() end

    self.DepartmentFilter = vgui.Create("DTextEntry", self.FiltersPanel)
    self.DepartmentFilter:SetPos(0, 0)
    self.DepartmentFilter:SetSize(120, 26)
    self.DepartmentFilter:SetPlaceholderText("Department")
    LeopardRP.CharacterCreation.StyleTextEntry(self.DepartmentFilter)

    self.RankFilter = vgui.Create("DTextEntry", self.FiltersPanel)
    self.RankFilter:SetPos(126, 0)
    self.RankFilter:SetSize(90, 26)
    self.RankFilter:SetPlaceholderText("Rank")
    LeopardRP.CharacterCreation.StyleTextEntry(self.RankFilter)

    self.DutyFilter = vgui.Create("DTextEntry", self.FiltersPanel)
    self.DutyFilter:SetPos(0, 32)
    self.DutyFilter:SetSize(216, 26)
    self.DutyFilter:SetPlaceholderText("Active Duty / Away Mission / Reserve")
    LeopardRP.CharacterCreation.StyleTextEntry(self.DutyFilter)

    self.DirectoryList:SetPos(12, 152)
    self.DirectoryList:SetSize(self.DirectoryCard:GetWide() - 24, self.DirectoryCard:GetTall() - 162)

    self.DirectorySearch.OnTextChanged = function(entry)
        local query = string.Trim(entry:GetValue() or "")
        if #query < 2 and query ~= "" then return end
        LeopardRP.Personnel.RequestDirectory(self.Mode, query)
    end

    self.DirectorySearch:SetPlaceholderText("Search crew roster")

    self.PageSwitch = vgui.Create("DPanel", self.HeaderBar)
    self.PageSwitch:SetPaintBackground(false)

    self.PersonnelPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.PersonnelPageButton:SetText("")
    self.PersonnelPageButton:SetButtonText("Personnel")
    self.PersonnelPageButton:SetAccentColor(Color(140, 190, 255, 255))

    self.RosterPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.RosterPageButton:SetText("")
    self.RosterPageButton:SetButtonText("Personnel Roster")
    self.RosterPageButton:SetAccentColor(Color(150, 205, 255, 255))

    self.TrainingPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.TrainingPageButton:SetText("")
    self.TrainingPageButton:SetButtonText("Training Management")
    self.TrainingPageButton:SetAccentColor(Color(165, 220, 180, 255))

    self.SecondaryPageButton = vgui.Create("LeopardRPMenuButton", self.PageSwitch)
    self.SecondaryPageButton:SetText("")
    self.SecondaryPageButton:SetButtonText("Secondary Ranks")
    self.SecondaryPageButton:SetAccentColor(Color(165, 220, 255, 255))

    self.SecondaryPanel = vgui.Create("DPanel", self.Root)
    self.SecondaryPanel.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(12, 16, 24, 196))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.SecondaryPanel:SetVisible(false)

    self.SecondarySearch = vgui.Create("DTextEntry", self.SecondaryPanel)
    self.SecondarySearch:SetPlaceholderText("Search secondary ranks")
    LeopardRP.CharacterCreation.StyleTextEntry(self.SecondarySearch)
    self.SecondarySearch.OnEnter = function()
        self:RequestSecondaryRanks()
    end

    self.SecondaryRefresh = vgui.Create("LeopardRPMenuButton", self.SecondaryPanel)
    self.SecondaryRefresh:SetText("")
    self.SecondaryRefresh:SetButtonText("Refresh")
    self.SecondaryRefresh:SetAccentColor(Color(140, 190, 255, 255))
    self.SecondaryRefresh.DoClick = function()
        self:RequestSecondaryRanks()
    end

    self.SecondaryDefinitionList = vgui.Create("DScrollPanel", self.SecondaryPanel)
    self.SecondaryAssignedList = vgui.Create("DScrollPanel", self.SecondaryPanel)

    self.SecondaryNameEntry = vgui.Create("DTextEntry", self.SecondaryPanel)
    self.SecondaryNameEntry:SetPlaceholderText("Secondary rank name")
    LeopardRP.CharacterCreation.StyleTextEntry(self.SecondaryNameEntry)

    self.SecondaryDepartment = vgui.Create("DComboBox", self.SecondaryPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.SecondaryDepartment)
    for _, departmentName in ipairs({ "Command", "Engineering", "Operations", "Tactical", "Security", "Science", "Medical" }) do
        self.SecondaryDepartment:AddChoice(departmentName)
    end
    self.SecondaryDepartment:SetValue("Command")

    self.SecondaryDepartmentToggle = vgui.Create("DCheckBoxLabel", self.SecondaryPanel)
    self.SecondaryDepartmentToggle:SetText("Require Department Match")
    self.SecondaryDepartmentToggle:SetTextColor(Color(210, 220, 240))
    self.SecondaryDepartmentToggle:SetChecked(false)
    self.SecondaryDepartmentToggle:SizeToContents()

    self.SecondaryRankLimitToggle = vgui.Create("DCheckBoxLabel", self.SecondaryPanel)
    self.SecondaryRankLimitToggle:SetText("Require Rank Range")
    self.SecondaryRankLimitToggle:SetTextColor(Color(210, 220, 240))
    self.SecondaryRankLimitToggle:SetChecked(false)
    self.SecondaryRankLimitToggle:SizeToContents()
    self.SecondaryRankLimitToggle.OnChange = function(_, checked)
        if IsValid(self.SecondaryMinRank) then
            self.SecondaryMinRank:SetEnabled(checked)
            self.SecondaryMinRank:SetMouseInputEnabled(checked)
        end
        if IsValid(self.SecondaryMaxRank) then
            self.SecondaryMaxRank:SetEnabled(checked)
            self.SecondaryMaxRank:SetMouseInputEnabled(checked)
        end
    end

    self.SecondaryDepartmentToggle.OnChange = function(_, checked)
        if IsValid(self.SecondaryDepartment) then
            self.SecondaryDepartment:SetEnabled(checked)
            self.SecondaryDepartment:SetMouseInputEnabled(checked)
        end
    end

    self.SecondaryDepartmentToggle:OnChange(false)
    self.SecondaryRankLimitToggle:OnChange(false)

    self.SecondaryMinRank = vgui.Create("DComboBox", self.SecondaryPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.SecondaryMinRank)
    self.SecondaryMaxRank = vgui.Create("DComboBox", self.SecondaryPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.SecondaryMaxRank)

    self.RankIDByName = {}
    local rankChoices, validChoiceIndexes = BuildCaptainAndBelowRankChoices()

    local function PopulateRankCombo(combo)
        combo:Clear()
        combo._lastValidChoiceID = nil
        combo.OnSelect = function(panel, index, value, data)
            if data == "__divider__" then
                timer.Simple(0, function()
                    if IsValid(panel) then
                        panel:ChooseOptionID(panel._lastValidChoiceID or 1)
                    end
                end)
                return
            end

            panel._lastValidChoiceID = index
        end

        for index, entry in ipairs(rankChoices) do
            combo:AddChoice(entry.label, entry.value)
            if entry.value ~= "__divider__" then
                self.RankIDByName[entry.label] = entry.value
                combo._lastValidChoiceID = combo._lastValidChoiceID or index
            end
        end

        for _, choiceIndex in ipairs(validChoiceIndexes) do
            if not combo._firstValidChoiceID then
                combo._firstValidChoiceID = choiceIndex
            end
            combo._lastValidChoiceID = choiceIndex
        end
    end

    PopulateRankCombo(self.SecondaryMinRank)
    PopulateRankCombo(self.SecondaryMaxRank)

    if self.SecondaryMinRank._firstValidChoiceID then
        self.SecondaryMinRank:ChooseOptionID(self.SecondaryMinRank._firstValidChoiceID)
    end
    if self.SecondaryMaxRank._lastValidChoiceID then
        self.SecondaryMaxRank:ChooseOptionID(self.SecondaryMaxRank._lastValidChoiceID)
    end

    self.SecondaryCreateButton = vgui.Create("LeopardRPMenuButton", self.SecondaryPanel)
    self.SecondaryCreateButton:SetText("")
    self.SecondaryCreateButton:SetButtonText("Create Secondary Rank")
    self.SecondaryCreateButton:SetAccentColor(Color(145, 220, 180, 255))
    self.SecondaryCreateButton.DoClick = function()
        local minLabel = self.SecondaryMinRank:GetValue() or ""
        local maxLabel = self.SecondaryMaxRank:GetValue() or ""
        LeopardRP.Personnel.CreateSecondaryRank({
            mode = self.Mode,
            steamID64 = self.SelectedSteamID64 or "",
            characterID = self.SelectedCharacterID or "",
            search = self.SecondarySearch:GetValue() or "",
            name = string.Trim(self.SecondaryNameEntry:GetValue() or ""),
            department = string.Trim(self.SecondaryDepartment:GetValue() or ""),
            minRankID = self.RankIDByName[minLabel] or minLabel,
            maxRankID = self.RankIDByName[maxLabel] or maxLabel,
            enforceDepartment = self.SecondaryDepartmentToggle:GetChecked() == true,
            enforceRankLimits = self.SecondaryRankLimitToggle:GetChecked() == true
        })
    end

    self.PersonnelPageButton.DoClick = function()
        if self.TrainingOnlyMode then return end
        self:SetPageMode("personnel")
    end

    self.SecondaryPageButton.DoClick = function()
        if self.TrainingOnlyMode then return end
        self:SetPageMode("secondary")
        self:RequestSecondaryRanks()
    end

    self.RosterPageButton.DoClick = function()
        if self.TrainingOnlyMode then return end
        self:SetPageMode("roster")
        self:RequestRoster()
    end

    self.TrainingPageButton.DoClick = function()
        self:SetPageMode("training")
        self:RequestTrainingManagement()
    end

    self:BuildRosterPage()
    self:BuildTrainingPage()
    self:SetPageMode("personnel")
end

function PANEL:SetTrainingOnlyMode(enabled)
    self.TrainingOnlyMode = enabled == true

    if not IsValid(self.PersonnelPageButton) then return end
    if not IsValid(self.RosterPageButton) then return end
    if not IsValid(self.SecondaryPageButton) then return end

    if self.TrainingOnlyMode then
        self.PersonnelPageButton:SetVisible(false)
        self.RosterPageButton:SetVisible(false)
        self.SecondaryPageButton:SetVisible(false)
        self.TrainingPageButton:SetPos(0, 0)
        self.TrainingPageButton:SetSize(math.max(220, self.PageSwitch:GetWide()), 32)
        self:SetPageMode("training")
    else
        self.PersonnelPageButton:SetVisible(true)
        self.RosterPageButton:SetVisible(true)
        self.SecondaryPageButton:SetVisible(true)
    end
end

function PANEL:BuildRosterPage()
    self.RosterPanel = vgui.Create("DPanel", self.Root)
    self.RosterPanel.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(12, 16, 24, 196))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.RosterPanel:SetVisible(false)

    self.RosterSearch = vgui.Create("DTextEntry", self.RosterPanel)
    self.RosterSearch:SetPlaceholderText("Search character name, steam name, species, rank, position, department, activity")
    LeopardRP.CharacterCreation.StyleTextEntry(self.RosterSearch)
    self.RosterSearch.OnTextChanged = function(entry)
        self:RequestRoster(entry:GetValue() or "")
    end

    self.RosterDepartmentFilter = vgui.Create("DComboBox", self.RosterPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.RosterDepartmentFilter)
    self.RosterDepartmentFilter:AddChoice("All Departments", "")
    for _, divisionName in ipairs({ "Command", "Operations", "Sciences", "Cadet", "Admiral" }) do
        self.RosterDepartmentFilter:AddChoice(divisionName, divisionName)
    end
    self.RosterDepartmentFilter:ChooseOptionID(1)
    self.RosterDepartmentFilter.OnSelect = function()
        self:RequestRoster()
    end

    self.RosterRankFilter = vgui.Create("DTextEntry", self.RosterPanel)
    self.RosterRankFilter:SetPlaceholderText("Rank filter")
    LeopardRP.CharacterCreation.StyleTextEntry(self.RosterRankFilter)
    self.RosterRankFilter.OnEnter = function()
        self:RequestRoster()
    end

    self.RosterActivityFilter = vgui.Create("DComboBox", self.RosterPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.RosterActivityFilter)
    self.RosterActivityFilter:AddChoice("All Activity", "")
    for _, activityData in ipairs(LeopardRP.Personnel.ActivityLevels or {}) do
        self.RosterActivityFilter:AddChoice(activityData.Name or activityData.ID or "", activityData.ID)
    end
    self.RosterActivityFilter:ChooseOptionID(1)
    self.RosterActivityFilter.OnSelect = function()
        self:RequestRoster()
    end

    self.RosterSort = vgui.Create("DComboBox", self.RosterPanel)
    LeopardRP.CharacterCreation.StyleComboBox(self.RosterSort)
    for _, sortOption in ipairs({
        { label = "Rank", value = "rank" },
        { label = "Character Name", value = "name" },
        { label = "Position", value = "position" },
        { label = "Department", value = "department" },
        { label = "Last Active", value = "lastactive" },
        { label = "Last Joined", value = "lastjoined" },
        { label = "Activity Level", value = "activity" },
        { label = "Promotion Date", value = "promotiondate" },
        { label = "Demotion Date", value = "demotiondate" }
    }) do
        self.RosterSort:AddChoice(sortOption.label, sortOption.value)
    end
    self.RosterSort:ChooseOptionID(1)
    self.RosterSort.OnSelect = function()
        self:RequestRoster()
    end

    self.RosterSortDirection = vgui.Create("LeopardRPMenuButton", self.RosterPanel)
    self.RosterSortDirection:SetText("")
    self.RosterSortDirection:SetButtonText("Descending")
    self.RosterSortDirection:SetAccentColor(Color(140, 190, 255, 255))
    self.RosterSortDirection.SortDirection = "desc"
    self.RosterSortDirection.DoClick = function(button)
        button.SortDirection = button.SortDirection == "desc" and "asc" or "desc"
        button:SetButtonText(button.SortDirection == "desc" and "Descending" or "Ascending")
        self:RequestRoster()
    end

    self.RosterRefresh = vgui.Create("LeopardRPMenuButton", self.RosterPanel)
    self.RosterRefresh:SetText("")
    self.RosterRefresh:SetButtonText("Refresh")
    self.RosterRefresh:SetAccentColor(Color(165, 220, 180, 255))
    self.RosterRefresh.DoClick = function()
        self:RequestRoster()
    end

    self.RosterHeader = vgui.Create("DPanel", self.RosterPanel)
    self.RosterHeader.Paint = function(_, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(18, 26, 40, 220))
        surface.SetDrawColor(255, 255, 255, 110)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local columns = self.RosterColumns or {}
        local x = 12
        for _, column in ipairs(columns) do
            draw.SimpleText(column.label or "", "LeopardRP.Menu.Micro", x, 10, Color(230, 235, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            x = x + (column.width or 100)
        end
    end

    self.RosterList = vgui.Create("DScrollPanel", self.RosterPanel)

    self.RosterInfo = vgui.Create("DPanel", self.RosterPanel)
    self.RosterInfo.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(16, 22, 34, 208))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local selected = self.SelectedRosterEntry or {}
        draw.SimpleText(tostring(selected.characterName or "No character selected"), "LeopardRP.Menu.PanelBold", 14, 12, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Rank: %s | Position: %s", tostring(selected.rankName or ""), tostring(selected.position or "")), "LeopardRP.Menu.Small", 14, 42, Color(220, 230, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Department: %s | Species: %s", tostring(selected.department or ""), tostring(selected.species or "")), "LeopardRP.Menu.Small", 14, 64, Color(220, 230, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Activity: %s", tostring(selected.activityLabel or "")), "LeopardRP.Menu.Small", 14, 86, Color(220, 230, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(string.format("Training: %d completed", tonumber(selected.trainingSummary and selected.trainingSummary.completed) or 0), "LeopardRP.Menu.Small", 14, 108, Color(220, 230, 245), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    self.RosterActivitySelect = vgui.Create("DComboBox", self.RosterInfo)
    LeopardRP.CharacterCreation.StyleComboBox(self.RosterActivitySelect)
    for _, activityData in ipairs(LeopardRP.Personnel.ActivityLevels or {}) do
        self.RosterActivitySelect:AddChoice(activityData.Name or activityData.ID or "", activityData.ID)
    end
    self.RosterActivitySelect:SetValue("Active Duty")

    self.RosterPositionEntry = vgui.Create("DTextEntry", self.RosterInfo)
    self.RosterPositionEntry:SetPlaceholderText("Position / assignment")
    LeopardRP.CharacterCreation.StyleTextEntry(self.RosterPositionEntry)

    self.RosterTrainingCourse = vgui.Create("DComboBox", self.RosterInfo)
    LeopardRP.CharacterCreation.StyleComboBox(self.RosterTrainingCourse)
    self.RosterTrainingCourse:AddChoice("Select training course", "")
    for _, departmentCourses in pairs(LeopardRP.Personnel.TrainingCatalog or {}) do
        for _, courseData in ipairs(departmentCourses or {}) do
            self.RosterTrainingCourse:AddChoice(courseData.Name or courseData.ID or "", courseData.ID)
        end
    end
    self.RosterTrainingCourse:ChooseOptionID(1)

    self.RosterViewDossier = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterViewDossier:SetText("")
    self.RosterViewDossier:SetButtonText("View Personnel Dossier")
    self.RosterViewDossier:SetAccentColor(Color(150, 205, 255, 255))
    self.RosterViewDossier.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        Personnel.RequestCharacterDetails(self.Mode, self.SelectedSteamID64, self.SelectedCharacterID)
        self:SetPageMode("personnel")
    end

    self.RosterPromote = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterPromote:SetText("")
    self.RosterPromote:SetButtonText("Promote")
    self.RosterPromote:SetAccentColor(Color(120, 185, 255, 255))
    self.RosterPromote.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "promote" })
    end

    self.RosterDemote = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterDemote:SetText("")
    self.RosterDemote:SetButtonText("Demote")
    self.RosterDemote:SetAccentColor(Color(255, 180, 110, 255))
    self.RosterDemote.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "demote" })
    end

    self.RosterAssignPosition = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterAssignPosition:SetText("")
    self.RosterAssignPosition:SetButtonText("Assign Position")
    self.RosterAssignPosition:SetAccentColor(Color(145, 220, 180, 255))
    self.RosterAssignPosition.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "assign_position", fields = { position = self.RosterPositionEntry:GetValue() or "" } })
    end

    self.RosterTransferDepartment = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterTransferDepartment:SetText("")
    self.RosterTransferDepartment:SetButtonText("Transfer Department")
    self.RosterTransferDepartment:SetAccentColor(Color(170, 220, 255, 255))
    self.RosterTransferDepartment.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "transfer_division", fields = { division = self.RosterDepartmentFilter:GetSelected() and select(2, self.RosterDepartmentFilter:GetSelected()) or self.RosterDepartmentFilter:GetValue() or "" } })
    end

    self.RosterChangeActivity = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterChangeActivity:SetText("")
    self.RosterChangeActivity:SetButtonText("Change Activity")
    self.RosterChangeActivity:SetAccentColor(Color(180, 215, 255, 255))
    self.RosterChangeActivity.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        local _, activityID = self.RosterActivitySelect:GetSelected()
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "change_activity", fields = { activityLevel = activityID or self.RosterActivitySelect:GetValue() or "active_duty" } })
    end

    self.RosterAddTraining = vgui.Create("LeopardRPMenuButton", self.RosterInfo)
    self.RosterAddTraining:SetText("")
    self.RosterAddTraining:SetButtonText("Add Training")
    self.RosterAddTraining:SetAccentColor(Color(165, 220, 180, 255))
    self.RosterAddTraining.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
        local _, trainingID = self.RosterTrainingCourse:GetSelected()
        local trainingName = self.RosterTrainingCourse:GetValue() or ""
        Personnel.SubmitAction({ mode = self.Mode, steamID64 = self.SelectedSteamID64, characterID = self.SelectedCharacterID, action = "add_training", trainingID = trainingID or "", trainingName = trainingName, fields = { trainingName = trainingName, status = "Not Started" } })
    end
end

function PANEL:BuildTrainingPage()
    self.TrainingPanel = vgui.Create("DPanel", self.Root)
    self.TrainingPanel.Paint = function(_, w, h)
        draw.RoundedBox(18, 0, 0, w, h, Color(12, 16, 24, 196))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    self.TrainingPanel:SetVisible(false)

    self.TrainingSearch = vgui.Create("DTextEntry", self.TrainingPanel)
    self.TrainingSearch:SetPlaceholderText("Search crew member or training")
    LeopardRP.CharacterCreation.StyleTextEntry(self.TrainingSearch)
    self.TrainingSearch.OnTextChanged = function(entry)
        self:RequestTrainingManagement(entry:GetValue() or "")
    end

    self.TrainingRefresh = vgui.Create("LeopardRPMenuButton", self.TrainingPanel)
    self.TrainingRefresh:SetText("")
    self.TrainingRefresh:SetButtonText("Refresh")
    self.TrainingRefresh:SetAccentColor(Color(145, 220, 180, 255))
    self.TrainingRefresh.DoClick = function()
        self:RequestTrainingManagement()
    end

    self.TrainingRosterList = vgui.Create("DScrollPanel", self.TrainingPanel)
    self.TrainingAssignedList = vgui.Create("DScrollPanel", self.TrainingPanel)
    self.TrainingAvailableList = vgui.Create("DScrollPanel", self.TrainingPanel)

    self.TrainingRosterLabel = vgui.Create("DLabel", self.TrainingPanel)
    self.TrainingRosterLabel:SetFont("LeopardRP.Menu.Small")
    self.TrainingRosterLabel:SetTextColor(Color(235, 240, 250))
    self.TrainingRosterLabel:SetText("Online Crew")

    self.TrainingAssignedLabel = vgui.Create("DLabel", self.TrainingPanel)
    self.TrainingAssignedLabel:SetFont("LeopardRP.Menu.Small")
    self.TrainingAssignedLabel:SetTextColor(Color(235, 240, 250))
    self.TrainingAssignedLabel:SetText("Assigned Training")

    self.TrainingAvailableLabel = vgui.Create("DLabel", self.TrainingPanel)
    self.TrainingAvailableLabel:SetFont("LeopardRP.Menu.Small")
    self.TrainingAvailableLabel:SetTextColor(Color(235, 240, 250))
    self.TrainingAvailableLabel:SetText("Available Courses")

    self.TrainingActionBar = vgui.Create("DPanel", self.TrainingPanel)
    self.TrainingActionBar.Paint = function(_, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(16, 22, 34, 210))
        surface.SetDrawColor(255, 255, 255, 110)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    self.TrainingInstructorEntry = vgui.Create("DTextEntry", self.TrainingActionBar)
    self.TrainingInstructorEntry:SetPlaceholderText("Instructor / notes / due date")
    LeopardRP.CharacterCreation.StyleTextEntry(self.TrainingInstructorEntry)

    local function MakeTrainingButton(label, colorOverride, actionName)
        local button = vgui.Create("LeopardRPMenuButton", self.TrainingActionBar)
        button:SetText("")
        button:SetButtonText(label)
        button:SetAccentColor(colorOverride)
        button.DoClick = function()
            if not self.SelectedSteamID64 or not self.SelectedCharacterID or not self.SelectedTrainingCourse then return end
            Personnel.SubmitAction({
                mode = self.Mode,
                steamID64 = self.SelectedSteamID64,
                characterID = self.SelectedCharacterID,
                action = actionName,
                trainingID = self.SelectedTrainingCourse.id,
                trainingName = self.SelectedTrainingCourse.name,
                fields = {
                    trainingName = self.SelectedTrainingCourse.name,
                    instructor = self.TrainingInstructorEntry:GetValue() or "",
                    notes = self.TrainingInstructorEntry:GetValue() or ""
                }
            })
        end
        return button
    end

    self.TrainingAssignButton = MakeTrainingButton("Assign Training", Color(145, 220, 180, 255), "add_training")
    self.TrainingRecordCompletedButton = vgui.Create("LeopardRPMenuButton", self.TrainingActionBar)
    self.TrainingRecordCompletedButton:SetText("")
    self.TrainingRecordCompletedButton:SetButtonText("Record Completed")
    self.TrainingRecordCompletedButton:SetAccentColor(Color(120, 240, 170, 255))
    self.TrainingRecordCompletedButton.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID or not self.SelectedTrainingCourse then return end
        Personnel.SubmitAction({
            mode = self.Mode,
            steamID64 = self.SelectedSteamID64,
            characterID = self.SelectedCharacterID,
            action = "add_training",
            trainingID = self.SelectedTrainingCourse.id,
            trainingName = self.SelectedTrainingCourse.name,
            fields = {
                trainingName = self.SelectedTrainingCourse.name,
                status = "Completed",
                completionDate = os.time(),
                completionStardate = LeopardRP.Util and LeopardRP.Util.GetStardate and tostring(LeopardRP.Util:GetStardate(os.time())) or tostring(os.time()),
                instructor = self.TrainingInstructorEntry:GetValue() or "",
                notes = self.TrainingInstructorEntry:GetValue() or ""
            }
        })
    end
    self.TrainingInstructorButton = MakeTrainingButton("Assign Instructor", Color(150, 205, 255, 255), "assign_instructor")
    self.TrainingCompleteButton = MakeTrainingButton("Mark Complete", Color(120, 240, 170, 255), "complete_training")
    self.TrainingFailedButton = MakeTrainingButton("Mark Failed", Color(230, 100, 100, 255), "fail_training")
    self.TrainingRemoveButton = MakeTrainingButton("Remove Certification", Color(255, 180, 110, 255), "remove_training")

    self.TrainingNotesButton = vgui.Create("LeopardRPMenuButton", self.TrainingActionBar)
    self.TrainingNotesButton:SetText("")
    self.TrainingNotesButton:SetButtonText("Add Notes")
    self.TrainingNotesButton:SetAccentColor(Color(165, 220, 180, 255))
    self.TrainingNotesButton.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID or not self.SelectedTrainingCourse then return end
        Personnel.SubmitAction({
            mode = self.Mode,
            steamID64 = self.SelectedSteamID64,
            characterID = self.SelectedCharacterID,
            action = "add_training_notes",
            trainingID = self.SelectedTrainingCourse.id,
            trainingName = self.SelectedTrainingCourse.name,
            fields = { notes = self.TrainingInstructorEntry:GetValue() or "" }
        })
    end
end

function PANEL:SetPageMode(mode)
    if self.TrainingOnlyMode then
        mode = "training"
    end

    self.PageMode = mode or "personnel"
    local showPersonnel = self.PageMode == "personnel"
    local showRoster = self.PageMode == "roster"
    local showTraining = self.PageMode == "training"
    local showSecondary = self.PageMode == "secondary"

    self.LeftPanel:SetVisible(showPersonnel)
    self.CenterPanel:SetVisible(showPersonnel)
    self.RightPanel:SetVisible(showPersonnel)
    self.BottomBar:SetVisible(showPersonnel)
    if IsValid(self.RosterPanel) then
        self.RosterPanel:SetVisible(showRoster)
    end
    if IsValid(self.TrainingPanel) then
        self.TrainingPanel:SetVisible(showTraining)
    end
    self.SecondaryPanel:SetVisible(showSecondary)
end

function PANEL:RequestRoster(searchText)
    local departmentValue = self.RosterDepartmentFilter and ({ self.RosterDepartmentFilter:GetSelected() })[2] or ""
    local rankValue = self.RosterRankFilter and self.RosterRankFilter:GetValue() or ""
    local activityValue = self.RosterActivityFilter and ({ self.RosterActivityFilter:GetSelected() })[2] or ""
    local sortKey = self.RosterSort and ({ self.RosterSort:GetSelected() })[2] or "rank"
    local sortDirection = IsValid(self.RosterSortDirection) and (self.RosterSortDirection.SortDirection or "desc") or "desc"

    LeopardRP.Personnel.RequestRoster(self.Mode, searchText or (self.RosterSearch and self.RosterSearch:GetValue() or ""), {
        department = departmentValue or "",
        rank = rankValue or "",
        activity = activityValue or ""
    }, sortKey or "rank", sortDirection)
end

function PANEL:RequestTrainingManagement(searchText)
    LeopardRP.Personnel.RequestTrainingManagement(self.Mode, self.SelectedSteamID64 or "", self.SelectedCharacterID or "", searchText or (self.TrainingSearch and self.TrainingSearch:GetValue() or ""))
end

function PANEL:SelectRosterEntry(entry)
    if not istable(entry) then return end

    self.SelectedRosterEntry = entry
    self.SelectedSteamID64 = tostring(entry.steamID64 or "")
    self.SelectedCharacterID = tostring(entry.characterID or "")
    if self.RosterActivitySelect and entry.activityLevel then
        self.RosterActivitySelect:SetValue(tostring(entry.activityLabel or entry.activityLevel or "Active Duty"))
    end
    if self.RosterPositionEntry then
        self.RosterPositionEntry:SetText(tostring(entry.position or ""))
    end
    if self.RosterTrainingCourse then
        self.RosterTrainingCourse:SetValue("Select training course")
    end
    if self.PageMode == "training" then
        self:RequestTrainingManagement()
    end
end

function PANEL:OnRosterData(payload)
    if not istable(payload) then return end

    self.RosterRows = payload.roster or {}
    self.RosterColumns = {
        { label = "Rank", width = 112 },
        { label = "Position", width = 142 },
        { label = "Character Name", width = 180 },
        { label = "Species", width = 108 },
        { label = "Department", width = 128 },
        { label = "Last Active", width = 150 },
        { label = "Last Joined", width = 150 },
        { label = "Activity", width = 132 },
        { label = "Promotion", width = 130 },
        { label = "Demotion", width = 130 },
        { label = "Training", width = 110 }
    }

    if not IsValid(self.RosterList) then return end
    self.RosterList:Clear()

    local groupedRows = {}
    for _, entry in ipairs(self.RosterRows or {}) do
        local departmentName = tostring(entry.department or "General")
        groupedRows[departmentName] = groupedRows[departmentName] or {}
        table.insert(groupedRows[departmentName], entry)
    end

    local departmentOrder = { "Command", "Operations", "Sciences", "Medical", "Security", "Engineering", "General" }

    local function addDepartmentHeader(departmentName)
        local header = vgui.Create("DPanel", self.RosterList)
        header:Dock(TOP)
        header:DockMargin(8, 0, 8, 6)
        header:SetTall(28)
        header.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(24, 34, 50, 230))
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(departmentName or "General"), "LeopardRP.Menu.Small", 12, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    local renderedDepartments = {}
    for _, departmentName in ipairs(departmentOrder) do
        local entries = groupedRows[departmentName]
        renderedDepartments[departmentName] = true
        addDepartmentHeader(departmentName)
        if istable(entries) and #entries > 0 then
            for _, entry in ipairs(entries) do
                local row = vgui.Create("DButton", self.RosterList)
                row:Dock(TOP)
                row:DockMargin(8, 0, 8, 8)
                row:SetTall(48)
                row:SetText("")
                row.LastClick = 0
                row.Paint = function(panel, w, h)
                    local selected = self.SelectedRosterEntry and tostring(self.SelectedRosterEntry.characterID or "") == tostring(entry.characterID or "")
                    local hovered = panel:IsHovered()
                    local baseColor = selected and Color(36, 50, 74, 232) or (hovered and Color(28, 38, 56, 224) or Color(18, 24, 36, 198))
                    draw.RoundedBox(12, 0, 0, w, h, baseColor)
                    surface.SetDrawColor(255, 255, 255, selected and 180 or 110)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)

                    local x = 12
                    local labels = {
                        tostring(entry.rankName or ""),
                        tostring(entry.position or ""),
                        tostring(entry.characterName or ""),
                        tostring(entry.species or ""),
                        tostring(entry.department or ""),
                        os.date("%Y-%m-%d", tonumber(entry.lastActive) or 0),
                        os.date("%Y-%m-%d", tonumber(entry.lastJoined) or 0),
                        tostring(entry.activityLabel or ""),
                        os.date("%Y-%m-%d", tonumber(entry.promotionDate) or 0),
                        os.date("%Y-%m-%d", tonumber(entry.demotionDate) or 0),
                        string.format("%d", tonumber(entry.trainingSummary and entry.trainingSummary.completed) or 0)
                    }

                    for index, column in ipairs(self.RosterColumns or {}) do
                        draw.SimpleText(labels[index] or "", "LeopardRP.Menu.Micro", x, 14, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        x = x + (column.width or 100)
                    end
                end
                row.OnMousePressed = function(panel, mouseCode)
                    if mouseCode ~= MOUSE_LEFT then return end

                    local now = CurTime()
                    if now - (panel.LastClick or 0) < 0.28 then
                        self.SelectedRosterEntry = entry
                        self.SelectedSteamID64 = tostring(entry.steamID64 or "")
                        self.SelectedCharacterID = tostring(entry.characterID or "")
                        Personnel.RequestCharacterDetails(self.Mode, self.SelectedSteamID64, self.SelectedCharacterID)
                        self:SetPageMode("personnel")
                    else
                        self:SelectRosterEntry(entry)
                        self.SelectedRosterEntry = entry
                    end
                    panel.LastClick = now
                end
            end
        else
            local emptyRow = vgui.Create("DPanel", self.RosterList)
            emptyRow:Dock(TOP)
            emptyRow:DockMargin(18, 0, 8, 8)
            emptyRow:SetTall(28)
            emptyRow.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(16, 24, 36, 150))
                draw.SimpleText("No personnel in this department.", "LeopardRP.Menu.Micro", 10, 7, Color(190, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
    end

    for departmentName, entries in SortedPairs(groupedRows) do
        if not renderedDepartments[departmentName] and istable(entries) and #entries > 0 then
            addDepartmentHeader(departmentName)
            for _, entry in ipairs(entries) do
                local row = vgui.Create("DButton", self.RosterList)
                row:Dock(TOP)
                row:DockMargin(8, 0, 8, 8)
                row:SetTall(48)
                row:SetText("")
                row.LastClick = 0
                row.Paint = function(panel, w, h)
                    local selected = self.SelectedRosterEntry and tostring(self.SelectedRosterEntry.characterID or "") == tostring(entry.characterID or "")
                    local hovered = panel:IsHovered()
                    local baseColor = selected and Color(36, 50, 74, 232) or (hovered and Color(28, 38, 56, 224) or Color(18, 24, 36, 198))
                    draw.RoundedBox(12, 0, 0, w, h, baseColor)
                    surface.SetDrawColor(255, 255, 255, selected and 180 or 110)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)

                    local x = 12
                    local labels = {
                        tostring(entry.rankName or ""),
                        tostring(entry.position or ""),
                        tostring(entry.characterName or ""),
                        tostring(entry.species or ""),
                        tostring(entry.department or ""),
                        os.date("%Y-%m-%d", tonumber(entry.lastActive) or 0),
                        os.date("%Y-%m-%d", tonumber(entry.lastJoined) or 0),
                        tostring(entry.activityLabel or ""),
                        os.date("%Y-%m-%d", tonumber(entry.promotionDate) or 0),
                        os.date("%Y-%m-%d", tonumber(entry.demotionDate) or 0),
                        string.format("%d", tonumber(entry.trainingSummary and entry.trainingSummary.completed) or 0)
                    }

                    for index, column in ipairs(self.RosterColumns or {}) do
                        draw.SimpleText(labels[index] or "", "LeopardRP.Menu.Micro", x, 14, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        x = x + (column.width or 100)
                    end
                end
                row.OnMousePressed = function(panel, mouseCode)
                    if mouseCode ~= MOUSE_LEFT then return end

                    local now = CurTime()
                    if now - (panel.LastClick or 0) < 0.28 then
                        self.SelectedRosterEntry = entry
                        self.SelectedSteamID64 = tostring(entry.steamID64 or "")
                        self.SelectedCharacterID = tostring(entry.characterID or "")
                        Personnel.RequestCharacterDetails(self.Mode, self.SelectedSteamID64, self.SelectedCharacterID)
                        self:SetPageMode("personnel")
                    else
                        self:SelectRosterEntry(entry)
                        self.SelectedRosterEntry = entry
                    end
                    panel.LastClick = now
                end
            end
        end
    end

    if IsValid(self.RosterInfo) then
        self.RosterInfo:SetMouseInputEnabled(true)
    end
end

function PANEL:OnTrainingData(payload)
    if not istable(payload) then return end

    self.TrainingData = payload
    self.SelectedTrainingCourse = self.SelectedTrainingCourse or nil
    self.SelectedTrainingRecord = nil

    if not IsValid(self.TrainingRosterList) then return end

    self.TrainingRosterList:Clear()
    local rosterHeader = vgui.Create("DPanel", self.TrainingRosterList)
    rosterHeader:Dock(TOP)
    rosterHeader:DockMargin(8, 0, 8, 8)
    rosterHeader:SetTall(28)
    rosterHeader.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(24, 34, 50, 220))
        draw.SimpleText("Crew Members", "LeopardRP.Menu.Small", 12, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    if not istable(payload.roster) or #payload.roster == 0 then
        local empty = vgui.Create("DPanel", self.TrainingRosterList)
        empty:Dock(TOP)
        empty:DockMargin(8, 0, 8, 8)
        empty:SetTall(30)
        empty.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(16, 24, 36, 160))
            draw.SimpleText("No online crew available.", "LeopardRP.Menu.Micro", 10, 8, Color(190, 200, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    for _, entry in ipairs(payload.roster or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.TrainingRosterList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(62)
        row:SetText("")
        row:SetButtonText(string.format("%s | %s", tostring(entry.characterName or "Unnamed"), tostring(entry.rankName or "")))
        row.DoClick = function()
            self:SelectRosterEntry(entry)
            self:RequestTrainingManagement()
            self.TrainingRosterLabel:SetText(string.format("Online Crew - Selected: %s", tostring(entry.characterName or "Unknown")))
        end
    end

    self.TrainingAssignedList:Clear()
    local assignedHeader = vgui.Create("DPanel", self.TrainingAssignedList)
    assignedHeader:Dock(TOP)
    assignedHeader:DockMargin(8, 0, 8, 8)
    assignedHeader:SetTall(28)
    assignedHeader.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(24, 34, 50, 220))
        draw.SimpleText("Assigned Training", "LeopardRP.Menu.Small", 12, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    local trainingRecords = payload.training and payload.training.records or {}
    for _, record in ipairs(trainingRecords or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.TrainingAssignedList)
        row:Dock(TOP)
        row:DockMargin(8, 0, 8, 8)
        row:SetTall(60)
        row:SetText("")
        row:SetButtonText(string.format("%s - %s", tostring(record.name or ""), tostring(record.status or "Unknown")))
        row.DoClick = function()
            self.SelectedTrainingCourse = {
                id = tostring(record.id or record.name or ""),
                name = tostring(record.name or "")
            }
            self.SelectedTrainingRecord = record
        end
    end

    self.TrainingAvailableList:Clear()
    local catalogHeader = vgui.Create("DPanel", self.TrainingAvailableList)
    catalogHeader:Dock(TOP)
    catalogHeader:DockMargin(8, 0, 8, 8)
    catalogHeader:SetTall(28)
    catalogHeader.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(24, 34, 50, 220))
        draw.SimpleText("Course Catalog", "LeopardRP.Menu.Small", 12, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    for departmentName, courses in pairs(payload.catalog or {}) do
        local header = vgui.Create("DPanel", self.TrainingAvailableList)
        header:Dock(TOP)
        header:DockMargin(8, 0, 8, 6)
        header:SetTall(28)
        header.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(24, 34, 50, 220))
            draw.SimpleText(tostring(departmentName or "General"), "LeopardRP.Menu.Small", 12, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        for _, courseData in ipairs(courses or {}) do
            local row = vgui.Create("LeopardRPMenuButton", self.TrainingAvailableList)
            row:Dock(TOP)
            row:DockMargin(8, 0, 8, 8)
            row:SetTall(48)
            row:SetText("")
            row:SetButtonText(tostring(courseData.name or courseData.id or "Training Course"))
            row.DoClick = function()
                self.SelectedTrainingCourse = {
                    id = tostring(courseData.id or ""),
                    name = tostring(courseData.name or ""),
                    department = tostring(courseData.department or departmentName or "General")
                }
                self.SelectedTrainingRecord = nil
            end
        end
    end
end

function PANEL:RequestSecondaryRanks()
    LeopardRP.Personnel.RequestSecondaryRanks(self.Mode, self.SelectedSteamID64 or "", self.SelectedCharacterID or "", self.SecondarySearch:GetValue() or "")
end

function PANEL:OnCharacterDetailsData(payload)
    self.BaseClass.OnCharacterDetailsData(self, payload)
    if self.PageMode == "secondary" then
        self:RequestSecondaryRanks()
    elseif self.PageMode == "roster" then
        self:RequestRoster()
    elseif self.PageMode == "training" then
        self:RequestTrainingManagement()
    end
end

function PANEL:OnSecondaryRanksData(payload)
    if not istable(payload) then return end

    self.SecondaryDefinitionList:Clear()
    self.SecondaryAssignedList:Clear()

    local groupedDefinitions = {}
    for _, definition in ipairs(payload.definitions or {}) do
        local departmentName = tostring(definition.department or "General")
        groupedDefinitions[departmentName] = groupedDefinitions[departmentName] or {}
        table.insert(groupedDefinitions[departmentName], definition)
    end

    for departmentName, definitions in SortedPairs(groupedDefinitions) do
        local section = vgui.Create("DPanel", self.SecondaryDefinitionList)
        section:Dock(TOP)
        section:DockMargin(8, 0, 8, 8)
        section:SetTall(36)
        section.Paint = function(_, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(22, 32, 48, 228))
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(departmentName, "LeopardRP.Menu.Small", 10, 8, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        for _, definition in ipairs(definitions or {}) do
            local row = vgui.Create("DPanel", self.SecondaryDefinitionList)
            row:Dock(TOP)
            row:DockMargin(18, 0, 8, 8)
            row:SetTall(78)
            row.Paint = function(_, w, h)
                draw.RoundedBox(12, 0, 0, w, h, Color(16, 24, 36, 188))
                surface.SetDrawColor(255, 255, 255, 90)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(tostring(definition.name or ""), "LeopardRP.Menu.Small", 10, 8, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(string.format("Dept: %s | Rank: %s -> %s", tostring(definition.department or ""), tostring(definition.minRankName or ""), tostring(definition.maxRankName or "")), "LeopardRP.Menu.Micro", 10, 30, Color(190, 205, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local assignButton = vgui.Create("LeopardRPMenuButton", row)
            assignButton:SetText("")
            assignButton:SetButtonText("Assign")
            assignButton:SetAccentColor(Color(145, 220, 180, 255))
            assignButton:SetSize(90, 26)
            assignButton:SetPos(10, 46)
            assignButton:SetEnabled((self.SelectedSteamID64 or "") ~= "" and (self.SelectedCharacterID or "") ~= "")
            assignButton.DoClick = function()
                if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
                LeopardRP.Personnel.SetCharacterSecondaryRank({
                    mode = self.Mode,
                    steamID64 = self.SelectedSteamID64,
                    characterID = self.SelectedCharacterID,
                    secondaryRankID = tonumber(definition.id) or 0,
                    operation = "assign",
                    search = self.SecondarySearch:GetValue() or ""
                })
            end
        end
    end

    local groupedAssignments = {}
    for _, assignment in ipairs(payload.assignments or {}) do
        local departmentName = tostring(assignment.department or "General")
        groupedAssignments[departmentName] = groupedAssignments[departmentName] or {}
        table.insert(groupedAssignments[departmentName], assignment)
    end

    for departmentName, assignments in SortedPairs(groupedAssignments) do
        local section = vgui.Create("DPanel", self.SecondaryAssignedList)
        section:Dock(TOP)
        section:DockMargin(8, 0, 8, 8)
        section:SetTall(30)
        section.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(22, 32, 48, 228))
            surface.SetDrawColor(255, 255, 255, 100)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(departmentName, "LeopardRP.Menu.Small", 10, 6, Color(235, 240, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        for _, assignment in ipairs(assignments or {}) do
            local row = vgui.Create("DPanel", self.SecondaryAssignedList)
            row:Dock(TOP)
            row:DockMargin(18, 0, 8, 8)
            row:SetTall(62)
            row.Paint = function(_, w, h)
                draw.RoundedBox(12, 0, 0, w, h, Color(16, 24, 36, 188))
                surface.SetDrawColor(255, 255, 255, 90)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(tostring(assignment.name or ""), "LeopardRP.Menu.Small", 10, 8, Color(225, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(string.format("Dept: %s", tostring(assignment.department or "")), "LeopardRP.Menu.Micro", 10, 30, Color(190, 205, 225), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local removeButton = vgui.Create("LeopardRPMenuButton", row)
            removeButton:SetText("")
            removeButton:SetButtonText("Remove")
            removeButton:SetAccentColor(Color(230, 100, 100, 255))
            removeButton:SetSize(90, 26)
            removeButton:SetPos(10, 34)
            removeButton.DoClick = function()
                if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end
                LeopardRP.Personnel.SetCharacterSecondaryRank({
                    mode = self.Mode,
                    steamID64 = self.SelectedSteamID64,
                    characterID = self.SelectedCharacterID,
                    secondaryRankID = tonumber(assignment.id) or 0,
                    operation = "remove",
                    search = self.SecondarySearch:GetValue() or ""
                })
            end
        end
    end
end

function PANEL:PerformLayout(w, h)
    self.BaseClass.PerformLayout(self, w, h)

    if IsValid(self.FiltersPanel) then
        self.FiltersPanel:SetWide(self.DirectoryCard:GetWide() - 32)
    end

    if IsValid(self.DirectoryList) then
        self.DirectoryList:SetSize(self.DirectoryCard:GetWide() - 24, self.DirectoryCard:GetTall() - 162)
    end

    if IsValid(self.PageSwitch) then
        self.PageSwitch:SetPos(20, 8)
        if self.TrainingOnlyMode then
            self.PageSwitch:SetSize(220, 32)
            self.TrainingPageButton:SetPos(0, 0)
            self.TrainingPageButton:SetSize(220, 32)
        else
            self.PageSwitch:SetSize(646, 32)
            self.PersonnelPageButton:SetPos(0, 0)
            self.PersonnelPageButton:SetSize(150, 32)
            self.RosterPageButton:SetPos(160, 0)
            self.RosterPageButton:SetSize(150, 32)
            self.TrainingPageButton:SetPos(320, 0)
            self.TrainingPageButton:SetSize(172, 32)
            self.SecondaryPageButton:SetPos(502, 0)
            self.SecondaryPageButton:SetSize(144, 32)
        end
    end

    local headerHeight = self.HeaderBar:GetTall()
    local contentTop = 24 + headerHeight + 16
    local contentBottom = 24
    if IsValid(self.SecondaryPanel) then
        self.SecondaryPanel:SetPos(24, contentTop)
        self.SecondaryPanel:SetSize(w - 48, h - contentTop - contentBottom)

        self.SecondarySearch:SetPos(12, 12)
        self.SecondarySearch:SetSize(math.max(200, self.SecondaryPanel:GetWide() - 184), 32)
        self.SecondaryRefresh:SetPos(self.SecondaryPanel:GetWide() - 160, 12)
        self.SecondaryRefresh:SetSize(148, 32)

        local leftW = math.floor((self.SecondaryPanel:GetWide() - 36) * 0.56)
        local rightW = self.SecondaryPanel:GetWide() - leftW - 24

        self.SecondaryDefinitionList:SetPos(0, 54)
        self.SecondaryDefinitionList:SetSize(leftW, self.SecondaryPanel:GetTall() - 58)

        self.SecondaryAssignedList:SetPos(leftW + 12, 54)
        self.SecondaryAssignedList:SetSize(rightW, math.floor((self.SecondaryPanel:GetTall() - 86) * 0.52))

        local formY = self.SecondaryAssignedList:GetY() + self.SecondaryAssignedList:GetTall() + 10
        self.SecondaryNameEntry:SetPos(leftW + 12, formY)
        self.SecondaryNameEntry:SetSize(rightW, 28)
        self.SecondaryDepartment:SetPos(leftW + 12, formY + 34)
        self.SecondaryDepartment:SetSize(rightW, 28)
        self.SecondaryDepartmentToggle:SetPos(leftW + 12, formY + 66)
        self.SecondaryDepartmentToggle:SizeToContents()
        self.SecondaryRankLimitToggle:SetPos(leftW + 12 + math.floor(rightW * 0.5), formY + 66)
        self.SecondaryRankLimitToggle:SizeToContents()

        self.SecondaryMinRank:SetPos(leftW + 12, formY + 92)
        self.SecondaryMinRank:SetSize(math.floor((rightW - 8) * 0.5), 28)
        self.SecondaryMaxRank:SetPos(leftW + 12 + math.floor((rightW - 8) * 0.5) + 8, formY + 92)
        self.SecondaryMaxRank:SetSize(rightW - math.floor((rightW - 8) * 0.5) - 8, 28)
        self.SecondaryCreateButton:SetPos(leftW + 12, formY + 126)
        self.SecondaryCreateButton:SetSize(rightW, 30)
    end

    if IsValid(self.RosterPanel) then
        self.RosterPanel:SetPos(24, contentTop)
        self.RosterPanel:SetSize(w - 48, h - contentTop - contentBottom)

        self.RosterSearch:SetPos(12, 12)
        self.RosterSearch:SetSize(math.max(240, self.RosterPanel:GetWide() * 0.42), 32)
        self.RosterDepartmentFilter:SetPos(12, 52)
        self.RosterDepartmentFilter:SetSize(152, 28)
        self.RosterRankFilter:SetPos(172, 52)
        self.RosterRankFilter:SetSize(120, 28)
        self.RosterActivityFilter:SetPos(300, 52)
        self.RosterActivityFilter:SetSize(148, 28)
        self.RosterSort:SetPos(456, 52)
        self.RosterSort:SetSize(164, 28)
        self.RosterSortDirection:SetPos(628, 52)
        self.RosterSortDirection:SetSize(132, 28)
        self.RosterRefresh:SetPos(self.RosterPanel:GetWide() - 152, 12)
        self.RosterRefresh:SetSize(140, 32)

        local infoW = math.max(320, math.floor(self.RosterPanel:GetWide() * 0.34))
        local listW = self.RosterPanel:GetWide() - infoW - 24
        self.RosterHeader:SetPos(12, 92)
        self.RosterHeader:SetSize(listW, 34)
        self.RosterList:SetPos(12, 128)
        self.RosterList:SetSize(listW, self.RosterPanel:GetTall() - 140)

        self.RosterInfo:SetPos(listW + 20, 92)
        self.RosterInfo:SetSize(infoW - 12, self.RosterPanel:GetTall() - 140)

        self.RosterActivitySelect:SetPos(14, 136)
        self.RosterActivitySelect:SetSize(infoW - 40, 28)
        self.RosterPositionEntry:SetPos(14, 172)
        self.RosterPositionEntry:SetSize(infoW - 40, 28)
        self.RosterTrainingCourse:SetPos(14, 208)
        self.RosterTrainingCourse:SetSize(infoW - 40, 28)

        local buttonY = 252
        local buttonW = math.floor((infoW - 36) * 0.5)
        self.RosterViewDossier:SetPos(14, buttonY)
        self.RosterViewDossier:SetSize(infoW - 40, 30)
        self.RosterPromote:SetPos(14, buttonY + 38)
        self.RosterPromote:SetSize(buttonW, 30)
        self.RosterDemote:SetPos(22 + buttonW, buttonY + 38)
        self.RosterDemote:SetSize(buttonW, 30)
        self.RosterAssignPosition:SetPos(14, buttonY + 76)
        self.RosterAssignPosition:SetSize(infoW - 40, 30)
        self.RosterTransferDepartment:SetPos(14, buttonY + 114)
        self.RosterTransferDepartment:SetSize(infoW - 40, 30)
        self.RosterChangeActivity:SetPos(14, buttonY + 152)
        self.RosterChangeActivity:SetSize(infoW - 40, 30)
        self.RosterAddTraining:SetPos(14, buttonY + 190)
        self.RosterAddTraining:SetSize(infoW - 40, 30)
    end

    if IsValid(self.TrainingPanel) then
        self.TrainingPanel:SetPos(24, contentTop)
        self.TrainingPanel:SetSize(w - 48, h - contentTop - contentBottom)

        self.TrainingSearch:SetPos(12, 12)
        self.TrainingSearch:SetSize(math.max(240, self.TrainingPanel:GetWide() * 0.45), 32)
        self.TrainingRefresh:SetPos(self.TrainingPanel:GetWide() - 152, 12)
        self.TrainingRefresh:SetSize(140, 32)

        local colW = math.floor((self.TrainingPanel:GetWide() - 36) / 3)
        self.TrainingRosterList:SetPos(12, 54)
        self.TrainingRosterList:SetSize(colW, self.TrainingPanel:GetTall() - 164)
        self.TrainingAssignedList:SetPos(24 + colW, 54)
        self.TrainingAssignedList:SetSize(colW, self.TrainingPanel:GetTall() - 164)
        self.TrainingAvailableList:SetPos(36 + colW * 2, 54)
        self.TrainingAvailableList:SetSize(self.TrainingPanel:GetWide() - (36 + colW * 2), self.TrainingPanel:GetTall() - 164)

        self.TrainingActionBar:SetPos(12, self.TrainingPanel:GetTall() - 100)
        self.TrainingActionBar:SetSize(self.TrainingPanel:GetWide() - 24, 88)
        self.TrainingInstructorEntry:SetPos(12, 8)
        self.TrainingInstructorEntry:SetSize(math.max(240, math.floor(self.TrainingActionBar:GetWide() * 0.23)), 30)

        local x = self.TrainingInstructorEntry:GetX() + self.TrainingInstructorEntry:GetWide() + 10
        local buttonOrder = {
            self.TrainingAssignButton,
            self.TrainingRecordCompletedButton,
            self.TrainingInstructorButton,
            self.TrainingCompleteButton,
            self.TrainingFailedButton,
            self.TrainingRemoveButton,
            self.TrainingNotesButton
        }

        local availableWidth = self.TrainingActionBar:GetWide() - x - 12
        local columns = 4
        local buttonWidth = math.max(138, math.floor((availableWidth - 18) / columns))
        local buttonHeight = 30
        for index, button in ipairs(buttonOrder) do
            local rowIndex = math.floor((index - 1) / columns)
            local columnIndex = (index - 1) % columns
            button:SetPos(x + (columnIndex * (buttonWidth + 6)), 8 + (rowIndex * (buttonHeight + 8)))
            button:SetSize(buttonWidth, buttonHeight)
        end
    end
end

vgui.Register("LeopardRPCrewManager", PANEL, "LeopardRPPersonnelBasePanel")

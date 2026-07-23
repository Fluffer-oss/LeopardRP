LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Personnel = LeopardRP.Personnel
local Theme = LeopardRP.CharacterCreation.Theme or {}

local PANEL = {}

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

local function ResolveMaterial(path)
    local candidates = { path, path .. ".png", "ui/MainMenuScreen.png" }
    for _, candidate in ipairs(candidates) do
        local mat = Material(candidate, "smooth mips")
        if mat and not mat:IsError() then
            return mat
        end
    end

    return Material("vgui/white")
end

local function StylePanel(panel, radius)
    panel.Paint = function(_, w, h)
        draw.RoundedBox(radius or 18, 0, 0, w, h, Color(12, 16, 24, 196))
        surface.SetDrawColor(255, 255, 255, 120)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

local function CreateHeaderLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:SetFont("LeopardRP.Menu.PanelBold")
    label:SetTextColor(Color(255, 255, 255))
    label:SetText(text or "")
    return label
end

local function CreateSubLabel(parent, text)
    local label = vgui.Create("DLabel", parent)
    label:SetFont("LeopardRP.Menu.Small")
    label:SetTextColor(Color(220, 220, 220, 240))
    label:SetText(text or "")
    return label
end

local function CreateTextEntry(parent)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetTall(34)
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.StyleTextEntry then
        LeopardRP.CharacterCreation.StyleTextEntry(entry)
    end

    return entry
end

local function CreateComboBox(parent)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetTall(34)
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.StyleComboBox then
        LeopardRP.CharacterCreation.StyleComboBox(combo)
    end

    return combo
end

local function CreateActionButton(parent, text, colorOverride)
    local button = vgui.Create("LeopardRPMenuButton", parent)
    button:SetText("")
    button:SetButtonText(text)
    if colorOverride and button.SetAccentColor then
        button:SetAccentColor(colorOverride)
    end
    return button
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
    self:MakePopup()
    SetMenuInteractionEnabled(true)

    self.Mode = self.Mode or "crew"
    self.BackgroundMaterial = ResolveMaterial(self.BackgroundPath or "ui/crewmanager")

    self.Root = vgui.Create("EditablePanel", self)
    self.Root:Dock(FILL)
    self.Root.Paint = function(_, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.BackgroundMaterial)
        surface.DrawTexturedRect(0, 0, w, h)
        surface.SetDrawColor(4, 6, 10, 140)
        surface.DrawRect(0, 0, w, h)
    end

    self.HeaderBar = vgui.Create("DPanel", self.Root)
    self.HeaderBar:SetTall(math.max(88, ScrH() * 0.1))
    self.HeaderBar:Dock(TOP)
    self.HeaderBar:DockMargin(24, 24, 24, 16)
    StylePanel(self.HeaderBar, 20)

    self.TitleLabel = CreateHeaderLabel(self.HeaderBar, self.TitleText or "Personnel Terminal")
    self.SubtitleLabel = CreateSubLabel(self.HeaderBar, self.SubtitleText or "")

    self.BackButton = CreateActionButton(self.HeaderBar, "Back")
    self.BackButton.DoClick = function()
        Personnel.CloseActivePanel()
    end

    self.LeftPanel = vgui.Create("DPanel", self.Root)
    self.LeftPanel.Paint = function() end

    self.CenterPanel = vgui.Create("DPanel", self.Root)
    self.CenterPanel.Paint = function() end

    self.RightPanel = vgui.Create("DPanel", self.Root)
    self.RightPanel.Paint = function() end

    self.BottomBar = vgui.Create("DPanel", self.Root)
    self.BottomBar:SetTall(math.max(92, ScrH() * 0.1))
    self.BottomBar:Dock(BOTTOM)
    self.BottomBar:DockMargin(24, 10, 24, 24)
    StylePanel(self.BottomBar, 20)

    self.DirectoryCard = vgui.Create("DPanel", self.LeftPanel)
    self.DirectoryCard:Dock(FILL)
    StylePanel(self.DirectoryCard, 18)

    self.CharacterListCard = vgui.Create("DPanel", self.CenterPanel)
    self.CharacterListCard:Dock(FILL)
    StylePanel(self.CharacterListCard, 18)

    self.DetailsCard = vgui.Create("DPanel", self.RightPanel)
    self.DetailsCard:Dock(FILL)
    StylePanel(self.DetailsCard, 18)

    self.DirectoryTitle = CreateHeaderLabel(self.DirectoryCard, "Player Directory")
    self.DirectoryTitle:SetPos(16, 12)
    self.DirectoryTitle:SetSize(320, 26)

    self.DirectorySearch = CreateTextEntry(self.DirectoryCard)
    self.DirectorySearch:SetPos(16, 44)
    self.DirectorySearch:SetWide(260)
    self.DirectorySearch:SetPlaceholderText("Search SteamID, Steam Name, Character")
    self.DirectorySearch.OnEnter = function(entry)
        Personnel.RequestDirectory(self.Mode, entry:GetValue() or "")
    end

    self.DirectoryList = vgui.Create("DScrollPanel", self.DirectoryCard)
    self.DirectoryList:SetPos(12, 86)

    self.CharacterListTitle = CreateHeaderLabel(self.CharacterListCard, "Character List")
    self.CharacterListTitle:SetPos(16, 12)
    self.CharacterListTitle:SetSize(220, 26)

    self.CharacterList = vgui.Create("DScrollPanel", self.CharacterListCard)
    self.CharacterList:SetPos(12, 48)

    self.DetailsTitle = CreateHeaderLabel(self.DetailsCard, "Personnel Record")
    self.DetailsTitle:SetPos(16, 12)
    self.DetailsTitle:SetSize(280, 26)

    self.Preview = vgui.Create("LeopardRPCharacterPreview", self.DetailsCard)
    self.Preview:SetPos(16, 46)

    self.DetailsScroll = vgui.Create("DScrollPanel", self.DetailsCard)

    self.Fields = {}
    self.FieldMeta = {}
    local fieldDefs = {
        { key = "name", label = "Character Name", type = "text", editable = true },
        { key = "authCode", label = "Authorization Code", type = "text", editable = false },
        { key = "clearanceWord", label = "Clearance Level", type = "combo", editable = true, options = { "Auto", "Alpha", "Beta", "Gamma", "Delta", "Omega", "Sigma", "Theta", "Kappa" } },
        { key = "personnelNumber", label = "Personnel ID", type = "text", editable = false },
        { key = "serviceNumber", label = "Service Number", type = "text", editable = false },
        { key = "species", label = "Species", type = "text", editable = true },
        { key = "gender", label = "Gender", type = "combo", editable = true, options = { "Male", "Female" } },
        { key = "age", label = "Age", type = "text", editable = true },
        { key = "rankName", label = "Rank", type = "text", editable = false },
        { key = "division", label = "Division", type = "combo", editable = true, options = LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.Divisions or { "Cadet", "Operations", "Sciences", "Command", "Admiral" } },
        { key = "uniformType", label = "Uniform", type = "combo", editable = true, options = LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.UniformTypes or { "Standard", "Dress" } },
        { key = "assignment", label = "Assignment", type = "text", editable = true },
        { key = "creationDate", label = "Creation Date", type = "text", editable = false },
        { key = "creationStardate", label = "Creation Stardate", type = "text", editable = false },
        { key = "steamID64", label = "SteamID", type = "text", editable = false },
        { key = "lastLogin", label = "Last Login", type = "text", editable = false },
        { key = "status", label = "Current Status", type = "combo", editable = false, options = { "Active", "Deleted", "Event" } }
    }

    local cursorY = 4
    for _, def in ipairs(fieldDefs) do
        local row = vgui.Create("DPanel", self.DetailsScroll)
        row:SetPos(0, cursorY)
        row:SetSize(380, 56)
        row.Paint = function(_, w, h)
            draw.RoundedBox(12, 0, 0, w, h, Color(16, 24, 36, 175))
            surface.SetDrawColor(255, 255, 255, 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local label = CreateSubLabel(row, def.label)
        label:SetPos(12, 6)
        label:SetSize(350, 18)

        local control
        if def.type == "combo" then
            control = CreateComboBox(row)
            control:SetPos(12, 24)
            control:SetSize(356, 26)
            for _, option in ipairs(def.options or {}) do
                control:AddChoice(tostring(option))
            end
        else
            control = CreateTextEntry(row)
            control:SetPos(12, 24)
            control:SetSize(356, 26)
        end

        if not def.editable or (def.key == "clearanceWord" and self.Mode ~= "admin") then
            control:SetEnabled(false)
            control:SetMouseInputEnabled(false)
        end

        self.Fields[def.key] = control
        self.FieldMeta[def.key] = def
        cursorY = cursorY + 62
    end

    self.DossierCard = vgui.Create("DPanel", self.DetailsCard)
    StylePanel(self.DossierCard, 14)

    self.DossierTitle = CreateHeaderLabel(self.DossierCard, "Personnel Dossier")
    self.DossierTitle:SetPos(10, 8)
    self.DossierTitle:SetSize(260, 22)

    self.DossierCategory = CreateComboBox(self.DossierCard)
    self.DossierCategory:SetPos(10, 32)
    self.DossierCategory:SetSize(150, 26)
    for _, categoryName in ipairs({ "Service Notes", "Awards", "Commendations", "Disciplinary Actions", "Psychological Notes", "Medical Restrictions", "Promotions", "Demotions", "Transfer History", "Assignment History" }) do
        self.DossierCategory:AddChoice(categoryName)
    end
    self.DossierCategory:ChooseOption("Service Notes", 1)

    self.DossierInput = CreateTextEntry(self.DossierCard)
    self.DossierInput:SetPos(166, 32)
    self.DossierInput:SetSize(188, 26)
    self.DossierInput:SetPlaceholderText("Entry text")

    self.DossierAdd = CreateActionButton(self.DossierCard, "Add Dossier Entry", Theme.Accent)
    self.DossierAdd:SetPos(10, 62)
    self.DossierAdd:SetSize(344, 28)

    self.DossierList = vgui.Create("DScrollPanel", self.DossierCard)
    self.DossierList:SetPos(10, 94)
    self.DossierList:SetSize(344, 248)

    self.Actions = {}
    self.ActionOrder = {}

    self.SelectedSteamID64 = nil
    self.SelectedCharacterID = nil
    self.CurrentDetails = nil

    self.DossierAdd.DoClick = function()
        if not self.SelectedSteamID64 or not self.SelectedCharacterID then return end

        local textValue = string.Trim(self.DossierInput:GetValue() or "")
        if textValue == "" then return end

        Personnel.AddDossierEntry({
            mode = self.Mode,
            steamID64 = self.SelectedSteamID64,
            characterID = self.SelectedCharacterID,
            category = string.Trim(self.DossierCategory:GetValue() or "Service Notes"),
            text = textValue
        })

        self.DossierInput:SetText("")
    end

    self:BuildActionBar()
    Personnel.RequestDirectory(self.Mode, "")
end

function PANEL:RegisterAction(actionID, buttonText, accentColor)
    local button = CreateActionButton(self.BottomBar, buttonText, accentColor)
    button.DoClick = function()
        self:PerformAction(actionID)
    end

    self.Actions[actionID] = button
    table.insert(self.ActionOrder, actionID)
end

function PANEL:BuildActionBar()
    self:RegisterAction("save_changes", "Save Changes", Theme.Accent)
    self:RegisterAction("promote", "Promote", Color(120, 185, 255, 255))
    self:RegisterAction("demote", "Demote", Color(255, 180, 110, 255))
    self:RegisterAction("transfer_division", "Transfer Division", Color(145, 220, 180, 255))
    self:RegisterAction("edit_character", "Edit Character", Theme.Accent)

    if self.Mode == "admin" then
        self:RegisterAction("delete_character", "Delete Character", Color(230, 100, 100, 255))
        self:RegisterAction("restore_character", "Restore Character", Color(165, 230, 170, 255))
        self:RegisterAction("delete_player_data", "Delete Player Data", Color(255, 90, 90, 255))
    end
end

function PANEL:CollectFieldsPayload()
    local fields = {}
    for key, control in pairs(self.Fields) do
        local meta = self.FieldMeta[key] or {}
        if meta.type == "combo" then
            fields[key] = string.Trim(control:GetValue() or "")
        else
            fields[key] = string.Trim(control:GetValue() or "")
        end
    end
    return fields
end

function PANEL:OpenDivisionTransferPicker()
    if not IsValid(self.Fields.division) then return end

    if IsValid(self.TransferPanel) then
        self.TransferPanel:Remove()
    end

    local divisions = LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.Divisions or { "Cadet", "Operations", "Sciences", "Command", "Admiral" }

    self.TransferPanel = vgui.Create("DPanel", self.Root)
    self.TransferPanel:SetSize(430, 190)
    self.TransferPanel:SetPos((ScrW() - 430) * 0.5, (ScrH() - 190) * 0.5)
    StylePanel(self.TransferPanel, 18)

    local label = CreateSubLabel(self.TransferPanel, "Choose division for transfer")
    label:SetPos(16, 14)
    label:SetSize(390, 24)

    local combo = CreateComboBox(self.TransferPanel)
    combo:SetPos(16, 48)
    combo:SetSize(398, 30)
    for _, divisionName in ipairs(divisions) do
        combo:AddChoice(tostring(divisionName))
    end

    local currentValue = self.Fields.division:GetValue() or ""
    if currentValue ~= "" then
        combo:SetValue(currentValue)
    else
        combo:ChooseOptionID(1)
    end

    local confirmButton = CreateActionButton(self.TransferPanel, "Transfer", Color(145, 220, 180, 255))
    confirmButton:SetPos(16, 144)
    confirmButton:SetSize(194, 30)
    confirmButton.DoClick = function()
        self.Fields.division:SetValue(combo:GetValue() or "")
        if IsValid(self.TransferPanel) then self.TransferPanel:Remove() end
        self:RunAction("transfer_division")
    end

    local cancelButton = CreateActionButton(self.TransferPanel, "Cancel", Theme.Accent)
    cancelButton:SetPos(220, 144)
    cancelButton:SetSize(194, 30)
    cancelButton.DoClick = function()
        if IsValid(self.TransferPanel) then self.TransferPanel:Remove() end
    end
end

function PANEL:ConfirmAndRun(actionID)
    if actionID ~= "delete_character" and actionID ~= "delete_player_data" then
        self:RunAction(actionID)
        return
    end

    if IsValid(self.ConfirmPanel) then
        self.ConfirmPanel:Remove()
    end

    self.ConfirmPanel = vgui.Create("DPanel", self.Root)
    self.ConfirmPanel:SetSize(420, 160)
    self.ConfirmPanel:SetPos((ScrW() - 420) * 0.5, (ScrH() - 160) * 0.5)
    StylePanel(self.ConfirmPanel, 18)

    local label = CreateSubLabel(self.ConfirmPanel, "Confirm destructive action: " .. actionID)
    label:SetPos(16, 18)
    label:SetSize(390, 24)

    local yesButton = CreateActionButton(self.ConfirmPanel, "Confirm", Color(230, 100, 100, 255))
    yesButton:SetPos(16, 112)
    yesButton:SetSize(186, 32)
    yesButton.DoClick = function()
        if IsValid(self.ConfirmPanel) then self.ConfirmPanel:Remove() end
        self:RunAction(actionID)
    end

    local noButton = CreateActionButton(self.ConfirmPanel, "Cancel", Theme.Accent)
    noButton:SetPos(218, 112)
    noButton:SetSize(186, 32)
    noButton.DoClick = function()
        if IsValid(self.ConfirmPanel) then self.ConfirmPanel:Remove() end
    end
end

function PANEL:PerformAction(actionID)
    if not self.SelectedSteamID64 then return end
    if actionID ~= "delete_player_data" and not self.SelectedCharacterID then return end

    if actionID == "transfer_division" then
        self:OpenDivisionTransferPicker()
        return
    end

    self:ConfirmAndRun(actionID)
end

function PANEL:RunAction(actionID)
    Personnel.SubmitAction({
        mode = self.Mode,
        steamID64 = self.SelectedSteamID64,
        characterID = self.SelectedCharacterID,
        action = actionID,
        fields = self:CollectFieldsPayload()
    })
end

function PANEL:OnDirectoryData(payload)
    if not istable(payload) then return end

    self.DirectoryList:Clear()

    for _, playerEntry in ipairs(payload.players or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.DirectoryList)
        row:Dock(TOP)
        row:DockMargin(4, 0, 4, 8)
        row:SetTall(58)
        row:SetText("")

        local steamName = tostring(playerEntry.steamName or "Unknown")
        local steamID64 = tostring(playerEntry.steamID64 or "")
        local stateText = playerEntry.online and "Online" or "Offline"
        local stateColor = playerEntry.online and Color(170, 240, 170) or Color(240, 180, 180)

        row:SetButtonText(steamName)
        row.Paint = function(panel, w, h)
            local hovered = panel:IsHovered()
            draw.RoundedBox(12, 0, 0, w, h, hovered and Color(30, 38, 56, 220) or Color(18, 24, 36, 198))
            surface.SetDrawColor(255, 255, 255, hovered and 170 or 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(steamName, "LeopardRP.Menu.Small", 12, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(steamID64, "LeopardRP.Menu.Micro", 12, 30, Color(200, 200, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(stateText, "LeopardRP.Menu.Micro", w - 12, 10, stateColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Chars: %d", tonumber(playerEntry.characterCount) or 0), "LeopardRP.Menu.Micro", w - 12, 30, Color(200, 200, 210), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        row.DoClick = function()
            self.SelectedSteamID64 = steamID64
            self.SelectedCharacterID = nil
            Personnel.RequestCharacterList(self.Mode, steamID64)
        end
    end
end

function PANEL:OnCharacterListData(payload)
    if not istable(payload) then return end

    if self.SelectedSteamID64 and payload.steamID64 and self.SelectedSteamID64 ~= payload.steamID64 then
        return
    end

    self.CharacterList:Clear()

    for _, characterEntry in ipairs(payload.characters or {}) do
        local row = vgui.Create("LeopardRPMenuButton", self.CharacterList)
        row:Dock(TOP)
        row:DockMargin(4, 0, 4, 8)
        row:SetTall(74)
        row:SetText("")
        row:SetButtonText(tostring(characterEntry.name or "Unnamed"))

        row.Paint = function(panel, w, h)
            local hovered = panel:IsHovered()
            draw.RoundedBox(12, 0, 0, w, h, hovered and Color(30, 38, 56, 220) or Color(18, 24, 36, 198))
            surface.SetDrawColor(255, 255, 255, hovered and 170 or 110)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(tostring(characterEntry.name or "Unnamed"), "LeopardRP.Menu.Small", 12, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("%s | %s | %s | Age %s", tostring(characterEntry.rankName or ""), tostring(characterEntry.division or ""), tostring(characterEntry.species or ""), tostring(characterEntry.age or "0")), "LeopardRP.Menu.Micro", 12, 32, Color(200, 205, 215), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Status: %s", tostring(characterEntry.status or "Unknown")), "LeopardRP.Menu.Micro", 12, 50, Color(180, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        row.DoClick = function()
            self.SelectedCharacterID = tostring(characterEntry.id or "")
            Personnel.RequestCharacterDetails(self.Mode, self.SelectedSteamID64, self.SelectedCharacterID)
        end
    end
end

function PANEL:OnCharacterDetailsData(payload)
    if not istable(payload) or not istable(payload.details) then return end

    if self.SelectedSteamID64 and payload.steamID64 and self.SelectedSteamID64 ~= payload.steamID64 then
        return
    end

    if self.SelectedCharacterID and payload.characterID and self.SelectedCharacterID ~= payload.characterID then
        return
    end

    self.CurrentDetails = payload.details
    local character = payload.details.character or {}

    for key, entry in pairs(self.Fields) do
        if IsValid(entry) then
            local value = tostring(character[key] or "")
            local meta = self.FieldMeta[key] or {}
            if meta.type == "combo" then
                entry:SetValue(value)
            else
                entry:SetText(value)
            end
        end
    end

    if IsValid(self.Preview) then
        self.Preview:SetCharacterData({
            bodyModel = character.bodyModel,
            headModel = character.headModel,
            headIndex = character.headIndex,
            rankID = character.rankID,
            division = character.division
        })
    end

    self.DossierList:Clear()
    for _, dossierEntry in ipairs(payload.details.dossierEntries or {}) do
        local row = vgui.Create("DPanel", self.DossierList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
            row:SetTall(self.Mode == "admin" and 96 or 72)
        row.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(16, 24, 36, 188))
            surface.SetDrawColor(255, 255, 255, 90)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            draw.SimpleText(string.format("[%s] %s", tostring(dossierEntry.category or "Service Notes"), tostring(dossierEntry.authorName or "Unknown")), "LeopardRP.Menu.Micro", 8, 8, Color(220, 230, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(dossierEntry.text or ""), "LeopardRP.Menu.Micro", 8, 28, Color(210, 210, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("TS: %s | SD: %s", os.date("%Y-%m-%d %H:%M:%S", tonumber(dossierEntry.timestamp) or 0), tostring(dossierEntry.stardate or "")), "LeopardRP.Menu.Micro", 8, 52, Color(180, 190, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

            if self.Mode == "admin" then
                local deleteButton = vgui.Create("LeopardRPMenuButton", row)
                deleteButton:SetText("")
                deleteButton:SetButtonText("Delete Entry")
                deleteButton:SetSize(124, 24)
                deleteButton:SetPos(8, 68)
                deleteButton:SetAccentColor(Color(230, 100, 100, 255))
                deleteButton.DoClick = function()
                    net.Start(Personnel.NetworkStrings.DeleteDossierEntry)
                    net.WriteString(tostring(dossierEntry.id or 0))
                    net.WriteString(tostring(self.SelectedSteamID64 or ""))
                    net.WriteString(tostring(self.SelectedCharacterID or ""))
                    net.SendToServer()
                end
            end
    end
end

function PANEL:PerformLayout(w, h)
    self.Root:SetSize(w, h)

    local headerHeight = math.max(88, h * 0.1)
    self.HeaderBar:SetTall(headerHeight)

    self.TitleLabel:SetPos(20, 14)
    self.TitleLabel:SetSize(w * 0.5, 30)

    self.SubtitleLabel:SetPos(20, 44)
    self.SubtitleLabel:SetSize(w * 0.6, 22)

    local backW = math.max(120, w * 0.08)
    self.BackButton:SetSize(backW, math.max(34, headerHeight * 0.42))
    self.BackButton:SetPos(self.HeaderBar:GetWide() - backW - 18, (headerHeight - self.BackButton:GetTall()) * 0.5)

    local contentTop = 24 + headerHeight + 16
    local contentBottom = self.BottomBar:GetTall() + 40
    local contentHeight = h - contentTop - contentBottom

    local leftW = math.floor(w * 0.22)
    local centerW = math.floor(w * 0.23)
    local rightW = w - leftW - centerW - 72

    self.LeftPanel:SetPos(24, contentTop)
    self.LeftPanel:SetSize(leftW, contentHeight)

    self.CenterPanel:SetPos(24 + leftW + 12, contentTop)
    self.CenterPanel:SetSize(centerW, contentHeight)

    self.RightPanel:SetPos(24 + leftW + 12 + centerW + 12, contentTop)
    self.RightPanel:SetSize(rightW, contentHeight)

    self.BottomBar:SetPos(24, h - self.BottomBar:GetTall() - 24)
    self.BottomBar:SetSize(w - 48, self.BottomBar:GetTall())

    self.DirectorySearch:SetWide(self.DirectoryCard:GetWide() - 32)
    self.DirectoryList:SetSize(self.DirectoryCard:GetWide() - 24, self.DirectoryCard:GetTall() - 96)

    self.CharacterList:SetSize(self.CharacterListCard:GetWide() - 24, self.CharacterListCard:GetTall() - 60)

    local rightInnerW = self.DetailsCard:GetWide() - 32
    local rightInnerH = self.DetailsCard:GetTall() - 58

    local previewW = math.floor(rightInnerW * 0.58)
    local previewH = math.min(math.max(250, self.DetailsCard:GetTall() * 0.42), 420)
    local dossierH = math.min(rightInnerH - 180, math.max(previewH + 48, math.floor(self.DetailsCard:GetTall() * 0.5)))
    local dossierW = math.max(180, rightInnerW - previewW - 12)

    self.Preview:SetSize(previewW, previewH)
    self.DossierCard:SetPos(16 + previewW + 12, 46)
    self.DossierCard:SetSize(dossierW, dossierH)

    self.DossierInput:SetSize(math.max(90, dossierW - 176), 26)
    self.DossierAdd:SetSize(math.max(120, dossierW - 20), 28)
    self.DossierList:SetSize(math.max(120, dossierW - 20), math.max(80, dossierH - 104))

    self.DetailsScroll:SetPos(16, 46 + dossierH + 12)
    self.DetailsScroll:SetSize(rightInnerW, math.max(160, rightInnerH - dossierH - 12))

    local actionCount = #self.ActionOrder
    if actionCount > 0 then
        local buttonGap = 10
        local buttonW = math.max(120, math.floor((self.BottomBar:GetWide() - (buttonGap * (actionCount + 1))) / actionCount))
        local buttonH = self.BottomBar:GetTall() - 24

        for index, actionID in ipairs(self.ActionOrder) do
            local button = self.Actions[actionID]
            if IsValid(button) then
                button:SetSize(buttonW, buttonH)
                button:SetPos(buttonGap + (index - 1) * (buttonW + buttonGap), 12)
            end
        end
    end
end

function PANEL:OnRemove()
    SetMenuInteractionEnabled(false)
    if Personnel.ActivePanel == self then
        Personnel.ActivePanel = nil
    end
end

vgui.Register("LeopardRPPersonnelBasePanel", PANEL, "EditablePanel")

LeopardRP = LeopardRP or {}
LeopardRP.GameMaster = LeopardRP.GameMaster or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local GM = LeopardRP.GameMaster
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

local function FormatActionText(actionID)
    local action = string.Trim(tostring(actionID or ""))
    if action == "" then
        return "Unknown"
    end

    action = string.Replace(action, "_", " ")
    return string.upper(string.sub(action, 1, 1)) .. string.sub(action, 2)
end

local function BuildGMLogDetails(details)
    if not istable(details) then
        return ""
    end

    local parts = {}
    local eventCharacterID = tonumber(details.eventCharacterID)
    local entityModel = string.Trim(tostring(details.entityModel or ""))
    local rankID = string.Trim(tostring(details.rankID or ""))
    local actionName = string.Trim(tostring(details.action or ""))
    local actionsPerformed = tonumber(details.actionsPerformed)
    local sessionLength = tonumber(details.sessionLengthSeconds)

    if eventCharacterID and eventCharacterID > 0 then
        table.insert(parts, "Event Character ID: " .. tostring(eventCharacterID))
    end
    if entityModel ~= "" then
        table.insert(parts, "Model: " .. entityModel)
    end
    if rankID ~= "" then
        table.insert(parts, "Rank: " .. rankID)
    end
    if actionName ~= "" then
        table.insert(parts, "Utility: " .. FormatActionText(actionName))
    end
    if actionsPerformed and actionsPerformed >= 0 then
        table.insert(parts, "Actions: " .. tostring(actionsPerformed))
    end
    if sessionLength and sessionLength >= 0 then
        table.insert(parts, "Session: " .. string.NiceTime(sessionLength))
    end

    return table.concat(parts, " | ")
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

local function BuildGMGalaxyEntries()
    local entries = {}
    local minX, maxX = math.huge, -math.huge
    local minY, maxY = math.huge, -math.huge
    local source = "none"

    local function posToXY(pos)
        if isvector(pos) then
            return pos.x, pos.y
        end

        if IsWorldVector(pos) then
            local vec = pos:ToVector()
            return vec.x, vec.y
        end

        return nil, nil
    end

    local function pushEntry(name, className, x, y)
        x = tonumber(x)
        y = tonumber(y)
        if not x or not y then
            return
        end

        entries[#entries + 1] = {
            Name = tostring(name or "Unknown"),
            Class = tostring(className or "area"),
            X = x,
            Y = y,
            __key = string.format("%s|%.4f|%.4f", tostring(name or "Unknown"), x, y),
        }

        minX = math.min(minX, x)
        maxX = math.max(maxX, x)
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end

    if istable(Star_Trek) and istable(Star_Trek.World) and istable(Star_Trek.World.GalaxySystems) then
        for _, sector in ipairs(Star_Trek.World.GalaxySystems) do
            local x = tonumber(sector and sector.X)
            local y = tonumber(sector and sector.Y)
            if x and y then
                source = "startrek_galaxy_systems"
                pushEntry(sector.Name or "Unnamed Sector", "sector", x, y)
            end
        end
    end

    if istable(Star_Trek) and istable(Star_Trek.World) and istable(Star_Trek.World.Entities) then
        local ship = Star_Trek.World.Entities[1]
        local x, y = posToXY(ship and ship.Pos)
        if x and y then
            pushEntry(ship.Name or "Ship", "ship", x, y)
        end
    end

    if #entries == 0 and istable(Star_Trek) and istable(Star_Trek.SystemMap) and isfunction(Star_Trek.SystemMap.BuildGalaxyMapData) then
        local galaxyEntries = Star_Trek.SystemMap:BuildGalaxyMapData()
        if istable(galaxyEntries) and #galaxyEntries > 0 then
            source = "startrek_galaxy_map"

            for _, entry in ipairs(galaxyEntries) do
                pushEntry(entry.Name or "Unknown Sector", entry.Class or "area", entry.RelX, entry.RelY)
            end
        end
    end

    if #entries == 0 and LeopardRP and LeopardRP.Galaxy and isfunction(LeopardRP.Galaxy.BuildSnapshot) then
        local snapshot = LeopardRP.Galaxy:BuildSnapshot() or {}
        local systems = snapshot.Systems or {}
        local objects = snapshot.Objects or {}
        if istable(systems) and #systems > 0 then
            source = "leopardrp_snapshot"

            local systemPosById = {}
            for _, systemData in ipairs(systems) do
                local systemId = tostring(systemData.Id or "")
                local sx = tonumber(systemData.X)
                local sy = tonumber(systemData.Y)
                if sx and sy then
                    systemPosById[systemId] = { X = sx, Y = sy }
                    pushEntry(systemData.Name or "Unnamed Sector", "sector", sx, sy)
                end
            end

            for _, objectData in ipairs(objects) do
                local objectPos = objectData.RuntimePosition or {}
                local ox = tonumber(objectPos.X)
                local oy = tonumber(objectPos.Y)
                if not ox or not oy then
                    local fallback = systemPosById[tostring(objectData.SystemId or "")]
                    if fallback then
                        ox, oy = fallback.X, fallback.Y
                    end
                end

                pushEntry(objectData.Name or "Unnamed Area", objectData.TypeId or "area", ox, oy)
            end
        end
    end

    if #entries == 0 and Star_Trek and Star_Trek.World and istable(Star_Trek.World.StarSystems) then
        source = "startrek_systems"
        for _, starSystem in ipairs(Star_Trek.World.StarSystems) do
            if istable(starSystem) and istable(starSystem.Data) then
                local sx = tonumber(starSystem.X)
                local sy = tonumber(starSystem.Y)
                pushEntry(starSystem.Data.Name or "Unnamed Sector", "sector", sx, sy)
            end
        end
    end

    if #entries == 0 then
        return entries, nil, "no_data"
    end

    if minX == maxX then
        minX = minX - 1
        maxX = maxX + 1
    end
    if minY == maxY then
        minY = minY - 1
        maxY = maxY + 1
    end

    table.sort(entries, function(a, b)
        if a.Class == "sector" and b.Class ~= "sector" then return true end
        if b.Class == "sector" and a.Class ~= "sector" then return false end
        return tostring(a.Name or "") < tostring(b.Name or "")
    end)

    return entries, { MinX = minX, MaxX = maxX, MinY = minY, MaxY = maxY }, source
end

local function CopyTable(source)
    local copy = {}
    if not istable(source) then return copy end
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

local function NormalizeGalaxyName(text)
    return string.lower(string.Trim(tostring(text or "")))
end

local function BuildPlanetsFromSector(sectorEntry)
    local children = {}
    if not istable(sectorEntry) then return children end

    local sectorName = tostring(sectorEntry.Name or "Unnamed Sector")
    local baseOrbit = 0.2
    for index = 1, 8 do
        children[#children + 1] = {
            Name = string.format("%s Planet %d", sectorName, index),
            Model = "models/crazycanadian/space/sol/earth.mdl",
            Diameter = 12000 + index * 500,
            OrbitRadius = baseOrbit + (index - 1) * 0.18,
        }
    end

    return children
end

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
    SetMenuInteractionEnabled(true)

    self.Root = LeopardRP.CharacterCreation.CreateFullscreenRoot("ui/MainMenuScreen.png", self)
    self.Root:Dock(FILL)

    self.Header = CreateCard(self.Root)
    self.Header:SetSize(ScrW() * 0.94, ScrH() * 0.095)
    self.Header:SetPos(ScrW() * 0.03, ScrH() * 0.03)

    local title = vgui.Create("DLabel", self.Header)
    title:SetFont("LeopardRP.Menu.PanelBold")
    title:SetTextColor(Color(255, 255, 255))
    title:SetText("Game Master Event Suite")
    title:SizeToContents()
    title:SetPos(24, 16)

    local subtitle = vgui.Create("DLabel", self.Header)
    subtitle:SetFont("LeopardRP.Menu.Small")
    subtitle:SetTextColor(Color(210, 225, 240, 240))
    subtitle:SetText("Game Master event suite with integrated galaxy map tools.")
    subtitle:SizeToContents()
    subtitle:SetPos(24, 46)

    self.CloseButton = CreateStyledButton(self.Header, "Close")
    self.CloseButton:SetSize(120, 38)
    self.CloseButton:SetPos(self.Header:GetWide() - 136, 16)
    self.CloseButton.DoClick = function()
        GM.CloseActivePanel()
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
        GM.CloseActivePanel()
    end

    self.Nav = CreateCard(self.Root)
    self.Nav:SetSize(ScrW() * 0.2, ScrH() * 0.78)
    self.Nav:SetPos(ScrW() * 0.03, ScrH() * 0.145)

    self.Content = CreateCard(self.Root)
    self.Content:SetSize(ScrW() * 0.73, ScrH() * 0.78)
    self.Content:SetPos(ScrW() * 0.24, ScrH() * 0.145)

    self.Pages = {}
    self.PageButtons = {}
    self.ActivePage = nil

    local pageList = {
        { id = "dashboard", label = "Duty Dashboard" },
        { id = "event_characters", label = "Event Characters" },
        { id = "utilities", label = "Event Utilities" },
        { id = "logs", label = "GM Logs" },
        { id = "galaxy_map", label = "Galaxy Map" },
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
    self:BuildEventCharactersPage()
    self:BuildUtilitiesPage()
    self:BuildLogsPage()
    self:BuildGalaxyMapPage()

    self:SetPage("dashboard")
    self:OnDataUpdated(GM.State or {})
end

function PANEL:OnRemove()
    if GM.ActivePanel == self then
        GM.ActivePanel = nil
    end

    local hasCharacterMenu = LeopardRP.CharacterCreation and IsValid(LeopardRP.CharacterCreation.ActiveMenuFrame)
    local hasPersonnelMenu = LeopardRP.Personnel and IsValid(LeopardRP.Personnel.ActivePanel)
    local hasAdminMenu = LeopardRP.Administration and IsValid(LeopardRP.Administration.ActivePanel)
    if not hasCharacterMenu and not hasPersonnelMenu and not hasAdminMenu then
        SetMenuInteractionEnabled(false)
    end
end

function PANEL:SetPage(pageID)
    if self.ActivePage == pageID then return end

    for id, page in pairs(self.Pages) do
        page:SetVisible(id == pageID)
    end

    for id, button in pairs(self.PageButtons) do
        if button.SetAccentColor then
            button:SetAccentColor(id == pageID and Color(150, 210, 255, 255) or nil)
        end
    end

    self.ActivePage = pageID
end

function PANEL:CreatePage(pageID)
    local page = vgui.Create("EditablePanel", self.Content)
    page:SetSize(self.Content:GetWide() - 24, self.Content:GetTall() - 24)
    page:SetPos(12, 12)
    page:SetVisible(false)
    page.Paint = function() end
    self.Pages[pageID] = page
    return page
end

function PANEL:BuildDashboardPage()
    local page = self:CreatePage("dashboard")

    self.ClockCard = CreateCard(page)
    self.ClockCard:SetSize(page:GetWide() * 0.5 - 8, 166)
    self.ClockCard:SetPos(0, 0)

    self.ClockStatus = vgui.Create("DLabel", self.ClockCard)
    self.ClockStatus:SetFont("LeopardRP.Menu.Small")
    self.ClockStatus:SetTextColor(Color(220, 240, 255, 240))
    self.ClockStatus:SetText("Status: Offline")
    self.ClockStatus:SizeToContents()
    self.ClockStatus:SetPos(14, 20)

    self.ClockButton = CreateStyledButton(self.ClockCard, "Clock In", Color(145, 220, 180, 255))
    self.ClockButton:SetSize(220, 34)
    self.ClockButton:SetPos(14, 118)
    self.ClockButton.DoClick = function()
        local isClockedIn = tobool((GM.State.clock or {}).clockedIn)
        GM.ToggleClock(not isClockedIn)
    end

    self.RankCard = CreateCard(page)
    self.RankCard:SetSize(page:GetWide() * 0.5 - 8, 166)
    self.RankCard:SetPos(page:GetWide() * 0.5 + 8, 0)

    self.RankDetail = vgui.Create("DLabel", self.RankCard)
    self.RankDetail:SetFont("LeopardRP.Menu.Small")
    self.RankDetail:SetTextColor(Color(220, 240, 255, 240))
    self.RankDetail:SetText("GM Rank: Unknown")
    self.RankDetail:SizeToContents()
    self.RankDetail:SetPos(14, 20)

    self.OverviewList = vgui.Create("DScrollPanel", page)
    self.OverviewList:SetPos(0, 184)
    self.OverviewList:SetSize(page:GetWide(), page:GetTall() - 184)
end

function PANEL:BuildEventCharactersPage()
    local page = self:CreatePage("event_characters")

    self.EventList = vgui.Create("DScrollPanel", page)
    self.EventList:SetPos(0, 0)
    self.EventList:SetSize(page:GetWide() * 0.58 - 6, page:GetTall())

    self.EventRight = CreateCard(page)
    self.EventRight:SetSize(page:GetWide() * 0.42 - 6, page:GetTall())
    self.EventRight:SetPos(page:GetWide() * 0.58 + 6, 0)

    self.EventFields = {}
    local labels = {
        { "Character Name", "name" },
        { "Species", "species" },
        { "Gender", "gender" },
        { "Body", "bodyID" },
        { "Head", "headID" },
        { "Skin", "skin" },
        { "Model Path", "modelPath" }
    }

    local y = 12
    for _, entry in ipairs(labels) do
        local field = CreateStyledEntry(self.EventRight, entry[1])
        field:SetPos(12, y)
        field:SetSize(self.EventRight:GetWide() - 24, 28)
        self.EventFields[entry[2]] = field
        y = y + 34
    end

    self.EventCreateButton = CreateStyledButton(self.EventRight, "Save Event Character", Color(145, 220, 180, 255))
    self.EventCreateButton:SetSize(self.EventRight:GetWide() - 24, 34)
    self.EventCreateButton:SetPos(12, y + 8)
    self.EventCreateButton.DoClick = function()
        GM.SubmitAction({
            type = "create_event_character",
            name = self.EventFields.name:GetValue(),
            species = self.EventFields.species:GetValue(),
            gender = self.EventFields.gender:GetValue(),
            bodyID = self.EventFields.bodyID:GetValue(),
            headID = self.EventFields.headID:GetValue(),
            skin = self.EventFields.skin:GetValue(),
            modelPath = self.EventFields.modelPath:GetValue(),
            bodygroups = {},
            boneMerge = true,
        })
    end
end

function PANEL:BuildUtilitiesPage()
    local page = self:CreatePage("utilities")
    local controls = vgui.Create("DPanel", page)
    controls:Dock(TOP)
    controls:SetTall(42)
    controls.Paint = function() end

    local scroll = vgui.Create("DScrollPanel", page)
    scroll:Dock(FILL)
    scroll:DockMargin(0, 8, 0, 0)

    local utilities = {
        { id = "teleport_to", text = "Teleport To Player" },
        { id = "bring_player", text = "Bring Player" },
        { id = "return_player", text = "Return Player" },
        { id = "freeze_player", text = "Freeze Player" },
        { id = "unfreeze_player", text = "Unfreeze Player" },
        { id = "cleanup_entire_event", text = "Cleanup Entire Event" },
    }

    self.UtilityTarget = CreateStyledCombo(controls)
    self.UtilityTarget:Dock(FILL)
    self.UtilityTarget:DockMargin(12, 6, 12, 6)

    for _, utility in ipairs(utilities) do
        local row = CreateCard(scroll)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 8)
        row:SetTall(48)

        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Small")
        label:SetTextColor(Color(235, 245, 255, 245))
        label:SetText(utility.text)
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)

        local actionButton = CreateStyledButton(row, "Run", Color(150, 205, 255, 255))
        actionButton:SetSize(120, 30)
        actionButton.DoClick = function()
            local selectedID = self.UtilityTarget:GetSelectedID() or 0
            local targetSteamID64 = self.UtilityTarget:GetOptionData(selectedID)
            GM.SubmitAction({ type = "utility_action", action = utility.id, targetSteamID64 = targetSteamID64 or "" })
        end

        row.PerformLayout = function(panel, w)
            local buttonW = 120
            local leftPad, rightPad = 12, 12
            local buttonX = w - buttonW - rightPad
            actionButton:SetPos(buttonX, 9)

            local labelW = math.max(120, buttonX - leftPad - 10)
            label:SetPos(leftPad, 8)
            label:SetSize(labelW, 32)
            label:SizeToContentsY()

            local desiredTall = math.max(48, label:GetTall() + 16)
            if panel:GetTall() ~= desiredTall then
                panel:SetTall(desiredTall)
            end
        end
    end

    local spawnerRow = CreateCard(scroll)
    spawnerRow:Dock(TOP)
    spawnerRow:DockMargin(0, 0, 0, 8)
    spawnerRow:SetTall(48)

    local spawnerLabel = vgui.Create("DLabel", spawnerRow)
    spawnerLabel:SetFont("LeopardRP.Menu.Small")
    spawnerLabel:SetTextColor(Color(235, 245, 255, 245))
    spawnerLabel:SetText("Open Item Spawner")

    local spawnerButton = CreateStyledButton(spawnerRow, "Open", Color(255, 185, 120, 255))
    spawnerButton:SetSize(120, 30)
    spawnerButton.DoClick = function()
        if (LeopardRP.Personnel and LeopardRP.Personnel.OpenItemSpawner) then
            LeopardRP.Personnel.OpenItemSpawner()
        end
    end

    spawnerRow.PerformLayout = function(panel, w)
        local buttonW = 120
        local leftPad, rightPad = 12, 12
        local buttonX = w - buttonW - rightPad
        spawnerButton:SetPos(buttonX, 9)

        local labelW = math.max(120, buttonX - leftPad - 10)
        spawnerLabel:SetPos(leftPad, 14)
        spawnerLabel:SetSize(labelW, 20)
    end
end

function PANEL:BuildLogsPage()
    local page = self:CreatePage("logs")
    self.LogList = vgui.Create("DScrollPanel", page)
    self.LogList:Dock(FILL)
end

function PANEL:BuildGalaxyMapPage()
    local page = self:CreatePage("galaxy_map")

    self.GalaxyZoom = self.GalaxyZoom or 1
    self.GalaxyPanX = self.GalaxyPanX or 0
    self.GalaxyPanY = self.GalaxyPanY or 0
    self.GalaxySelectedIndex = self.GalaxySelectedIndex or 0
    self.GalaxySortMode = self.GalaxySortMode or "name"
    self.GalaxyLookupText = self.GalaxyLookupText or ""
    self.GalaxyFocusedSector = self.GalaxyFocusedSector or nil
    self.GalaxyDragging = false
    self.GalaxyDragStartX = 0
    self.GalaxyDragStartY = 0
    self.GalaxyPanStartX = 0
    self.GalaxyPanStartY = 0

    self.GalaxyStatus = vgui.Create("DLabel", page)
    self.GalaxyStatus:SetFont("LeopardRP.Menu.Small")
    self.GalaxyStatus:SetTextColor(Color(220, 240, 255, 240))
    self.GalaxyStatus:SetText("Loading galaxy map...")
    self.GalaxyStatus:SetPos(12, 10)
    self.GalaxyStatus:SetSize(page:GetWide() - 140, 24)

    self.GalaxyRefreshButton = CreateStyledButton(page, "Refresh", Color(150, 205, 255, 255))
    self.GalaxyRefreshButton:SetSize(110, 30)
    self.GalaxyRefreshButton:SetPos(page:GetWide() - 122, 8)
    self.GalaxyRefreshButton.DoClick = function()
        self:RefreshGalaxyMapData()
    end

    self.GalaxyMapCanvas = CreateCard(page)
    self.GalaxyMapCanvas:SetPos(0, 44)
    self.GalaxyMapCanvas:SetSize(page:GetWide() * 0.68 - 6, page:GetTall() - 44)
    self.GalaxyMapCanvas:SetMouseInputEnabled(true)

    self.GalaxyList = vgui.Create("DScrollPanel", page)
    self.GalaxyList:SetPos(page:GetWide() * 0.68 + 6, 44)
    self.GalaxyList:SetSize(page:GetWide() * 0.32 - 6, page:GetTall() - 44)

        self.GalaxySearch = vgui.Create("DTextEntry", page)
        self.GalaxySearch:SetPos(12, 44)
        self.GalaxySearch:SetSize(page:GetWide() * 0.36, 28)
        self.GalaxySearch:SetPlaceholderText("Lookup sector or area")
        self.GalaxySearch.OnTextChanged = function(control)
		self.GalaxyLookupText = control:GetText() or ""
		self:RefreshGalaxyMapData()
	end

        self.GalaxySort = vgui.Create("DComboBox", page)
        self.GalaxySort:SetPos(page:GetWide() * 0.36 + 20, 44)
        self.GalaxySort:SetSize(page:GetWide() * 0.18, 28)
        self.GalaxySort:AddChoice("Name", "name", true)
        self.GalaxySort:AddChoice("Class", "class")
        self.GalaxySort:AddChoice("X", "x")
        self.GalaxySort:AddChoice("Y", "y")
        self.GalaxySort.OnSelect = function(_, _, _, data)
		self.GalaxySortMode = tostring(data or "name")
		self:RefreshGalaxyMapData()
	end

        self.GalaxyDetail = CreateCard(page)
        self.GalaxyDetail:SetPos(0, page:GetTall() - 150)
        self.GalaxyDetail:SetSize(page:GetWide() * 0.68 - 6, 106)

        self.GalaxyDetailTitle = vgui.Create("DLabel", self.GalaxyDetail)
        self.GalaxyDetailTitle:SetFont("LeopardRP.Menu.Small")
        self.GalaxyDetailTitle:SetTextColor(Color(255, 235, 180, 240))
        self.GalaxyDetailTitle:SetText("Double-click a sector to zoom in")
        self.GalaxyDetailTitle:SetPos(12, 10)
        self.GalaxyDetailTitle:SizeToContents()

        self.GalaxyDetailInfo = vgui.Create("DLabel", self.GalaxyDetail)
        self.GalaxyDetailInfo:SetFont("LeopardRP.Menu.Micro")
        self.GalaxyDetailInfo:SetTextColor(Color(220, 240, 255, 235))
        self.GalaxyDetailInfo:SetText("Use search and sort to find areas, then double click a sector to focus it.")
        self.GalaxyDetailInfo:SetPos(12, 34)
        self.GalaxyDetailInfo:SetSize(self.GalaxyDetail:GetWide() - 24, 60)

        self.GalaxyEditor = CreateCard(page)
        self.GalaxyEditor:SetPos(page:GetWide() * 0.68 + 6, page:GetTall() - 204)
        self.GalaxyEditor:SetSize(page:GetWide() * 0.32 - 6, 194)

        self.GalaxyEditorTitle = vgui.Create("DLabel", self.GalaxyEditor)
        self.GalaxyEditorTitle:SetFont("LeopardRP.Menu.Small")
        self.GalaxyEditorTitle:SetTextColor(Color(255, 235, 180, 240))
        self.GalaxyEditorTitle:SetText("Sector Editor")
        self.GalaxyEditorTitle:SetPos(12, 10)
        self.GalaxyEditorTitle:SizeToContents()

        self.GalaxyEditorHint = vgui.Create("DLabel", self.GalaxyEditor)
        self.GalaxyEditorHint:SetFont("LeopardRP.Menu.Micro")
        self.GalaxyEditorHint:SetTextColor(Color(220, 240, 255, 225))
        self.GalaxyEditorHint:SetText("Double-click a sector to edit planets and export JSON.")
        self.GalaxyEditorHint:SetPos(12, 32)
        self.GalaxyEditorHint:SetSize(self.GalaxyEditor:GetWide() - 24, 18)

        self.GalaxyExportButton = CreateStyledButton(self.GalaxyEditor, "Export JSON", Color(145, 220, 175, 255))
        self.GalaxyExportButton:SetPos(12, 152)
        self.GalaxyExportButton:SetSize(100, 28)
        self.GalaxyExportButton.DoClick = function()
		self:ExportFocusedGalaxySector()
	end

        self.GalaxyAddPlanetButton = CreateStyledButton(self.GalaxyEditor, "Add Planet", Color(150, 205, 255, 255))
        self.GalaxyAddPlanetButton:SetPos(118, 152)
        self.GalaxyAddPlanetButton:SetSize(96, 28)
        self.GalaxyAddPlanetButton.DoClick = function()
		self:AddPlanetToFocusedSector()
	end

        self.GalaxyPlanetList = vgui.Create("DScrollPanel", self.GalaxyEditor)
        self.GalaxyPlanetList:SetPos(12, 54)
        self.GalaxyPlanetList:SetSize(self.GalaxyEditor:GetWide() - 24, 92)

    page.PerformLayout = function(panel, w, h)
        self.GalaxyRefreshButton:SetPos(w - 122, 8)
        self.GalaxyStatus:SetPos(12, 10)
        self.GalaxyStatus:SetSize(math.max(120, w - 252), 24)

        self.GalaxyMapCanvas:SetPos(0, 44)
        self.GalaxyMapCanvas:SetSize(w * 0.68 - 6, h - 44)

        self.GalaxyList:SetPos(w * 0.68 + 6, 44)
        self.GalaxyList:SetSize(w * 0.32 - 6, h - 194)

        self.GalaxySearch:SetPos(12, 44)
        self.GalaxySearch:SetSize(w * 0.36, 28)
        self.GalaxySort:SetPos(w * 0.36 + 20, 44)
        self.GalaxySort:SetSize(w * 0.18, 28)
        self.GalaxyDetail:SetPos(0, h - 150)
        self.GalaxyDetail:SetSize(w * 0.68 - 6, 106)
        self.GalaxyDetailInfo:SetSize(self.GalaxyDetail:GetWide() - 24, 60)
		self.GalaxyEditor:SetPos(w * 0.68 + 6, h - 204)
		self.GalaxyEditor:SetSize(w * 0.32 - 6, 194)
		self.GalaxyPlanetList:SetSize(self.GalaxyEditor:GetWide() - 24, 92)
    end

    self.GalaxyMapCanvas.Paint = function(panel, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(12, 18, 28, 210))
        surface.SetDrawColor(255, 255, 255, 110)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local entries = self.GalaxyEntries or {}
        local bounds = self.GalaxyBounds
        if not istable(bounds) or #entries == 0 then
            draw.SimpleText("No galaxy data available.", "LeopardRP.Menu.Small", w * 0.5, h * 0.5, Color(220, 230, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local minX, maxX = tonumber(bounds.MinX), tonumber(bounds.MaxX)
        local minY, maxY = tonumber(bounds.MinY), tonumber(bounds.MaxY)
        if not minX or not maxX or not minY or not maxY then
            draw.SimpleText("No galaxy data available.", "LeopardRP.Menu.Small", w * 0.5, h * 0.5, Color(220, 230, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local spanX = math.max(maxX - minX, 0.001)
        local spanY = math.max(maxY - minY, 0.001)
        local span = math.max(spanX, spanY)
        local pad = 14
        local drawW = math.max(w - pad * 2, 1)
        local drawH = math.max(h - pad * 2, 1)
        local viewScale = math.min(drawW, drawH) * 0.42 / span
        viewScale = viewScale * math.Clamp(self.GalaxyZoom or 1, 0.25, 8)
        local centerX = (minX + maxX) * 0.5 + (tonumber(self.GalaxyPanX) or 0)
        local centerY = (minY + maxY) * 0.5 + (tonumber(self.GalaxyPanY) or 0)

        surface.SetDrawColor(120, 160, 190, 80)
        surface.DrawOutlinedRect(pad, pad, drawW, drawH, 1)
        surface.DrawLine(pad, pad + drawH * 0.5, pad + drawW, pad + drawH * 0.5)
        surface.DrawLine(pad + drawW * 0.5, pad, pad + drawW * 0.5, pad + drawH)

        for _, entry in ipairs(entries) do
            local px = pad + drawW * 0.5 + ((tonumber(entry.X) or 0) - centerX) * viewScale
            local py = pad + drawH * 0.5 - ((tonumber(entry.Y) or 0) - centerY) * viewScale

            if px >= pad - 24 and px <= pad + drawW + 24 and py >= pad - 24 and py <= pad + drawH + 24 then
                local isSector = tostring(entry.Class or "") == "sector"
                local isShip = tostring(entry.Class or "") == "ship"
                local isSelected = tonumber(self.GalaxySelectedIndex) == tonumber(entry.__index or 0)

                if isShip then
                    surface.SetDrawColor(255, 236, 144, 255)
                    surface.DrawRect(px - 4, py - 4, 8, 8)
                elseif isSelected then
                    surface.SetDrawColor(110, 245, 255, 245)
                    surface.DrawOutlinedRect(px - 6, py - 6, 12, 12, 2)
                elseif isSector then
                    surface.SetDrawColor(255, 180, 90, 245)
                    surface.DrawRect(px - 3, py - 3, 6, 6)
                else
                    surface.SetDrawColor(140, 200, 255, 200)
                    surface.DrawRect(px - 2, py - 2, 4, 4)
                end

                draw.SimpleText(tostring(entry.Name or "Unknown"), "LeopardRP.Menu.Micro", px + 8, py - 8, Color(230, 240, 255, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        end
    end

    self.GalaxyMapCanvas.OnMouseWheeled = function(_, delta)
        self.GalaxyZoom = math.Clamp((self.GalaxyZoom or 1) * (delta > 0 and 1.18 or 0.85), 0.25, 24)
        self.GalaxyMapCanvas:InvalidateLayout(true)
        return true
    end

    self.GalaxyMapCanvas.OnMousePressed = function(_, mouseCode)
        if mouseCode == MOUSE_RIGHT then
            self.GalaxyDragging = true
            self.GalaxyDragStartX, self.GalaxyDragStartY = self.GalaxyMapCanvas:CursorPos()
            self.GalaxyPanStartX = self.GalaxyPanX or 0
            self.GalaxyPanStartY = self.GalaxyPanY or 0
            return
        end

        if mouseCode ~= MOUSE_LEFT then
            return
        end

        local mx, my = self.GalaxyMapCanvas:CursorPos()
        local entries = self.GalaxyEntries or {}
        local bounds = self.GalaxyBounds
        if not istable(bounds) or #entries == 0 then return end

        local minX, maxX = tonumber(bounds.MinX), tonumber(bounds.MaxX)
        local minY, maxY = tonumber(bounds.MinY), tonumber(bounds.MaxY)
        if not minX or not maxX or not minY or not maxY then return end

        local span = math.max(maxX - minX, maxY - minY, 0.001)
        local pad = 14
        local drawW = math.max(self.GalaxyMapCanvas:GetWide() - pad * 2, 1)
        local drawH = math.max(self.GalaxyMapCanvas:GetTall() - pad * 2, 1)
        local viewScale = math.min(drawW, drawH) * 0.42 / span * math.Clamp(self.GalaxyZoom or 1, 0.25, 8)
        local centerX = (minX + maxX) * 0.5 + (tonumber(self.GalaxyPanX) or 0)
        local centerY = (minY + maxY) * 0.5 + (tonumber(self.GalaxyPanY) or 0)

        local bestIndex, bestDist = 0, 999999
        local bestSectorIndex, bestSectorDist = 0, 999999
        for index, entry in ipairs(entries) do
            local px = pad + drawW * 0.5 + ((tonumber(entry.X) or 0) - centerX) * viewScale
            local py = pad + drawH * 0.5 - ((tonumber(entry.Y) or 0) - centerY) * viewScale
            local dx = mx - px
            local dy = my - py
            local dist = dx * dx + dy * dy
            if dist < bestDist then
                bestDist = dist
                bestIndex = index
            end
            if tostring(entry.Class or "") == "sector" and dist < bestSectorDist then
                bestSectorDist = dist
                bestSectorIndex = index
            end
        end

        local selectedIndex = 0
        if bestSectorIndex > 0 and bestSectorDist < 40 * 40 then
            selectedIndex = bestSectorIndex
        elseif bestIndex > 0 and bestDist < 40 * 40 then
            selectedIndex = bestIndex
        end

        if selectedIndex > 0 then
            self.GalaxySelectedIndex = selectedIndex
            local entry = entries[selectedIndex]
            self.GalaxyStatus:SetText(string.format("Selected %s", tostring(entry.Name or "Unknown")))
            self.GalaxyStatus:SizeToContentsX()

			local now = CurTime()
			if (self.GalaxyLastClickTime or 0) > 0 and (now - self.GalaxyLastClickTime) < 0.3 then
				self:FocusGalaxySector(entry)
			else
				self:UpdateGalaxyDetail(entry)
			end
			self.GalaxyLastClickTime = now
        end
    end

    self.GalaxyMapCanvas.OnMouseReleased = function(_, mouseCode)
        if mouseCode == MOUSE_RIGHT then
            self.GalaxyDragging = false
        end
    end

    self.GalaxyMapCanvas.OnCursorMoved = function(_, x, y)
        if not self.GalaxyDragging then return end

        local bounds = self.GalaxyBounds
        if not istable(bounds) then return end

        local minX, maxX = tonumber(bounds.MinX), tonumber(bounds.MaxX)
        local minY, maxY = tonumber(bounds.MinY), tonumber(bounds.MaxY)
        if not minX or not maxX or not minY or not maxY then return end

        local span = math.max(maxX - minX, maxY - minY, 0.001)
        local pad = 14
        local drawW = math.max(self.GalaxyMapCanvas:GetWide() - pad * 2, 1)
        local drawH = math.max(self.GalaxyMapCanvas:GetTall() - pad * 2, 1)
        local viewScale = math.min(drawW, drawH) * 0.42 / span * math.Clamp(self.GalaxyZoom or 1, 0.25, 8)
        if viewScale <= 0 then return end

        local dx = x - (self.GalaxyDragStartX or x)
        local dy = y - (self.GalaxyDragStartY or y)
        self.GalaxyPanX = (self.GalaxyPanStartX or 0) - dx / viewScale
        self.GalaxyPanY = (self.GalaxyPanStartY or 0) + dy / viewScale
        self.GalaxyMapCanvas:InvalidateLayout(true)
    end

    self:RefreshGalaxyMapData()
end

function PANEL:RefreshGalaxyMapData()
    local entries, bounds, source = BuildGMGalaxyEntries()
    self.GalaxyEntries = entries
    self.GalaxyBounds = bounds

    if IsValid(self.GalaxyStatus) then
        self.GalaxyStatus:SetText(string.format("Loaded %d entries (%s)", #entries, tostring(source or "unknown")))
        self.GalaxyStatus:SizeToContentsX()
    end

    if not IsValid(self.GalaxyList) then
        return
    end

    self.GalaxyList:Clear()
    local limit = math.min(#entries, 250)
    local lookupText = NormalizeGalaxyName(self.GalaxyLookupText)
    local filtered = {}
    for _, entry in ipairs(entries) do
        local haystack = NormalizeGalaxyName(entry.Name .. " " .. entry.Class)
        if lookupText == "" or string.find(haystack, lookupText, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end

    if self.GalaxySortMode == "class" then
        table.sort(filtered, function(a, b)
            return tostring(a.Class or "") < tostring(b.Class or "")
        end)
    elseif self.GalaxySortMode == "x" then
        table.sort(filtered, function(a, b)
            return (tonumber(a.X) or 0) < (tonumber(b.X) or 0)
        end)
    elseif self.GalaxySortMode == "y" then
        table.sort(filtered, function(a, b)
            return (tonumber(a.Y) or 0) < (tonumber(b.Y) or 0)
        end)
    else
        table.sort(filtered, function(a, b)
            return tostring(a.Name or "") < tostring(b.Name or "")
        end)
    end

    self.GalaxyVisibleEntries = filtered
    for i = 1, math.min(#filtered, limit) do
        local entry = filtered[i]
        entry.__index = i
        local row = CreateCard(self.GalaxyList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(32)

        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Micro")
        label:SetTextColor(Color(230, 240, 255, 240))
        label:SetText(string.format("[%s] %s", tostring(entry.Class or "area"), tostring(entry.Name or "Unknown")))
        label:Dock(FILL)
        label:DockMargin(10, 8, 10, 8)
        label:SetWrap(false)
        local lastClick = 0
        row.OnMousePressed = function()
            local now = CurTime()
            if (now - lastClick) < 0.3 then
                self:FocusGalaxySector(entry)
                return
            end
            lastClick = now
            self.GalaxySelectedIndex = i
            self:UpdateGalaxyDetail(entry)
        end
    end

    if #entries > limit then
        local row = CreateCard(self.GalaxyList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(30)

        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Micro")
        label:SetTextColor(Color(180, 210, 235, 240))
        label:SetText(string.format("... plus %d more entries", #entries - limit))
        label:Dock(FILL)
        label:DockMargin(10, 8, 10, 8)
    end
end

function PANEL:UpdateGalaxyDetail(entry)
    if not IsValid(self.GalaxyDetailTitle) or not IsValid(self.GalaxyDetailInfo) then return end
    if not istable(entry) then
        self.GalaxyDetailTitle:SetText("Double-click a sector to zoom in")
        self.GalaxyDetailInfo:SetText("Use search and sort to find areas, then double click a sector to focus it.")
        return
    end

    local sectorName = tostring(entry.Name or "Unknown Sector")
    self.GalaxyDetailTitle:SetText(sectorName .. " | " .. tostring(entry.Class or "sector"))
    self.GalaxyDetailTitle:SizeToContents()
    self.GalaxyDetailInfo:SetText(string.format("X %.2f | Y %.2f | Double-click to zoom. Use the editor below to add planets.", tonumber(entry.X) or 0, tonumber(entry.Y) or 0))
end

function PANEL:FocusGalaxySector(entry)
    if not istable(entry) then return end
    self.GalaxyFocusedSector = CopyTable(entry)
    self.GalaxyZoom = math.max(self.GalaxyZoom or 1, 8)

    local bounds = self.GalaxyBounds or {}
    local minX, maxX = tonumber(bounds.MinX), tonumber(bounds.MaxX)
    local minY, maxY = tonumber(bounds.MinY), tonumber(bounds.MaxY)
    if minX and maxX and minY and maxY then
        local midX = (minX + maxX) * 0.5
        local midY = (minY + maxY) * 0.5
        self.GalaxyPanX = (tonumber(entry.X) or 0) - midX
        self.GalaxyPanY = (tonumber(entry.Y) or 0) - midY
    else
        self.GalaxyPanX = 0
        self.GalaxyPanY = 0
    end

    self:UpdateGalaxyDetail(entry)
    self:RefreshGalaxyPlanetEditor()
    if IsValid(self.GalaxyMapCanvas) then
        self.GalaxyMapCanvas:InvalidateLayout(true)
    end
end

function PANEL:RefreshGalaxyPlanetEditor()
    if not IsValid(self.GalaxyPlanetList) then return end
    self.GalaxyPlanetList:Clear()

    local sector = self.GalaxyFocusedSector
    if not istable(sector) then
        local row = CreateCard(self.GalaxyPlanetList)
        row:SetTall(28)
        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Micro")
        label:SetTextColor(Color(220, 240, 255, 225))
        label:SetText("No sector selected")
        label:Dock(FILL)
        label:DockMargin(10, 6, 10, 6)
        return
    end

    sector.Planets = istable(sector.Planets) and sector.Planets or BuildPlanetsFromSector(sector)
    for index, planet in ipairs(sector.Planets) do
        local row = CreateCard(self.GalaxyPlanetList)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
                row:SetTall(34)

        local label = vgui.Create("DLabel", row)
        label:SetFont("LeopardRP.Menu.Micro")
        label:SetTextColor(Color(220, 240, 255, 235))
                label:SetText(string.format("%d. %s | %s | %.0f | %.2f", index, tostring(planet.Name or "Planet"), tostring(planet.Model or "model"), tonumber(planet.Diameter) or 0, tonumber(planet.OrbitRadius) or 0))
        label:Dock(FILL)
        label:DockMargin(8, 4, 8, 4)

                local edit = CreateStyledButton(row, "Edit", Color(150, 205, 255, 255))
                edit:SetSize(44, 22)
                edit:Dock(RIGHT)
                edit.DoClick = function()
			self:OpenPlanetEditor(index, planet)
		end

        local remove = CreateStyledButton(row, "X", Color(220, 120, 120, 255))
        remove:SetSize(22, 20)
        remove:Dock(RIGHT)
        remove.DoClick = function()
            table.remove(sector.Planets, index)
            self:RefreshGalaxyPlanetEditor()
        end
    end
end

function PANEL:AddPlanetToFocusedSector()
    local sector = self.GalaxyFocusedSector
    if not istable(sector) then return end
    sector.Planets = istable(sector.Planets) and sector.Planets or BuildPlanetsFromSector(sector)
    sector.Planets[#sector.Planets + 1] = {
        Name = string.format("%s Planet %d", tostring(sector.Name or "Sector"), #sector.Planets + 1),
        Model = "models/crazycanadian/space/sol/earth.mdl",
        Diameter = 12000,
        OrbitRadius = 0.2 + #sector.Planets * 0.18,
    }
    self:RefreshGalaxyPlanetEditor()
end

function PANEL:OpenPlanetEditor(index, planet)
    local sector = self.GalaxyFocusedSector
    if not istable(sector) or not istable(planet) then return end

    local frame = vgui.Create("DFrame")
    frame:SetSize(420, 260)
    frame:Center()
    frame:SetTitle("Edit Planet")
    frame:MakePopup()
    frame:SetDeleteOnClose(true)

    local nameEntry = CreateStyledEntry(frame, "Planet name")
    nameEntry:SetPos(16, 40)
    nameEntry:SetSize(388, 32)
    nameEntry:SetText(tostring(planet.Name or "Planet"))

    local orbitEntry = CreateStyledEntry(frame, "Orbit radius / location")
    orbitEntry:SetPos(16, 80)
    orbitEntry:SetSize(388, 32)
    orbitEntry:SetText(tostring(planet.OrbitRadius or 0))

    local diameterEntry = CreateStyledEntry(frame, "Diameter")
    diameterEntry:SetPos(16, 120)
    diameterEntry:SetSize(388, 32)
    diameterEntry:SetText(tostring(planet.Diameter or 0))

    local modelEntry = CreateStyledCombo(frame)
    modelEntry:SetPos(16, 160)
    modelEntry:SetSize(388, 32)
    modelEntry:SetEditable(true)
    modelEntry:SetValue(tostring(planet.Model or "models/crazycanadian/space/sol/earth.mdl"))
    for _, modelPath in ipairs({
        "models/crazycanadian/space/sol/earth.mdl",
        "models/crazycanadian/space/sol/mars.mdl",
        "models/crazycanadian/space/sol/venus.mdl",
        "models/crazycanadian/space/sol/jupiter.mdl",
        "models/crazycanadian/space/sol/luna.mdl",
        "models/crazycanadian/space/generic/star.mdl",
    }) do
        modelEntry:AddChoice(modelPath, modelPath)
    end

    local saveButton = CreateStyledButton(frame, "Save", Color(145, 220, 175, 255))
    saveButton:SetPos(214, 206)
    saveButton:SetSize(90, 28)
    saveButton.DoClick = function()
        sector.Planets = istable(sector.Planets) and sector.Planets or {}
        sector.Planets[index] = sector.Planets[index] or {}
        sector.Planets[index].Name = string.Trim(nameEntry:GetText() or "")
        sector.Planets[index].OrbitRadius = tonumber(orbitEntry:GetText()) or tonumber(sector.Planets[index].OrbitRadius) or 0
        sector.Planets[index].Diameter = tonumber(diameterEntry:GetText()) or tonumber(sector.Planets[index].Diameter) or 0
        sector.Planets[index].Model = tostring(modelEntry:GetText() or modelEntry:GetValue() or sector.Planets[index].Model or "")
        if sector.Planets[index].Name == "" then
            sector.Planets[index].Name = string.format("%s Planet %d", tostring(sector.Name or "Sector"), index)
        end
        self:RefreshGalaxyPlanetEditor()
        frame:Close()
    end

    local cancelButton = CreateStyledButton(frame, "Cancel", Color(220, 120, 120, 255))
    cancelButton:SetPos(310, 206)
    cancelButton:SetSize(90, 28)
    cancelButton.DoClick = function()
        frame:Close()
    end
end

function PANEL:ExportFocusedGalaxySector()
    local sector = self.GalaxyFocusedSector
    if not istable(sector) then return end
    sector.Planets = istable(sector.Planets) and sector.Planets or BuildPlanetsFromSector(sector)

    local payload = util.TableToJSON({
        Name = sector.Name,
        Class = sector.Class,
        X = sector.X,
        Y = sector.Y,
        Planets = CopyTable(sector.Planets),
    }, true)

    if payload then
        SetClipboardText(payload)
        if IsValid(self.GalaxyStatus) then
            self.GalaxyStatus:SetText("Focused sector JSON copied to clipboard")
            self.GalaxyStatus:SizeToContentsX()
        end
    end
end

function PANEL:OnDataUpdated(state)
    state = state or {}
    local clock = state.clock or {}

    self.ClockStatus:SetText("Status: " .. (tobool(clock.clockedIn) and "Clocked In" or "Clocked Out"))
    self.ClockStatus:SizeToContents()

    self.ClockButton:SetButtonText(tobool(clock.clockedIn) and "Clock Out" or "Clock In")
    self.RankDetail:SetText("GM Rank: " .. tostring(clock.rankName or "Unknown"))
    self.RankDetail:SizeToContents()

    if IsValid(self.UtilityTarget) then
        self.UtilityTarget:Clear()
        for _, playerData in ipairs(state.onlinePlayers or {}) do
            local display = string.format("%s (%s)", tostring(playerData.name or "Unknown"), tostring(playerData.characterName or "No Character"))
            self.UtilityTarget:AddChoice(display, playerData.steamID64)
        end
    end

    if IsValid(self.OverviewList) then
        self.OverviewList:Clear()
        local rows = {
            "Galaxy map is available from this F4 Game Master menu.",
            "Game Master permissions are independent from roleplay/admin systems.",
            "Clock In enables GM tools and action logging."
        }
        for _, text in ipairs(rows) do
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
    end

    if IsValid(self.LogList) then
        self.LogList:Clear()
        for _, logEntry in ipairs(state.logs or {}) do
            local row = CreateCard(self.LogList)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 8)
            row:SetTall(92)

            local header = vgui.Create("DLabel", row)
            header:SetFont("LeopardRP.Menu.Small")
            header:SetTextColor(Color(240, 246, 255, 245))
            header:SetText(string.format("%s | %s | %s", tostring(logEntry.steamName or "Unknown"), FormatActionText(logEntry.action), tostring(logEntry.targetName or "No target")))
            header:SetWrap(true)
            header:SetAutoStretchVertical(true)

            local detailsText = BuildGMLogDetails(logEntry.details)
            if detailsText == "" then
                detailsText = "No additional details."
            end

            local details = vgui.Create("DLabel", row)
            details:SetFont("LeopardRP.Menu.Micro")
            details:SetTextColor(Color(255, 181, 118, 235))
            details:SetWrap(true)
            details:SetAutoStretchVertical(true)
            details:SetText(detailsText)

            local footer = vgui.Create("DLabel", row)
            footer:SetFont("LeopardRP.Menu.Micro")
            footer:SetTextColor(Color(190, 210, 232, 230))
            footer:SetText(string.format("%s %s | Stardate %s", tostring(logEntry.date or ""), tostring(logEntry.time or ""), tostring(logEntry.stardate or "")))
            footer:SetWrap(true)
            footer:SetAutoStretchVertical(true)

            row.PerformLayout = function(panel, w)
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
end

vgui.Register("LeopardRPGameMasterMenu", PANEL, "EditablePanel")

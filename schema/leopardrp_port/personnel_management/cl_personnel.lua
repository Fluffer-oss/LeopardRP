LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.Personnel = LeopardRP.Personnel or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Personnel = LeopardRP.Personnel

Personnel.State = Personnel.State or {
    Directory = {},
    CharacterList = {},
    CharacterDetails = nil,
    Logs = {},
    StaffRanks = {},
    SecondaryRanks = {},
    Roster = {},
    Training = {},
    PermissionManagement = {},
    DevMode = {},
    MenuAccess = {}
}

local keyDownState = {}
local activeSelectorFrame = nil
local pendingMenuAccessTarget = nil

local function SetMenuInteractionEnabled(enabled)
    if LeopardRP.VR and LeopardRP.VR.SetMenuInteractionEnabled then
        LeopardRP.VR:SetMenuInteractionEnabled(enabled)
        return
    end

    gui.EnableScreenClicker(enabled == true)
end

function Personnel.OpenHelixInventory()
    local client = LocalPlayer()
    if not IsValid(client) or not client.GetCharacter or not client:GetCharacter() then
        return false
    end

    function Personnel.OpenItemSpawner()
        if (!IsValid(LocalPlayer()) or !LocalPlayer():IsAdmin()) then
            return false
        end

        if (IsValid(Personnel.ItemSpawnerFrame)) then
            Personnel.ItemSpawnerFrame:Remove()
        end

        local frame = vgui.Create("DFrame")
        frame:SetTitle("LeopardRP Item Spawner")
        frame:SetSize(math.min(980, ScrW() * 0.72), math.min(680, ScrH() * 0.78))
        frame:Center()
        frame:MakePopup()
        SetMenuInteractionEnabled(true)

        local panel = frame:Add("LeopardRPGMItemSpawner")
        panel:Dock(FILL)

        Personnel.ItemSpawnerFrame = frame

        frame.OnRemove = function()
            if (Personnel.ItemSpawnerFrame == frame) then
                Personnel.ItemSpawnerFrame = nil
            end

            SetMenuInteractionEnabled(false)
        end

        return true
    end

    if not IsValid(ix.gui.menu) then
        vgui.Create("ixMenu")
    end

    if not IsValid(ix.gui.menu) or not IsValid(ix.gui.menu.tabs) then
        return false
    end

    for _, button in ipairs(ix.gui.menu.tabs.buttons or {}) do
        if tostring(button.name or "") == "inv" then
            button:SetSelected(true)
            ix.gui.menu:TransitionSubpanel(button.id)
            return true
        end
    end

    return false
end

local function RequestOpenMainMenu()
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.RequestMainMenu then
        LeopardRP.CharacterCreation.RequestMainMenu()
        return
    end

    if LeopardRP.VR and LeopardRP.VR.OpenMainMenu then
        LeopardRP.VR:OpenMainMenu()
        return
    end

    if IsValid(ix and ix.gui and ix.gui.menu) then
        ix.gui.menu:Remove()
    end

    vgui.Create("ixMenu")
end

local function RequestOpenCharacterSelection()
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.RequestCharacterSelection then
        LeopardRP.CharacterCreation.RequestCharacterSelection()
        return
    end

    if LeopardRP.VR and LeopardRP.VR.OpenCharacterSelection then
        LeopardRP.VR:OpenCharacterSelection()
        return
    end

    if IsValid(ix and ix.gui and ix.gui.menu) then
        ix.gui.menu:Remove()
    end

    vgui.Create("ixCharMenu")
end

local function RequestOpenInventory()
    Personnel.OpenHelixInventory()
end

local function CycleVoiceRange()
    if LeopardRP.Combadge and LeopardRP.Combadge.CycleVoiceMode then
        LeopardRP.Combadge:CycleVoiceMode()
    end
end

local function NotifyPersonnel(message)
    local text = string.Trim(tostring(message or ""))
    if text == "" then return end

    chat.AddText(Color(80, 180, 255), "[LeopardRP Personnel] ", color_white, text)
end

local function CloseSelectorFrame()
    if IsValid(activeSelectorFrame) then
        activeSelectorFrame:Remove()
    end

    activeSelectorFrame = nil
end

local function OpenSelectorFrame(titleText, subtitleText, choices)
    if not istable(choices) or #choices <= 0 then
        return
    end

    if #choices == 1 and isfunction(choices[1].onSelect) then
        choices[1].onSelect()
        return
    end

    CloseSelectorFrame()

    local frame = vgui.Create("DFrame")
    frame:SetSize(math.min(520, ScrW() * 0.34), 212)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(true)
    frame:SetDraggable(false)
    frame:MakePopup()
    SetMenuInteractionEnabled(true)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(12, 16, 24, 240))
        surface.SetDrawColor(255, 255, 255, 110)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText(titleText or "Select Menu", "Trebuchet24", 16, 14, Color(230, 240, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(subtitleText or "Choose which panel to open.", "Trebuchet18", 16, 44, Color(185, 205, 235), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    frame.OnRemove = function()
        if activeSelectorFrame == frame then
            activeSelectorFrame = nil
        end

        SetMenuInteractionEnabled(false)
    end

    activeSelectorFrame = frame

    local combo = vgui.Create("DComboBox", frame)
    combo:SetPos(16, 78)
    combo:SetSize(frame:GetWide() - 32, 30)
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.StyleComboBox then
        LeopardRP.CharacterCreation.StyleComboBox(combo)
    end

    local choiceByName = {}
    for _, choice in ipairs(choices) do
        local label = tostring(choice.label or "Option")
        combo:AddChoice(label)
        choiceByName[label] = choice
    end
    combo:ChooseOptionID(1)

    local openButton = vgui.Create("LeopardRPMenuButton", frame)
    openButton:SetText("")
    openButton:SetButtonText("Open")
    if openButton.SetAccentColor then
        openButton:SetAccentColor(Color(145, 215, 255, 255))
    end
    openButton:SetPos(16, 124)
    openButton:SetSize(frame:GetWide() - 32, 36)
    openButton.DoClick = function()
        local selected = choiceByName[tostring(combo:GetValue() or "")]
        if selected and isfunction(selected.onSelect) then
            selected.onSelect()
        end

        frame:Remove()
    end

    local cancelButton = vgui.Create("LeopardRPMenuButton", frame)
    cancelButton:SetText("")
    cancelButton:SetButtonText("Cancel")
    cancelButton:SetPos(16, 166)
    cancelButton:SetSize(frame:GetWide() - 32, 28)
    cancelButton.DoClick = function()
        frame:Remove()
    end
end

function Personnel.RequestMenuAccess(target)
    pendingMenuAccessTarget = tostring(target or "")
    net.Start(Personnel.NetworkStrings.RequestMenuAccess)
    net.SendToServer()
end

function Personnel.OpenStaffMenuSelector(access)
    local canGM = access and access.canGameMasterMenu == true

    if not canGM then
        NotifyPersonnel("You do not have access to the Game Master menu.")
        return
    end

    local choices = {}
    if canGM then
        table.insert(choices, {
            label = "Game Master Menu",
            onSelect = function()
                if LeopardRP.GameMaster and LeopardRP.GameMaster.RequestOpenMenu then
                    LeopardRP.GameMaster.RequestOpenMenu()
                end
            end
        })
    end

    OpenSelectorFrame("Staff Utility", "Select the staff panel you want to open.", choices)
end

function Personnel.OpenPersonnelMenuSelector(access)
    local canCrew = access and access.canCrewManager == true

    if not canCrew then
        NotifyPersonnel("You do not have access to Crew Manager.")
        return
    end

    local choices = {}
    if canCrew then
        table.insert(choices, {
            label = "Crew Manager",
            onSelect = function()
                Personnel.RequestCrewManager()
            end
        })
    end

    OpenSelectorFrame("Personnel Utility", "Select the personnel panel you want to open.", choices)
end

local keybindCache = {
    NextRefresh = 0,
    MainMenu = KEY_NONE,
    CharacterSelection = KEY_NONE,
    GameMasterMenu = KEY_NONE,
    PersonnelMenu = KEY_NONE,
    InventoryOpen = KEY_NONE,
    VoiceRangeCycle = KEY_NONE,
    CrewManager = KEY_NONE,
    TrainingManagement = KEY_NONE,
}
local keybindActionMap = {}

local function BindAction(keyCode, action)
    if not keyCode or keyCode <= 0 then
        return
    end

    if not isfunction(action) then
        return
    end

    if not isfunction(keybindActionMap[keyCode]) then
        keybindActionMap[keyCode] = action
        return
    end

    local previous = keybindActionMap[keyCode]
    keybindActionMap[keyCode] = function()
        previous()
        action()
    end
end

local function refreshKeybindCache()
    keybindCache.MainMenu = Personnel.GetBoundKey("main_menu")
    keybindCache.CharacterSelection = Personnel.GetBoundKey("character_selection")
    keybindCache.GameMasterMenu = Personnel.GetBoundKey("game_master_menu")
    keybindCache.PersonnelMenu = Personnel.GetBoundKey("personnel_menu")
    keybindCache.InventoryOpen = Personnel.GetBoundKey("inventory_open")
    keybindCache.VoiceRangeCycle = Personnel.GetBoundKey("voice_range_cycle")
    keybindCache.CrewManager = Personnel.GetBoundKey("crew_manager")
    keybindCache.TrainingManagement = Personnel.GetBoundKey("training_management")

    keybindActionMap = {}
    BindAction(keybindCache.MainMenu, RequestOpenMainMenu)
    BindAction(keybindCache.CharacterSelection, RequestOpenCharacterSelection)
    BindAction(keybindCache.InventoryOpen, RequestOpenInventory)
    BindAction(keybindCache.VoiceRangeCycle, CycleVoiceRange)

    BindAction(keybindCache.GameMasterMenu, function()
        Personnel.RequestMenuAccess("staff")
    end)

    BindAction(keybindCache.PersonnelMenu, function()
        Personnel.RequestMenuAccess("personnel")
    end)

    BindAction(keybindCache.CrewManager, function()
        Personnel.RequestCrewManager()
    end)

    BindAction(keybindCache.TrainingManagement, function()
        if Personnel.CanAccessTrainingManagement and Personnel.CanAccessTrainingManagement(LocalPlayer()) then
            Personnel.PendingInitialPage = "training"
            Personnel.RequestCrewManager()
        end
    end)

    keybindCache.NextRefresh = CurTime() + 0.25
end

local function runKeybindAction(keyCode, action)
    if not keyCode or keyCode <= 0 then
        return
    end

    local isDown = input.IsKeyDown(keyCode)
    local wasDown = keyDownState[keyCode] == true

    if isDown and not wasDown then
        action()
    end

    keyDownState[keyCode] = isDown
end

local keybindByActionID = {}
for _, keybindAction in ipairs(Personnel.KeybindActions or {}) do
    keybindByActionID[tostring(keybindAction.ID or "")] = keybindAction
end

function Personnel.GetBoundKey(actionID)
    local actionData = keybindByActionID[tostring(actionID or "")]
    if not actionData then return KEY_NONE end

    local defaultValue = tonumber(actionData.Default) or KEY_NONE
    local keyValue = tonumber(cookie.GetString("LeopardRP.Keybind." .. tostring(actionData.ID), tostring(defaultValue))) or defaultValue
    if keyValue <= 0 then
        return KEY_NONE
    end

    return keyValue
end

function Personnel.SetBoundKey(actionID, keyCode)
    local actionData = keybindByActionID[tostring(actionID or "")]
    if not actionData then return end

    local normalized = tonumber(keyCode) or KEY_NONE
    if normalized < 0 then
        normalized = KEY_NONE
    end

    cookie.Set("LeopardRP.Keybind." .. tostring(actionData.ID), tostring(normalized))
end

local function ReadJSONPayload()
    local isCompressed = net.ReadBool()
    if isCompressed then
        local length = net.ReadUInt(32)
        local compressed = net.ReadData(length)
        return util.JSONToTable(util.Decompress(compressed) or "{}") or {}
    end

    return util.JSONToTable(net.ReadString() or "{}") or {}
end

function Personnel.RequestCrewManager()
    net.Start(Personnel.NetworkStrings.RequestCrewManager)
    net.SendToServer()
end

function Personnel.RequestAdminPanel()
    NotifyPersonnel("Administration panel has been removed. Use ULX for administrative actions.")
end

function Personnel.RequestDirectory(mode, searchText)
    net.Start(Personnel.NetworkStrings.RequestDirectory)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(searchText or ""))
    net.SendToServer()
end

function Personnel.RequestCharacterList(mode, steamID64)
    net.Start(Personnel.NetworkStrings.RequestCharacterList)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(steamID64 or ""))
    net.SendToServer()
end

function Personnel.RequestCharacterDetails(mode, steamID64, characterID)
    net.Start(Personnel.NetworkStrings.RequestCharacterDetails)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(steamID64 or ""))
    net.WriteString(tostring(characterID or ""))
    net.SendToServer()
end

function Personnel.SubmitAction(payload)
    net.Start(Personnel.NetworkStrings.SubmitAction)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.RequestLogs(searchText, categoryFilter, sortMode)
    net.Start(Personnel.NetworkStrings.RequestLogs)
    net.WriteString(tostring(searchText or ""))
    net.WriteString(tostring(categoryFilter or "all"))
    net.WriteString(tostring(sortMode or "newest"))
    net.SendToServer()
end

function Personnel.RequestStaffRanks(searchText)
    net.Start(Personnel.NetworkStrings.RequestStaffRanks)
    net.WriteString(tostring(searchText or ""))
    net.SendToServer()
end

function Personnel.SetStaffRank(steamID64, staffRank)
    net.Start(Personnel.NetworkStrings.SetStaffRank)
    net.WriteString(tostring(steamID64 or ""))
    net.WriteString(tostring(staffRank or "none"))
    net.SendToServer()
end

function Personnel.RequestSecondaryRanks(mode, steamID64, characterID, searchText)
    net.Start(Personnel.NetworkStrings.RequestSecondaryRanks)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(steamID64 or ""))
    net.WriteString(tostring(characterID or ""))
    net.WriteString(tostring(searchText or ""))
    net.SendToServer()
end

function Personnel.CreateSecondaryRank(payload)
    net.Start(Personnel.NetworkStrings.CreateSecondaryRank)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.SetCharacterSecondaryRank(payload)
    net.Start(Personnel.NetworkStrings.SetCharacterSecondaryRank)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.RequestRoster(mode, searchText, filters, sortKey, sortDirection)
    net.Start(Personnel.NetworkStrings.RequestRoster)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(searchText or ""))
    net.WriteString(util.TableToJSON(filters or {}, false) or "{}")
    net.WriteString(tostring(sortKey or "rank"))
    net.WriteString(tostring(sortDirection or "desc"))
    net.SendToServer()
end

function Personnel.RequestTrainingManagement(mode, steamID64, characterID, searchText)
    net.Start(Personnel.NetworkStrings.RequestTrainingManagement)
    net.WriteString(tostring(mode or "crew"))
    net.WriteString(tostring(steamID64 or ""))
    net.WriteString(tostring(characterID or ""))
    net.WriteString(tostring(searchText or ""))
    net.SendToServer()
end

function Personnel.RequestPermissionManagement(mode, steamID64, characterID)
    net.Start(Personnel.NetworkStrings.RequestPermissionManagement)
    net.WriteString(tostring(mode or "admin"))
    net.WriteString(tostring(steamID64 or ""))
    net.WriteString(tostring(characterID or ""))
    net.SendToServer()
end

function Personnel.SavePermissionManagement(payload)
    net.Start(Personnel.NetworkStrings.SavePermissionManagement)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.RequestDevModeSettings()
    net.Start(Personnel.NetworkStrings.RequestDevModeSettings)
    net.SendToServer()
end

function Personnel.SaveDevModeSettings(payload)
    net.Start(Personnel.NetworkStrings.SaveDevModeSettings)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.RequestLogisticsSettings()
    net.Start(Personnel.NetworkStrings.RequestLogisticsSettings)
    net.SendToServer()
end

function Personnel.SaveLogisticsSettings(payload)
    net.Start(Personnel.NetworkStrings.SaveLogisticsSettings)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.UpdateRosterRecord(payload)
    net.Start(Personnel.NetworkStrings.UpdateRosterRecord)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.UpdateTrainingRecord(payload)
    net.Start(Personnel.NetworkStrings.UpdateTrainingRecord)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.AddDossierEntry(payload)
    net.Start(Personnel.NetworkStrings.AddDossierEntry)
    net.WriteString(util.TableToJSON(payload or {}, false) or "{}")
    net.SendToServer()
end

function Personnel.CloseActivePanel()
    if IsValid(Personnel.ActivePanel) then
        Personnel.ActivePanel:Remove()
    end

    Personnel.ActivePanel = nil
end

function Personnel.OpenPanel(panelClass)
    if LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.CloseActiveMenu then
        LeopardRP.CharacterCreation.CloseActiveMenu()
    end

    Personnel.CloseActivePanel()

    local panel = vgui.Create(panelClass)
    Personnel.ActivePanel = panel

    return panel
end

hook.Add("Think", "LeopardRP.Personnel.Keybinds", function()
    if gui.IsGameUIVisible() then return end
    if IsValid(vgui.GetKeyboardFocus()) then return end

    if CurTime() >= (keybindCache.NextRefresh or 0) then
        refreshKeybindCache()
    end

    for keyCode, action in pairs(keybindActionMap) do
        if keyCode == KEY_F3 then
            keyDownState[keyCode] = input.IsKeyDown(keyCode)
            continue
        end

        runKeybindAction(keyCode, action)
    end
end)

net.Receive(Personnel.NetworkStrings.OpenCrewManager, function()
    local panel = Personnel.OpenPanel("LeopardRPCrewManager")
    if IsValid(panel) and panel.SetTrainingOnlyMode then
        panel:SetTrainingOnlyMode(Personnel.PendingInitialPage == "training")
    end
    if IsValid(panel) and Personnel.PendingInitialPage and panel.SetPageMode then
        panel:SetPageMode(Personnel.PendingInitialPage)
    end
    Personnel.PendingInitialPage = nil
end)

net.Receive(Personnel.NetworkStrings.OpenAdminPanel, function()
    NotifyPersonnel("Administration panel is disabled on this server build.")
end)

net.Receive(Personnel.NetworkStrings.ReceiveMenuAccess, function()
    local payload = ReadJSONPayload()
    Personnel.State.MenuAccess = payload or {}

    if pendingMenuAccessTarget == "staff" then
        Personnel.OpenStaffMenuSelector(Personnel.State.MenuAccess)
    elseif pendingMenuAccessTarget == "personnel" then
        Personnel.OpenPersonnelMenuSelector(Personnel.State.MenuAccess)
    end

    pendingMenuAccessTarget = nil
end)

net.Receive(Personnel.NetworkStrings.ReceiveDirectory, function()
    local payload = ReadJSONPayload()
    Personnel.State.Directory = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnDirectoryData then
        Personnel.ActivePanel:OnDirectoryData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveCharacterList, function()
    local payload = ReadJSONPayload()
    Personnel.State.CharacterList = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnCharacterListData then
        Personnel.ActivePanel:OnCharacterListData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveCharacterDetails, function()
    local payload = ReadJSONPayload()
    Personnel.State.CharacterDetails = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnCharacterDetailsData then
        Personnel.ActivePanel:OnCharacterDetailsData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveLogs, function()
    local payload = ReadJSONPayload()
    Personnel.State.Logs = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnLogsData then
        Personnel.ActivePanel:OnLogsData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveStaffRanks, function()
    local payload = ReadJSONPayload()
    Personnel.State.StaffRanks = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnStaffRanksData then
        Personnel.ActivePanel:OnStaffRanksData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveSecondaryRanks, function()
    local payload = ReadJSONPayload()
    Personnel.State.SecondaryRanks = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnSecondaryRanksData then
        Personnel.ActivePanel:OnSecondaryRanksData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveRoster, function()
    local payload = ReadJSONPayload()
    Personnel.State.Roster = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnRosterData then
        Personnel.ActivePanel:OnRosterData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveTrainingManagement, function()
    local payload = ReadJSONPayload()
    Personnel.State.Training = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnTrainingData then
        Personnel.ActivePanel:OnTrainingData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceivePermissionManagement, function()
    local payload = ReadJSONPayload()
    Personnel.State.PermissionManagement = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnPermissionManagementData then
        Personnel.ActivePanel:OnPermissionManagementData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveDevModeSettings, function()
    local payload = ReadJSONPayload()
    Personnel.State.DevMode = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnDevModeData then
        Personnel.ActivePanel:OnDevModeData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.ReceiveLogisticsSettings, function()
    local payload = ReadJSONPayload()
    Personnel.State.LogisticsSettings = payload

    if IsValid(Personnel.ActivePanel) and Personnel.ActivePanel.OnLogisticsSettingsData then
        Personnel.ActivePanel:OnLogisticsSettingsData(payload)
    end
end)

net.Receive(Personnel.NetworkStrings.Notification, function()
    local message = net.ReadString() or ""
    if message ~= "" then
        chat.AddText(Color(80, 180, 255), "[LeopardRP Personnel] ", color_white, message)
    end
end)

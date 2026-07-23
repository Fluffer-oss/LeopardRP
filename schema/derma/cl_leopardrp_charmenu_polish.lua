local MAIN_MENU_CAMERA_VIEWS = {
    {
        origin = Vector(-6736.23, 2710.89, 1596.24),
        angles = Angle(24.84, -32.55, 0),
        fov = 78,
    },
    {
        origin = Vector(-1164.37, -760.03, 284.99),
        angles = Angle(9.40, 17.59, 0),
        fov = 78,
    },
    {
        origin = Vector(8353.92, -3382.90, 610.55),
        angles = Angle(16.93, 141.28, 0),
        fov = 78,
    },
    {
        origin = Vector(-103.30, 295.61, 13441.89),
        angles = Angle(15.60, -105.68, 0),
        fov = 78,
    },
    {
        origin = Vector(-370.63, 3.37, 13457.55),
        angles = Angle(16.27, -0.76, 0),
        fov = 78,
    },
    {
        origin = Vector(-163.17, -238.95, 13457.55),
        angles = Angle(14.55, 49.93, 0),
        fov = 78,
    },
}

local function getMenuCameraOrigins()
    local origins = {}

    for index = 1, #MAIN_MENU_CAMERA_VIEWS do
        local view = MAIN_MENU_CAMERA_VIEWS[index]

        if (view and view.origin) then
            origins[#origins + 1] = view.origin
        end
    end

    return origins
end

local MENU_ICON_TARGET_HEIGHT = 220
local MENU_ICON_TOP = 82
local MENU_TITLE_GAP = 14
local MENU_TITLE_X_OFFSET = -22
local MENU_TITLE_Y_OFFSET = -8
local MID_BAR_HEIGHT = 34

-- Menu tuning values (edit these only).
local MENU_TUNING = {
    newsPanel = {
        widthScale = 0.81,
        heightScale = 0.17,
        minWidth = 240,
        maxWidth = 580,
        minHeight = 220,
        maxHeight = 490,
        rightMargin = 50,
        bottomMargin = 356,
    },
    background = {
        overlayAlpha = 150,
        blurMax = 6,
    }
}

local function layoutEmbeddedNewsPanel(menu)
    if (!IsValid(menu) or !IsValid(menu.mainPanel) or !IsValid(menu.leopardEmbeddedNews)) then
        return
    end

    local tune = MENU_TUNING.newsPanel
    local parent = menu.mainPanel
    local width = math.floor(math.Clamp(parent:GetWide() * tune.widthScale, tune.minWidth, tune.maxWidth))
    local height = math.floor(math.Clamp(parent:GetTall() * tune.heightScale, tune.minHeight, tune.maxHeight))
    local x = parent:GetWide() - width - tune.rightMargin
    local y = parent:GetTall() - height - tune.bottomMargin

    menu.leopardEmbeddedNews:SetSize(width, height)
    menu.leopardEmbeddedNews:SetPos(x, y)
end

local function ensureEmbeddedNewsPanel(menu)
    if (!IsValid(menu) or !IsValid(menu.mainPanel)) then
        return
    end

    if (!IsValid(menu.leopardEmbeddedNews)) then
        local newsPanel = menu.mainPanel:Add("LeopardRPNewsPanel")
        newsPanel:SetZPos(5)
        menu.leopardEmbeddedNews = newsPanel
    end

    layoutEmbeddedNewsPanel(menu)
end

local cachedServerIcon
local attemptedServerIconResolve = false

local function getServerIconMaterial()
    if (attemptedServerIconResolve) then
        return cachedServerIcon
    end

    attemptedServerIconResolve = true

    local candidates = {
        "ui/logo",
        "ui/logo.png",
        "ui/icon24",
        "ui/icon24.png",
        "ui/server_icon",
        "ui/server_icon.png"
    }

    for _, path in ipairs(candidates) do
        local material = Material(path, "smooth")

        if (material and !material:IsError()) then
            cachedServerIcon = material
            break
        end
    end

    return cachedServerIcon
end

local function findHeaderPanel(mainPanel)
    for _, child in ipairs(mainPanel:GetChildren()) do
        if (IsValid(child) and child ~= mainPanel.mainButtonList and child:GetWide() >= ScrW() * 0.9 and child:GetTall() > 60) then
            return child
        end
    end

    return nil
end

local function compactHeader(mainPanel)
    local headerPanel = findHeaderPanel(mainPanel)

    if (!IsValid(headerPanel)) then
        return
    end

    headerPanel:SetVisible(false)

    for _, child in ipairs(headerPanel:GetChildren()) do
        if (IsValid(child)) then
            child:SetVisible(false)
        end
    end
end

local function applyCharacterLabelPolish(root)
    if (!IsValid(root) or !root.GetChildren) then
        return
    end

    for _, child in ipairs(root:GetChildren() or {}) do
        if (IsValid(child) and child.GetText and child.SetText) then
            local currentText = tostring(child:GetText() or "")
            local upperText = string.upper(currentText)

            if (string.find(upperText, "DEFINE YOUR NARRATIVE", 1, true)) then
                child:SetText("NARRATIVE")
                if (child.SizeToContentsY) then
                    child:SizeToContentsY()
                end
            elseif (upperText == "DESCRIPTION") then
                local x, y = child:GetPos()
                child:SetPos(x, y + 12)
            end
        end

        applyCharacterLabelPolish(child)
    end
end

local function getBestCharacterID()
    local bestID
    local bestJoinTime = -1

    for _, characterID in ipairs(ix.characters or {}) do
        local character = ix.char.loaded and ix.char.loaded[characterID]

        if (character) then
            local joinedAt = tonumber(character:GetLastJoinTime(0)) or 0

            if (joinedAt > bestJoinTime) then
                bestJoinTime = joinedAt
                bestID = characterID
            end
        end
    end

    if (!bestID) then
        bestID = ix.characters and ix.characters[1] or nil
    end

    return bestID
end

local function continueCharacter()
    local characterID = getBestCharacterID()

    if (!characterID) then
        return false
    end

    net.Start("ixCharacterChoose")
        net.WriteUInt(characterID, 32)
    net.SendToServer()

    return true
end

local function getMenuCameraHoldDuration(index)
    if (index == 1) then
        return 5
    elseif (index == 2) then
        return 3
    end

    return math.Rand(8, 15)
end

local function isInstantCameraCut(fromIndex, toIndex)
    return (fromIndex == 3 and toIndex == 4) or (fromIndex == 6 and toIndex == 1)
end

local function buildBackgroundPainter()
    local currentViewIndex = 1
    local lastSentViewIndex = 0
    local holdStartedAt = CurTime()
    local holdDuration = getMenuCameraHoldDuration(currentViewIndex)
    local transitionStartedAt
    local transitionDuration = math.Rand(8, 15)
    local transitionFromView
    local transitionToView
    local transitioning = false
    local menuPVSPoints = getMenuCameraOrigins()

    local function sendMenuCameraPVS(points)
        if (!istable(points)) then
            return
        end

        net.Start("LeopardRP.UpdateMenuCameraPVS")
            net.WriteTable(points)
        net.SendToServer()
    end

    return function(self, width, height)
        local now = CurTime()
        local currentView = MAIN_MENU_CAMERA_VIEWS[currentViewIndex] or MAIN_MENU_CAMERA_VIEWS[1]

        if (lastSentViewIndex ~= currentViewIndex) then
            lastSentViewIndex = currentViewIndex
            sendMenuCameraPVS(menuPVSPoints)
        end

        local view = currentView

        if (transitioning) then
            local transitionElapsed = now - transitionStartedAt
            local fraction = transitionDuration > 0 and math.Clamp(transitionElapsed / transitionDuration, 0, 1) or 1

            if (transitionFromView and transitionToView and fraction > 0 and fraction < 1) then
                view = {
                    origin = LerpVector(fraction, transitionFromView.origin, transitionToView.origin),
                    angles = LerpAngle(fraction, transitionFromView.angles, transitionToView.angles),
                    fov = Lerp(fraction, transitionFromView.fov or 78, transitionToView.fov or 78),
                }
            else
                transitioning = false
                currentViewIndex = currentViewIndex + 1

                if (currentViewIndex > #MAIN_MENU_CAMERA_VIEWS) then
                    currentViewIndex = 1
                end

                holdStartedAt = now
                holdDuration = getMenuCameraHoldDuration(currentViewIndex)
                lastSentViewIndex = currentViewIndex - 1

                if (currentViewIndex == 1) then
                    lastSentViewIndex = #MAIN_MENU_CAMERA_VIEWS
                end

                currentView = MAIN_MENU_CAMERA_VIEWS[currentViewIndex] or currentView
                view = currentView

                if (lastSentViewIndex ~= currentViewIndex) then
                    lastSentViewIndex = currentViewIndex
                    sendMenuCameraPVS(menuPVSPoints)
                end
            end
        else
            local elapsed = now - holdStartedAt

            if (elapsed >= holdDuration) then
                local nextViewIndex = currentViewIndex + 1

                if (nextViewIndex > #MAIN_MENU_CAMERA_VIEWS) then
                    nextViewIndex = 1
                end

                local nextView = MAIN_MENU_CAMERA_VIEWS[nextViewIndex] or currentView

                if (isInstantCameraCut(currentViewIndex, nextViewIndex)) then
                    currentViewIndex = nextViewIndex
                    holdStartedAt = now
                    holdDuration = getMenuCameraHoldDuration(currentViewIndex)
                    lastSentViewIndex = currentViewIndex - 1

                    if (currentViewIndex == 1) then
                        lastSentViewIndex = #MAIN_MENU_CAMERA_VIEWS
                    end

                    currentView = nextView
                    view = currentView

                    if (lastSentViewIndex ~= currentViewIndex) then
                        lastSentViewIndex = currentViewIndex
                        sendMenuCameraPVS(menuPVSPoints)
                    end
                else
                    transitioning = true
                    transitionStartedAt = now
                    transitionFromView = currentView
                    transitionToView = nextView
                    transitionDuration = math.Rand(18, 24)
                end
            end
        end

        if (view) then
            render.RenderView({
                x = 0,
                y = 0,
                w = width,
                h = height,
                origin = view.origin,
                angles = view.angles,
                fov = view.fov or 78,
                drawviewmodel = false,
                drawhud = false,
                dopostprocess = true,
            })
        end

        -- Darken the backdrop so text remains readable without relying on heavy blur.
        surface.SetDrawColor(0, 0, 0, MENU_TUNING.background.overlayAlpha)
        surface.DrawRect(0, 0, width, height)

        if (!ix.option.Get("cheapBlur", false)) then
            self.currentAlpha = tonumber(self.currentAlpha) or 255
            ix.util.DrawBlur(self, Lerp((self.currentAlpha - 200) / 255, 0, MENU_TUNING.background.blurMax))
        end
    end
end

hook.Add("OnCharacterMenuCreated", "LeopardRP.CharMenuPolish", function(menu)
    if (!IsValid(menu)) then
        return
    end

    menu.Paint = buildBackgroundPainter()

    local oldOnRemove = menu.OnRemove

    menu.OnRemove = function(this)
        net.Start("LeopardRP.UpdateMenuCameraPVS")
            net.WriteTable({})
        net.SendToServer()

        if (oldOnRemove) then
            oldOnRemove(this)
        end
    end

    timer.Simple(0, function()
        if (!IsValid(menu) or !IsValid(menu.mainPanel) or !IsValid(menu.mainPanel.mainButtonList)) then
            return
        end

        ensureEmbeddedNewsPanel(menu)

        local mainPanel = menu.mainPanel
        local list = mainPanel.mainButtonList

        compactHeader(mainPanel)

        local oldMainPanelPaint = mainPanel.Paint
        mainPanel.Paint = function(this, width, height)
            if (oldMainPanelPaint) then
                oldMainPanelPaint(this, width, height)
            end

            -- The character loader supplies its own compact scanner header. Keep the
            -- large menu identity treatment off the 3D personnel preview.
            if (IsValid(menu.loadCharacterPanel) and menu.loadCharacterPanel.bActive) then
                return
            end

            local serverIcon = getServerIconMaterial()

            if (serverIcon) then
                local sourceWidth = math.max(1, serverIcon:Width())
                local sourceHeight = math.max(1, serverIcon:Height())
                local scale = MENU_ICON_TARGET_HEIGHT / sourceHeight
                local iconWidth = math.max(24, math.floor(sourceWidth * scale))
                local iconX = math.floor((width - iconWidth) * 0.5)
                local iconY = MENU_ICON_TOP
                local iconCenterY = iconY + math.floor(MENU_ICON_TARGET_HEIGHT * 0.5)
                local barY = iconCenterY - math.floor(MID_BAR_HEIGHT * 0.5)
                local accent = ix.config.Get("color") or Color(75, 119, 190, 255)

                -- Single centered bar behind the icon to create mirrored left/right wings.
                surface.SetDrawColor(accent.r, accent.g, accent.b, 120)
                surface.DrawRect(0, barY, width, MID_BAR_HEIGHT)
                surface.SetDrawColor(255, 255, 255, 38)
                surface.DrawRect(0, barY, width, 1)
                surface.DrawRect(0, barY + MID_BAR_HEIGHT - 1, width, 1)

                surface.SetMaterial(serverIcon)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(iconX, iconY, iconWidth, MENU_ICON_TARGET_HEIGHT)

                local titleY = iconY + MENU_ICON_TARGET_HEIGHT + MENU_TITLE_GAP + MENU_TITLE_Y_OFFSET
                draw.SimpleText("Leopard RP", "LeopardRP.Menu.Title", math.floor(width * 0.5) + MENU_TITLE_X_OFFSET, titleY, Color(236, 242, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            end
        end

        if (IsValid(mainPanel.loadButton)) then
            mainPanel.loadButton:SetText("characters")
            mainPanel.loadButton:SizeToContents()
        end

        for _, child in ipairs(list:GetCanvas():GetChildren()) do
            if (IsValid(child) and type(child.text) == "string") then
                if (child.text == "create") then
                    child:SetText("create character")
                    child:SizeToContents()
                elseif (child.text == "leave") then
                    child:SetText("disconnect")
                    child:SizeToContents()
                elseif (child.text == "news") then
                    child:Remove()
                end
            end
        end

        if (!IsValid(list.leopardContinueButton)) then
            local continueButton = list:Add("ixMenuButton")
            continueButton:SetText("continue")
            continueButton:SizeToContents()
            continueButton:SetZPos(-100)
            continueButton.DoClick = function()
                if (!continueCharacter()) then
                    menu:ShowNotice(3, L("unknownError"))
                end
            end

            list.leopardContinueButton = continueButton
        end

        if (IsValid(list.leopardContinueButton)) then
            list:InvalidateLayout(true)
            list:SizeToContents()
            mainPanel:InvalidateLayout(true)
        end

        if (IsValid(menu.newCharacterPanel)) then
            applyCharacterLabelPolish(menu.newCharacterPanel)
            timer.Simple(0, function()
                if (IsValid(menu.newCharacterPanel)) then
                    applyCharacterLabelPolish(menu.newCharacterPanel)
                end
            end)
        end
    end)
end)

hook.Add("Think", "LeopardRP.CharMenuNewsLayout", function()
    local menu = ix.gui.characterMenu

    if (IsValid(menu) and IsValid(menu.leopardEmbeddedNews)) then
        layoutEmbeddedNewsPanel(menu)
    end
end)

hook.Add("HUDShouldDraw", "LeopardRP.DisableHUDInMenus", function(name)
    if (IsValid(ix.gui.characterMenu) or IsValid(ix.gui.menu)) then
        return false
    end
end)

local PANEL = {}

local function getServerIconMaterial()
    local candidates = {
        "ui/server_icon",
        "ui/server_icon.png"
    }

    for _, path in ipairs(candidates) do
        local material = Material(path, "smooth")

        if (material and !material:IsError()) then
            return material
        end
    end

    return nil
end

local function canOfferVREnable()
    if not (LeopardRP and LeopardRP.VR and LeopardRP.VR.IsAvailable and LeopardRP.VR:IsAvailable()) then
        return false
    end

    if LeopardRP.VR.IsPlayerInVR and LeopardRP.VR:IsPlayerInVR(LocalPlayer()) then
        return false
    end

    if vrmod and isfunction(vrmod.GetTrackedDeviceNames) then
        local devices = vrmod.GetTrackedDeviceNames()
        return istable(devices) and next(devices) ~= nil
    end

    return true
end

function PANEL:Init()
    self:Dock(FILL)
    self:DockMargin(24, 24, 24, 24)

    self.serverIcon = getServerIconMaterial()
    self.actionButtons = {}

    self.left = self:Add("DPanel")
    self.left:Dock(LEFT)
    self.left:SetWide(math.floor(ScrW() * 0.28))
    self.left.Paint = function(_, width, height)
        draw.RoundedBox(12, 0, 0, width, height, Color(10, 16, 28, 235))
        surface.SetDrawColor(255, 255, 255, 24)
        surface.DrawOutlinedRect(0, 0, width, height, 1)
    end

    self.right = self:Add("DPanel")
    self.right:Dock(FILL)
    self.right:DockMargin(16, 0, 0, 0)
    self.right.Paint = function(_, width, height)
        draw.RoundedBox(12, 0, 0, width, height, Color(8, 12, 20, 205))

        surface.SetDrawColor(255, 255, 255, 24)
        surface.DrawOutlinedRect(0, 0, width, height, 1)

        if (self.serverIcon and !self.serverIcon:IsError()) then
            surface.SetMaterial(self.serverIcon)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(24, 22, 72, 72)
        end

        draw.SimpleText("LeopardRP", "LeopardRP.Menu.Title", 108, 24, Color(235, 242, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

    self.newsPanel = self.right:Add("LeopardRPNewsPanel")
    self.newsPanel:Dock(FILL)
    self.newsPanel:DockMargin(14, 108, 14, 14)

    self.buttonList = self.left:Add("DListLayout")
    self.buttonList:Dock(FILL)
    self.buttonList:DockMargin(12, 12, 12, 12)

    local function continueCharacter()
        local characterMenu = ix.gui.characterMenu

        if (IsValid(characterMenu) and IsValid(characterMenu.mainPanel) and IsValid(characterMenu.mainPanel.loadButton)) then
            characterMenu.mainPanel.loadButton:DoClick()
            return
        end

        if (IsValid(ix.gui.menu)) then
            ix.gui.menu:Remove()
        end

        vgui.Create("ixCharMenu")
    end

    local buttons = {
        {
            label = "Continue",
            onClick = continueCharacter
        },
        {
            label = "Characters",
            onClick = function()
                local characterMenu = ix.gui.characterMenu

                if (IsValid(characterMenu) and IsValid(characterMenu.mainPanel) and IsValid(characterMenu.mainPanel.loadButton)) then
                    characterMenu.mainPanel.loadButton:DoClick()
                else
                    if (IsValid(ix.gui.menu)) then
                        ix.gui.menu:Remove()
                    end

                    vgui.Create("ixCharMenu")
                end
            end
        },
        {
            label = "Settings",
            onClick = function()
                if (IsValid(ix.gui.menu)) then
                    ix.gui.menu:TransitionSubpanel("settings")
                end
            end
        },
        {
            label = "Discord",
            onClick = function()
                gui.OpenURL("https://discord.gg/7XUrywCGKU")
            end
        },
        {
            label = "Disconnect",
            onClick = function()
                LocalPlayer():ConCommand("disconnect")
            end
        }
    }

    if canOfferVREnable() then
        table.insert(buttons, 4, {
            label = "Enable VR",
            onClick = function()
                RunConsoleCommand("vrmod_start")
            end
        })
    end

    for _, entry in ipairs(buttons) do
        local button = self.buttonList:Add("DButton")
        button:Dock(TOP)
        button:DockMargin(0, 0, 0, 8)
        button:SetTall(40)
        button:SetText("")

        button.Paint = function(this, width, height)
            local base = this:IsHovered() and Color(28, 50, 82, 255) or Color(18, 30, 48, 255)
            draw.RoundedBox(8, 0, 0, width, height, base)

            surface.SetDrawColor(255, 255, 255, 18)
            surface.DrawOutlinedRect(0, 0, width, height, 1)

            draw.SimpleText(entry.label, "LeopardRP.Menu.Button", 14, height * 0.5, Color(240, 246, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        button.DoClick = entry.onClick
        self.actionButtons[#self.actionButtons + 1] = button
    end
end

function PANEL:PerformLayout(width, height)
    local leftWidth = math.Clamp(math.floor(width * 0.30), 260, 430)

    if (IsValid(self.left)) then
        self.left:SetWide(leftWidth)
    end
end

vgui.Register("ixLeopardRPMenu", PANEL, "DPanel")

hook.Add("CreateCharacterInfo", "LeopardRPCharacterInfo", function(panel)
    local character = LocalPlayer():GetCharacter()

    if (!character) then
        return
    end

    local rows = {
        {label = "Species", value = character:GetSpecies("Human")},
        {label = "Gender", value = character:GetGender("Male")},
        {label = "Division", value = character:GetDivision("Starfleet Academy")},
        {label = "Uniform", value = character:GetUniformType("Standard")}
    }

    for _, rowData in ipairs(rows) do
        local row = panel:Add("ixListRow")
        row:SetList(panel.list)
        row:Dock(TOP)
        row:SetLabelText(rowData.label)
        row:SetText(tostring(rowData.value or ""))
        row:SizeToContents()
    end
end)

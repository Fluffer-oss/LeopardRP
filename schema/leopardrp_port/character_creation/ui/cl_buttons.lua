LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Theme = LeopardRP.CharacterCreation.Theme

local PANEL = {}

function PANEL:Init()
    self.HoverLerp = 0
    self.PressLerp = 0
    self:SetText("")
end

function PANEL:SetButtonText(text)
    self.ButtonText = text or ""
end

function PANEL:SetAccentColor(color)
    self.AccentColor = color
end

function PANEL:Paint(w, h)
    local isHovered = self:IsHovered()
    self.HoverLerp = Lerp(FrameTime() * 10, self.HoverLerp or 0, isHovered and 1 or 0)
    self.PressLerp = Lerp(FrameTime() * 16, self.PressLerp or 0, self.Depressed and 1 or 0)

    local baseColor = Theme.PanelBackground
    local hoverColor = Theme.PanelBackgroundHover
    local pressColor = Theme.PanelBackgroundPress

    local fillColor = baseColor
    if self.PressLerp > 0.01 then
        fillColor = Color(
            Lerp(self.PressLerp, baseColor.r, pressColor.r),
            Lerp(self.PressLerp, baseColor.g, pressColor.g),
            Lerp(self.PressLerp, baseColor.b, pressColor.b),
            Lerp(self.PressLerp, baseColor.a, pressColor.a)
        )
    elseif self.HoverLerp > 0.01 then
        fillColor = Color(
            Lerp(self.HoverLerp, baseColor.r, hoverColor.r),
            Lerp(self.HoverLerp, baseColor.g, hoverColor.g),
            Lerp(self.HoverLerp, baseColor.b, hoverColor.b),
            Lerp(self.HoverLerp, baseColor.a, hoverColor.a)
        )
    end

    local outlineColor = self.HoverLerp > 0 and Color(255, 255, 255, 210) or Theme.Outline
    draw.RoundedBox(Theme.PanelRadius, 0, 0, w, h, fillColor)
    surface.SetDrawColor(outlineColor)
    surface.DrawOutlinedRect(0, 0, w, h, Theme.ButtonOutlineWidth)

    if self.AccentColor then
        surface.SetDrawColor(self.AccentColor.r, self.AccentColor.g, self.AccentColor.b, 18)
        surface.DrawRect(2, 2, w - 4, h - 4)
    end

    draw.SimpleText(self.ButtonText or self:GetText() or "", "LeopardRP.Menu.Button", w * 0.5, h * 0.5, Color(255, 255, 255, 240 + self.HoverLerp * 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("LeopardRPMenuButton", PANEL, "DButton")

local ICON_PANEL = {}

function ICON_PANEL:Init()
    self.HoverLerp = 0
    self.IconText = ""
end

function ICON_PANEL:SetIconText(text)
    self.IconText = text or ""
end

function ICON_PANEL:Paint(w, h)
    self.HoverLerp = Lerp(FrameTime() * 14, self.HoverLerp or 0, self:IsHovered() and 1 or 0)
    local scale = Lerp(self.HoverLerp, 1, Theme.IconScaleHover)

    draw.RoundedBox(Theme.PanelRadiusSmall, 0, 0, w, h, Color(14, 18, 26, 205))
    surface.SetDrawColor(Theme.Outline)
    surface.DrawOutlinedRect(0, 0, w, h, 2)

    local iconSize = math.min(w, h) * scale * 0.42
    draw.SimpleText(self.IconText, "LeopardRP.Menu.Small", w * 0.5, h * 0.5, Color(255, 255, 255, 220 + self.HoverLerp * 35), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

vgui.Register("LeopardRPToolbarIcon", ICON_PANEL, "DButton")

function LeopardRP.CharacterCreation.CreateNavButton(parent, text, onClick)
    local button = vgui.Create("LeopardRPMenuButton", parent)
    button:SetText("")
    button:SetButtonText(text)
    button.DoClick = onClick
    return button
end

function LeopardRP.CharacterCreation.CreateIconButton(parent, text, onClick)
    local button = vgui.Create("LeopardRPToolbarIcon", parent)
    button:SetText("")
    button:SetIconText(text)
    button.DoClick = onClick
    return button
end
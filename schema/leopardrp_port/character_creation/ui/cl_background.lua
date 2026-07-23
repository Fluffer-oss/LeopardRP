LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

local Theme = LeopardRP.CharacterCreation.Theme or {}

function LeopardRP.CharacterCreation.CreateFullscreenRoot(backgroundMaterialPath, parent)
    local root = vgui.Create("EditablePanel", parent)
    root:SetSize(ScrW(), ScrH())
    root:SetPos(0, 0)
    root:SetMouseInputEnabled(true)
    root:SetKeyboardInputEnabled(true)
    root.BackgroundMaterial = Material(backgroundMaterialPath, "smooth mips")

    root.Paint = function(panel, w, h)
        LeopardRP.CharacterCreation.PaintBackground(panel, w, h)
    end

    return root
end

function LeopardRP.CharacterCreation.CreateMenuFrame(backgroundMaterialPath)
    return LeopardRP.CharacterCreation.CreateFullscreenRoot(backgroundMaterialPath)
end

function LeopardRP.CharacterCreation.DrawPanelShadow(x, y, w, h, alpha)
    draw.RoundedBox(Theme.PanelRadius or 18, x + 2, y + 4, w, h, Color(0, 0, 0, alpha or 80))
end

function LeopardRP.CharacterCreation.DrawRoundedPanel(x, y, w, h, fillColor, outlineColor, outlineWidth, radius)
    draw.RoundedBox(radius or Theme.PanelRadius or 18, x, y, w, h, fillColor)
    surface.SetDrawColor(outlineColor or Theme.Outline or Color(255, 255, 255, 180))
    surface.DrawOutlinedRect(x, y, w, h, outlineWidth or 2)
end

function LeopardRP.CharacterCreation.StylePanel(panel)
    if not IsValid(panel) then return end
    panel.Paint = function(_, w, h)
        draw.RoundedBox(Theme.PanelRadius or 18, 0, 0, w, h, Color(15, 15, 15, 190))
        surface.SetDrawColor(255, 255, 255, 140)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

function LeopardRP.CharacterCreation.PaintBackground(panel, w, h)
    if not IsValid(panel) or not panel.BackgroundMaterial then return end

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(panel.BackgroundMaterial)
    surface.DrawTexturedRect(0, 0, w, h)
    surface.SetDrawColor(4, 6, 10, 130)
    surface.DrawRect(0, 0, w, h)
end

function LeopardRP.CharacterCreation.DrawCardBackground(x, y, w, h, alpha)
    draw.RoundedBox(18, x, y, w, h, Color(16, 24, 36, alpha or 180))
end

function LeopardRP.CharacterCreation.StyleButton(button, accentColor)
    if not IsValid(button) then return end

    button:SetTextColor(Color(255, 255, 255))
    button.Paint = function(_, w, h)
        draw.RoundedBox(16, 0, 0, w, h, Color(14, 18, 26, button:IsEnabled() and 210 or 120))
        surface.SetDrawColor(button:IsEnabled() and Color(255, 255, 255, 180) or Color(255, 255, 255, 90))
        surface.DrawOutlinedRect(0, 0, w, h, 2)

        if accentColor then
            surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, 24)
            surface.DrawRect(1, 1, w - 2, h - 2)
        end
    end
end

function LeopardRP.CharacterCreation.StyleTextEntry(entry)
    if not IsValid(entry) then return end

    entry:SetTextColor(Color(255, 255, 255))
    if entry.SetCaretColor then
        entry:SetCaretColor(Color(255, 255, 255))
    end
    entry.Paint = function(_, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(14, 18, 26, 220))
        surface.SetDrawColor(255, 255, 255, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        entry:DrawTextEntryText(Color(255, 255, 255), Color(140, 180, 255), Color(255, 255, 255))
    end
end

function LeopardRP.CharacterCreation.StyleComboBox(comboBox)
    if not IsValid(comboBox) then return end

    comboBox:SetTextColor(Color(255, 255, 255))
    comboBox.Paint = function(_, w, h)
        draw.RoundedBox(14, 0, 0, w, h, Color(14, 18, 26, 220))
        surface.SetDrawColor(255, 255, 255, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end

function LeopardRP.CharacterCreation.StyleLabel(label, alpha)
    if not IsValid(label) then return end

    label:SetTextColor(Color(255, 255, 255, alpha or 255))
end
-- Compatibility patch layer for Helix UI assumptions.
-- This avoids hard crashes when panel animation state is missing during early lifecycle frames.

local function patchSegmentedProgress()
    local panelTable = vgui.GetControlTable("ixSegmentedProgress")

    if (!panelTable or panelTable._leopardPatched) then
        return
    end

    local baseSizeToContents = panelTable.SizeToContents

    panelTable.SizeToContents = function(self)
        local fontName = self.font

        if (!isstring(fontName) or fontName == "") then
            local skin = self.GetSkin and self:GetSkin()
            fontName = skin and skin.fontSegmentedProgress or "ixSmallFont"
        end

        if (!isstring(fontName) or fontName == "") then
            fontName = "DermaDefault"
        end

        self.font = fontName

        if (baseSizeToContents) then
            return baseSizeToContents(self)
        end

        self:SetTall(draw.GetFontHeight(fontName) + (self.padding or 0))
    end

    panelTable._leopardPatched = true
end

local function patchCharMenu()
    local panelTable = vgui.GetControlTable("ixCharMenu")

    if (!panelTable or panelTable._leopardPatched) then
        return
    end

    local basePaint = panelTable.Paint

    panelTable.Paint = function(self, width, height)
        self.currentAlpha = tonumber(self.currentAlpha) or 255

        if (basePaint) then
            return basePaint(self, width, height)
        end
    end

    panelTable._leopardPatched = true
end

local function patchIxMenuNoTabSound()
    local panelTable = vgui.GetControlTable("ixMenu")

    if (!panelTable or panelTable._leopardTabSoundPatched) then
        return
    end

    panelTable.Think = function(self)
        if (IsValid(self.projectedTexture)) then
            local forward = LocalPlayer():GetForward()
            forward.z = 0

            local right = LocalPlayer():GetRight()
            right.z = 0

            self.projectedTexture:SetBrightness(self.overviewFraction * 4)
            self.projectedTexture:SetPos(LocalPlayer():GetPos() + right * 16 - forward * 8 + self.projectedTexturePosition)
            self.projectedTexture:SetAngles(forward:Angle() + self.projectedTextureRotation)
            self.projectedTexture:Update()
        end

        if (self.bClosing) then
            return
        end

        local bTabDown = input.IsKeyDown(KEY_TAB)

        if (bTabDown and (self.noAnchor or CurTime() + 0.4) < CurTime() and self.anchorMode) then
            self.anchorMode = false
        end

        if ((!self.anchorMode and !bTabDown) or gui.IsGameUIVisible()) then
            self:Remove()

            if (ix.option.Get("escCloseMenu", false)) then
                gui.HideGameUI()
            end
        end
    end

    panelTable._leopardTabSoundPatched = true
end

hook.Add("InitPostEntity", "LeopardRP.HelixMenuCompat", function()
    patchSegmentedProgress()
    patchCharMenu()
    patchIxMenuNoTabSound()
end)

hook.Add("OnReloaded", "LeopardRP.HelixMenuCompatReload", function()
    patchSegmentedProgress()
    patchCharMenu()
    patchIxMenuNoTabSound()
end)

patchSegmentedProgress()
patchCharMenu()
patchIxMenuNoTabSound()

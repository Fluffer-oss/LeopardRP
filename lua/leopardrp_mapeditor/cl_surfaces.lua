local MapEditor = LeopardRPMapEditor

local HighlightColor = Color(255, 220, 40, 180)
local ExistingColor = Color(80, 220, 255, 180)

local EditState = {
    active = false,
    pending = nil, -- sanitized entry table currently shown in the panel, or nil
    pendingIsNew = true
}

local EditorFrame = nil
local EditorPanel = nil -- the per-surface sub-panel inside EditorFrame

local function AttachMaterialObjects()
    for _, entry in pairs(MapEditor.SurfaceOverrides) do
        entry.materialObj = Material(entry.material)
    end
end

net.Receive(MapEditor.NetSync, function()
    local list = util.JSONToTable(net.ReadString() or "[]") or {}
    MapEditor.SurfaceOverrides = MapEditor.DeserializeSurfaceOverrides(list)
    AttachMaterialObjects()
end)

local LastActionFeedback = nil
net.Receive(MapEditor.NetAction, function()
    local payload = util.JSONToTable(net.ReadString() or "{}") or {}
    LastActionFeedback = payload

    if IsValid(LocalPlayer()) then
        chat.AddText(
            payload.ok and Color(120, 255, 120) or Color(255, 120, 120),
            "[Map Editor] ",
            color_white,
            tostring(payload.message or "")
        )
    end
end)

local function SendAction(actionType, extra)
    local payload = table.Copy(istable(extra) and extra or {})
    payload.type = actionType

    net.Start(MapEditor.NetAction)
    net.WriteString(util.TableToJSON(payload))
    net.SendToServer()
end

-- UVs match the corner order from MapEditor.BuildSurfaceQuadCorners
-- (bottom-left, top-left, top-right, bottom-right).
local QuadUVs = { { 0, 1 }, { 0, 0 }, { 1, 0 }, { 1, 1 } }

local function DrawQuad(corners, materialObj, color, normal)
    if not materialObj then return end

    render.SetMaterial(materialObj)
    mesh.Begin(MATERIAL_QUAD, 1)
        for i, corner in ipairs(corners) do
            mesh.Position(corner)
            mesh.Normal(normal)
            mesh.TexCoord(0, QuadUVs[i][1], QuadUVs[i][2])
            mesh.Color(color.r, color.g, color.b, color.a)
            mesh.AdvanceVertex()
        end
    mesh.End()
end

local function DrawOutline(corners, color)
    for i = 1, 4 do
        local a = corners[i]
        local b = corners[(i % 4) + 1]
        render.DrawLine(a, b, color, true)
    end
end

hook.Add("PostDrawOpaqueRenderables", "LeopardRPMapEditor.DrawSurfaces", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local eyePos = ply:EyePos()

    for _, entry in pairs(MapEditor.SurfaceOverrides) do
        if eyePos:DistToSqr(entry.pos) <= (4096 * 4096) then
            local corners = MapEditor.BuildSurfaceQuadCorners(entry)
            DrawQuad(corners, entry.materialObj, entry.color, entry.normal)
        end
    end

    if EditState.active and EditState.pending then
        local pending = EditState.pending
        local corners = MapEditor.BuildSurfaceQuadCorners(pending)
        DrawQuad(corners, Material(pending.material), pending.color, pending.normal)
        DrawOutline(corners, EditState.pendingIsNew and HighlightColor or ExistingColor)
    end
end)

local function FindNearestOverride(pos, maxDistance)
    local nearestID, nearestDist = nil, maxDistance * maxDistance
    for id, entry in pairs(MapEditor.SurfaceOverrides) do
        local distSqr = entry.pos:DistToSqr(pos)
        if distSqr <= nearestDist then
            nearestID, nearestDist = id, distSqr
        end
    end
    return nearestID
end

local function RefreshEditorPanelContents()
    if not IsValid(EditorPanel) then return end
    EditorPanel:Clear(true)

    if not EditState.pending then
        local label = vgui.Create("DLabel", EditorPanel)
        label:SetText("Left-click a world surface to add or edit an override.\nRight-click an existing override to remove it.")
        label:SetWrap(true)
        label:SetAutoStretchVertical(true)
        label:Dock(TOP)
        return
    end

    local pending = EditState.pending

    local header = vgui.Create("DLabel", EditorPanel)
    header:SetText(EditState.pendingIsNew and "New surface override" or "Editing existing override")
    header:SetFont("DermaDefaultBold")
    header:Dock(TOP)
    header:DockMargin(0, 0, 0, 4)

    local textureLabel = vgui.Create("DLabel", EditorPanel)
    textureLabel:SetText("Original texture: " .. (pending.originalTexture ~= "" and pending.originalTexture or "unknown"))
    textureLabel:Dock(TOP)
    textureLabel:DockMargin(0, 0, 0, 4)

    local materialEntry = vgui.Create("DTextEntry", EditorPanel)
    materialEntry:Dock(TOP)
    materialEntry:SetValue(pending.material)
    materialEntry:DockMargin(0, 0, 0, 4)

    local preview = vgui.Create("DImage", EditorPanel)
    preview:SetSize(64, 64)
    preview:Dock(TOP)
    preview:DockMargin(0, 0, 0, 4)
    preview:SetImage(pending.material)

    materialEntry.OnValueChange = function(_, value)
        pending.material = tostring(value or "")
        preview:SetImage(pending.material)
    end

    local function AddSlider(label, key, min, max, decimals)
        local slider = vgui.Create("DNumSlider", EditorPanel)
        slider:Dock(TOP)
        slider:DockMargin(0, 0, 0, 4)
        slider:SetText(label)
        slider:SetMin(min)
        slider:SetMax(max)
        slider:SetDecimals(decimals or 0)
        slider:SetValue(pending[key])
        slider.OnValueChanged = function(_, value)
            pending[key] = value
        end
    end

    AddSlider("Width", "width", 1, 512, 0)
    AddSlider("Height", "height", 1, 512, 0)
    AddSlider("Rotation", "rotation", 0, 360, 0)
    AddSlider("Offset", "offset", 0, 8, 2)

    local mixer = vgui.Create("DColorMixer", EditorPanel)
    mixer:Dock(TOP)
    mixer:SetTall(130)
    mixer:DockMargin(0, 0, 0, 4)
    mixer:SetAlphaBar(true)
    mixer:SetPalette(false)
    mixer:SetColor(Color(pending.color.r, pending.color.g, pending.color.b, pending.color.a))
    mixer.ValueChanged = function(_, color)
        pending.color = { r = color.r, g = color.g, b = color.b, a = color.a }
    end

    local buttonRow = vgui.Create("DPanel", EditorPanel)
    buttonRow:Dock(TOP)
    buttonRow:SetTall(28)
    buttonRow:DockMargin(0, 4, 0, 0)
    buttonRow.Paint = function() end

    local saveButton = vgui.Create("DButton", buttonRow)
    saveButton:SetText("Save")
    saveButton:Dock(LEFT)
    saveButton:SetWide(80)
    saveButton.DoClick = function()
        SendAction(EditState.pendingIsNew and "add" or "update", {
            id = pending.id,
            entry = MapEditor.SurfaceEntryToTable(pending)
        })
    end

    if not EditState.pendingIsNew then
        local removeButton = vgui.Create("DButton", buttonRow)
        removeButton:SetText("Remove")
        removeButton:Dock(LEFT)
        removeButton:SetWide(80)
        removeButton:DockMargin(4, 0, 0, 0)
        removeButton.DoClick = function()
            SendAction("remove", { id = pending.id })
            EditState.pending = nil
            RefreshEditorPanelContents()
        end
    end

    local cancelButton = vgui.Create("DButton", buttonRow)
    cancelButton:SetText("Cancel")
    cancelButton:Dock(LEFT)
    cancelButton:SetWide(80)
    cancelButton:DockMargin(4, 0, 0, 0)
    cancelButton.DoClick = function()
        EditState.pending = nil
        RefreshEditorPanelContents()
    end
end

local function OpenEditorFrame()
    if IsValid(EditorFrame) then return end

    EditorFrame = vgui.Create("DFrame")
    EditorFrame:SetSize(320, 480)
    EditorFrame:SetPos(ScrW() - 340, 80)
    EditorFrame:SetTitle("LeopardRP Map Editor — Surfaces")
    EditorFrame:SetDeleteOnClose(true)
    EditorFrame:MakePopup()
    EditorFrame:SetSizable(true)
    EditorFrame.OnClose = function()
        EditState.active = false
    end

    local toolbar = vgui.Create("DPanel", EditorFrame)
    toolbar:Dock(TOP)
    toolbar:SetTall(28)
    toolbar.Paint = function() end

    local function AddToolbarButton(text, onClick)
        local button = vgui.Create("DButton", toolbar)
        button:SetText(text)
        button:Dock(LEFT)
        button:SetWide(68)
        button:DockMargin(0, 0, 4, 0)
        button.DoClick = onClick
    end

    AddToolbarButton("Reload", function() SendAction("reload") end)
    AddToolbarButton("Reset All", function() SendAction("reset") end)
    AddToolbarButton("Undo", function() SendAction("undo") end)
    AddToolbarButton("Redo", function() SendAction("redo") end)

    EditorPanel = vgui.Create("DScrollPanel", EditorFrame)
    EditorPanel:Dock(FILL)
    EditorPanel:DockMargin(0, 4, 0, 0)

    RefreshEditorPanelContents()
end

local function CloseEditorFrame()
    if IsValid(EditorFrame) then
        EditorFrame:Close()
    end
    EditorFrame = nil
    EditorPanel = nil
end

local function SetEditModeActive(active)
    if not MapEditor.CanUseEditor(LocalPlayer()) then
        chat.AddText(Color(255, 120, 120), "[Map Editor] You do not have permission to use this tool.")
        return
    end

    EditState.active = active
    EditState.pending = nil

    if active then
        OpenEditorFrame()
    else
        CloseEditorFrame()
    end
end

concommand.Add("leopardrp_mapeditor_surface_toggle", function()
    SetEditModeActive(not EditState.active)
end)

hook.Add("PlayerBindPress", "LeopardRPMapEditor.InterceptClicks", function(ply, bind, pressed)
    if not EditState.active or not pressed then return end
    if ply ~= LocalPlayer() then return end

    bind = string.lower(bind)
    if bind ~= "+attack" and bind ~= "+attack2" then return end

    local trace = ply:GetEyeTrace()

    if bind == "+attack2" then
        if trace.HitWorld then
            SendAction("remove", { pos = { x = trace.HitPos.x, y = trace.HitPos.y, z = trace.HitPos.z } })
        end
        return true
    end

    if not trace.HitWorld then return true end

    local nearestID = FindNearestOverride(trace.HitPos, MapEditor.RemoveSnapDistance)
    if nearestID and MapEditor.SurfaceOverrides[nearestID] then
        local existing = MapEditor.SurfaceOverrides[nearestID]
        EditState.pending = MapEditor.SanitizeSurfaceEntry(MapEditor.SurfaceEntryToTable(existing), nearestID)
        EditState.pendingIsNew = false
    else
        EditState.pending = MapEditor.SanitizeSurfaceEntry({
            pos = { x = trace.HitPos.x, y = trace.HitPos.y, z = trace.HitPos.z },
            normal = { x = trace.HitNormal.x, y = trace.HitNormal.y, z = trace.HitNormal.z },
            material = trace.HitTexture or "",
            originalTexture = trace.HitTexture or "",
            width = 32,
            height = 32,
            offset = 0.3,
            rotation = 0,
            color = { r = 255, g = 255, b = 255, a = 255 }
        })
        EditState.pendingIsNew = true
    end

    RefreshEditorPanelContents()
    return true
end)

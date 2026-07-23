
-- Here is where all of your clientside hooks should go.

function Schema:CanCreateCharacterInfo(suppress)
	suppress.money = true
end

function Schema:CanPlayerViewInventory()
	return true
end

function Schema:BuildBusinessMenu()
	return false
end

local function getCurrentInventoryCharacterData()
	local client = LocalPlayer()
	if (!IsValid(client) or !client.GetCharacter) then
		return nil
	end

	local character = client:GetCharacter()
	if (!character) then
		return nil
	end

	return {
		bodyModel = tostring(character.GetBodyModel and character:GetBodyModel("") or client:GetModel() or ""),
		headModel = tostring(character.GetHeadModel and character:GetHeadModel("") or ""),
		rankID = tostring(character.GetData and character:GetData("leopardrpRankID", "cadet") or "cadet"),
		division = tostring(character.GetDivision and character:GetDivision("Starfleet Academy") or "Starfleet Academy"),
		uniformType = tostring(character.GetUniformType and character:GetUniformType("Standard") or "Standard"),
		headIndex = tonumber(character.GetHeadIndex and character:GetHeadIndex(1) or 1) or 1,
		handsHidden = tobool(character.GetData and character:GetData("leopardrpHandsHidden", false) or false),
	}
end

local function findEquipmentInventory(character, slotType)
	if (!character or !character.GetInventory) then
		return nil
	end

	for _, inventory in ipairs(character:GetInventory(true) or {}) do
		if (istable(inventory) and istable(inventory.vars)) then
			if (inventory.vars.leopardSlotType == slotType) then
				return inventory
			end

			if (slotType == "uniform" and inventory.vars.isBag == "leopardrp_uniform") then
				return inventory
			end

			if (slotType == "combadge" and inventory.vars.isBag == "leopardrp_combadge") then
				return inventory
			end
		end
	end

	return nil
end

local function createEquipmentInventoryPanel(parent, title, slotType, iconSize)
	local inventoryPanel = parent:Add("ixInventory")
	inventoryPanel:SetTitle(nil)
	inventoryPanel:ShowCloseButton(false)
	inventoryPanel:SetDraggable(false)
	inventoryPanel:SetSizable(false)
	inventoryPanel:SetIconSize(iconSize)
	inventoryPanel:SetVisible(false)
	inventoryPanel:SetMouseInputEnabled(true)
	inventoryPanel:SetKeyboardInputEnabled(false)
	inventoryPanel.Paint = function(_, width, height)
		local accent = slotType == "uniform" and Color(80, 126, 170, 108) or Color(116, 168, 198, 108)
		draw.RoundedBox(6, 0, 0, width, height, Color(18, 24, 33, 72))
		surface.SetDrawColor(255, 255, 255, 12)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
		draw.SimpleText(string.upper(tostring(title or "")), "LeopardRP.Menu.Micro", 8, 6, Color(230, 238, 246), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	end

	return inventoryPanel
end

local function buildInventoryEquipmentSidebar(panel)
	if (!IsValid(panel) or IsValid(panel.leopardEquipmentSidebar)) then
		return
	end

	local sidebar = panel:Add("DPanel")
	sidebar:Dock(RIGHT)
	sidebar:SetWide(math.max(340, math.floor(ScrW() * 0.25)))
	sidebar:SetZPos(20)
	sidebar.Paint = function(_, width, height)
		draw.RoundedBox(18, 0, 0, width, height, Color(16, 22, 32, 186))
		surface.SetDrawColor(255, 255, 255, 48)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	local header = sidebar:Add("DLabel")
	header:Dock(TOP)
	header:DockMargin(16, 12, 16, 0)
	header:SetFont("LeopardRP.Menu.PanelBold")
	header:SetTextColor(Color(236, 242, 250))
	header:SetText("PERSONAL EQUIPMENT")
	header:SetTall(20)

	local subHeader = sidebar:Add("DLabel")
	subHeader:Dock(TOP)
	subHeader:DockMargin(16, 2, 16, 10)
	subHeader:SetFont("LeopardRP.Menu.Micro")
	subHeader:SetTextColor(Color(162, 178, 198))
	subHeader:SetText("Uniform and combadge inventories")
	subHeader:SetTall(14)

	local previewFrame = sidebar:Add("DPanel")
	previewFrame:Dock(TOP)
	previewFrame:DockMargin(16, 0, 16, 10)
	previewFrame:SetTall(math.max(304, math.floor(ScrH() * 0.44)))
	previewFrame.Paint = function(_, width, height)
		draw.RoundedBox(18, 0, 0, width, height, Color(20, 28, 40, 118))
		surface.SetDrawColor(255, 255, 255, 26)
		surface.DrawOutlinedRect(0, 0, width, height, 1)
	end

	local preview = previewFrame:Add("LeopardRPCharacterPreview")
	preview:Dock(FILL)
	preview:DockMargin(0, 0, 0, 0)

	local overlay = previewFrame:Add("DPanel")
	overlay:Dock(FILL)
	overlay:SetZPos(50)
	overlay.Paint = nil

	local uniformInventoryPanel = createEquipmentInventoryPanel(overlay, "Uniform Grid", "uniform", 24)
	local combadgeInventoryPanel = createEquipmentInventoryPanel(overlay, "Combadge Grid", "combadge", 30)
	local glovesToggle = sidebar:Add("DCheckBoxLabel")
	glovesToggle:Dock(TOP)
	glovesToggle:DockMargin(16, 2, 16, 0)
	glovesToggle:SetText("Take off gloves")
	glovesToggle:SetFont("LeopardRP.Menu.Small")
	glovesToggle:SetTextColor(Color(220, 230, 242))
	glovesToggle:SetTall(18)
	glovesToggle:SetValue(false)

	local characterData = getCurrentInventoryCharacterData()
	if (characterData) then
		preview:SetCharacterData(characterData)
		preview:SetHandsHidden(characterData.handsHidden)
		glovesToggle:SetChecked(characterData.handsHidden)
	end

	glovesToggle.OnChange = function(_, bChecked)
		if (IsValid(preview)) then
			preview:SetHandsHidden(bChecked)
		end
	end

	local function bindEquipmentInventories()
		if (!IsValid(panel) or !IsValid(preview)) then
			return false
		end

		local client = LocalPlayer()
		local character = IsValid(client) and client.GetCharacter and client:GetCharacter() or nil
		if (!character) then
			return false
		end

		local uniformInventory = findEquipmentInventory(character, "uniform")
		local combadgeInventory = findEquipmentInventory(character, "combadge")
		if (!uniformInventory or !combadgeInventory) then
			return false
		end

		if (IsValid(uniformInventoryPanel) and uniformInventoryPanel.invID ~= uniformInventory:GetID()) then
			uniformInventoryPanel:SetInventory(uniformInventory)
			uniformInventoryPanel:SetVisible(true)
		end

		if (IsValid(combadgeInventoryPanel) and combadgeInventoryPanel.invID ~= combadgeInventory:GetID()) then
			combadgeInventoryPanel:SetInventory(combadgeInventory)
			combadgeInventoryPanel:SetVisible(true)
		end

		sidebar:InvalidateLayout(true)

		return true
	end

	timer.Create("LeopardRP.InventoryEquipmentBind." .. tostring(panel), 0.1, 60, function()
		if (bindEquipmentInventories()) then
			timer.Remove("LeopardRP.InventoryEquipmentBind." .. tostring(panel))
		end
	end)

	sidebar.PerformLayout = function(_, width, height)
		local previewHeight = math.max(304, math.floor(height * 0.52))
		previewFrame:SetTall(previewHeight)

		local previewWide = previewFrame:GetWide()
		local previewTall = previewFrame:GetTall()

		if (IsValid(uniformInventoryPanel)) then
			local iconSize = math.max(18, math.floor(math.min(previewWide * 0.22, previewTall * 0.12)))
			uniformInventoryPanel:SetIconSize(iconSize)
			uniformInventoryPanel:SetPos(math.floor(previewWide * 0.04), math.floor(previewTall * 0.38))
			uniformInventoryPanel:SetZPos(60)
			uniformInventoryPanel:SetMouseInputEnabled(true)
			uniformInventoryPanel:SetKeyboardInputEnabled(false)
			uniformInventoryPanel:SetSize(iconSize * 4 + 8, iconSize * 4 + uniformInventoryPanel:GetPadding(2) + uniformInventoryPanel:GetPadding(4))
		end

		if (IsValid(combadgeInventoryPanel)) then
			local iconSize = math.max(22, math.floor(math.min(previewWide * 0.09, previewTall * 0.1)))
			combadgeInventoryPanel:SetIconSize(iconSize)
			combadgeInventoryPanel:SetPos(math.floor(previewWide * 0.63), math.floor(previewTall * 0.33))
			combadgeInventoryPanel:SetZPos(61)
			combadgeInventoryPanel:SetMouseInputEnabled(true)
			combadgeInventoryPanel:SetKeyboardInputEnabled(false)
			combadgeInventoryPanel:SetSize(iconSize + 8, iconSize + combadgeInventoryPanel:GetPadding(2) + combadgeInventoryPanel:GetPadding(4))
		end
	end

	panel.leopardEquipmentSidebar = sidebar
	panel.leopardEquipmentPreview = preview
	panel.leopardEquipmentUniform = uniformInventoryPanel
	panel.leopardEquipmentCombadge = combadgeInventoryPanel
	panel.leopardEquipmentGlovesToggle = glovesToggle
	panel.leopardEquipmentPreviewFrame = previewFrame

	sidebar:InvalidateLayout(true)
	bindEquipmentInventories()
end

local function canUseDutyNoClipClient(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	if (LeopardRP.Personnel and LeopardRP.Personnel.IsForcedOwner and LeopardRP.Personnel.IsForcedOwner(client)) then
		return true
	end

	if (LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank and LeopardRP.GameMaster.HasRankAtLeast) then
		local gmRank = tostring(LeopardRP.GameMaster.GetPermissionRank(client:SteamID64()) or "none")
		local gmClock = LeopardRP.GameMaster.State and LeopardRP.GameMaster.State.clock or {}

		if (gmClock.clockedIn == true and LeopardRP.GameMaster.HasRankAtLeast(gmRank, "game_master")) then
			return true
		end
	end

	if (LeopardRP.Personnel and LeopardRP.Personnel.CanAccessAdminPanel and LeopardRP.Personnel.CanAccessAdminPanel(client)) then
		return true
	end

	return false
end

hook.Add("PlayerBindPress", "LeopardRP.BlockNoClipWhenOffDuty", function(client, bind, pressed)
	if (!pressed or !IsValid(client) or client ~= LocalPlayer()) then
		return
	end

	local lowerBind = string.lower(tostring(bind or ""))
	if (string.find(lowerBind, "noclip", 1, true) and !canUseDutyNoClipClient(client)) then
		return true
	end
end)

hook.Add("MenuSubpanelCreated", "LeopardRP.InventoryPanelLateInit", function(name, subpanel)
	if (name ~= "inv") then
		return
	end

	local timerID = "LeopardRP.InventoryPanelLateInit." .. tostring(LocalPlayer())

	timer.Create(timerID, 0.1, 30, function()
		if (!IsValid(ix.gui.inv1)) then
			return
		end

		if (ix.gui.inv1.invID and ix.gui.inv1.gridW and ix.gui.inv1.gridH and ix.gui.inv1.gridW > 1 and ix.gui.inv1.gridH > 1) then
			timer.Remove(timerID)
			return
		end

		local client = LocalPlayer()
		local character = IsValid(client) and client.GetCharacter and client:GetCharacter() or nil
		local inventory = character and character.GetInventory and character:GetInventory() or nil
		local validInventory = type(inventory) == "table"
			and type(inventory.GetID) == "function"
			and type(inventory.GetSize) == "function"
			and type(inventory.slots) == "table"

		if (validInventory) then
			ix.gui.inv1:SetInventory(inventory)
			timer.Remove(timerID)
		end
	end)

	buildInventoryEquipmentSidebar(subpanel)
end)

if (CLIENT) then
	if (ix and ix.option and ix.option.Add) then
		ix.option.Add("leopardDisableCrosshair", ix.type.bool, false, {
			category = "appearance"
		})
	end

	hook.Add("ShouldDrawCrosshair", "LeopardRP.Appearance.DisableCrosshair", function(client)
		if (ix and ix.option and ix.option.Get and ix.option.Get("leopardDisableCrosshair", false)) then
			return false
		end
	end)

	local hideEntityInfo = false
	local middleMouseWasDown = false

	hook.Add("Think", "LeopardRP.ToggleEntityInfoMiddleClick", function()
		if (gui and gui.IsGameUIVisible and gui.IsGameUIVisible()) then
			return
		end

		local isDown = input.IsMouseDown(MOUSE_MIDDLE)
		if (isDown and not middleMouseWasDown) then
			hideEntityInfo = not hideEntityInfo

			if (hideEntityInfo and IsValid(ix and ix.gui and ix.gui.entityInfo)) then
				ix.gui.entityInfo:Remove()
			end
		end

		middleMouseWasDown = isDown
	end)

	hook.Add("ShouldPopulateEntityInfo", "LeopardRP.ToggleEntityInfoVisibility", function()
		if (hideEntityInfo) then
			return false
		end
	end)
end

LeopardRP = LeopardRP or {}

local NET_REQ = "LeopardRP.InventoryDebugRequest"
local NET_RES = "LeopardRP.InventoryDebugResponse"
local NET_RESYNC_REQ = "LeopardRP.InventoryDebugResyncRequest"
local ENABLE_DEBUG_REPORTS = false

local function BoolStr(value)
	return value and "yes" or "no"
end

local function PrintReport(title, lines)
	if not ENABLE_DEBUG_REPORTS then
		return
	end

	local header = string.format("[LeopardRP][INVDBG] %s", tostring(title or "Report"))

	print(header)
	for _, line in ipairs(lines or {}) do
		print("  - " .. tostring(line))
	end

	if (CLIENT and chat and chat.AddText) then
		chat.AddText(Color(255, 200, 80), header)
		for _, line in ipairs(lines or {}) do
			chat.AddText(Color(225, 225, 225), "  - " .. tostring(line))
		end
	end
end

if (SERVER) then
	util.AddNetworkString(NET_REQ)
	util.AddNetworkString(NET_RES)
	util.AddNetworkString(NET_RESYNC_REQ)

	local function SendServerReport(client, lines)
		net.Start(NET_RES)
			net.WriteString("Server Report")
			net.WriteTable(lines or {})
		net.Send(client)
	end

	local function BuildServerInventoryReport(client)
		local out = {}

		local char = client:GetCharacter()
		table.insert(out, "player=" .. tostring(client:Nick()) .. " steamid64=" .. tostring(client:SteamID64()))
		table.insert(out, "character_valid=" .. BoolStr(char ~= nil))
		table.insert(out, "config_inventory_size=" .. tostring(ix.config.Get("inventoryWidth", 6)) .. "x" .. tostring(ix.config.Get("inventoryHeight", 4)))

		if (!char) then
			SendServerReport(client, out)
			return
		end

		local charID = tonumber(char:GetID() or 0) or 0
		table.insert(out, "character_id=" .. tostring(charID) .. " name=" .. tostring(char:GetName() or "unknown"))

		local mainInv = char.GetInventory and char:GetInventory() or nil
		local mainGetID = type(mainInv) == "table" and mainInv.GetID or nil
		local mainGetSize = type(mainInv) == "table" and mainInv.GetSize or nil
		local mainIter = type(mainInv) == "table" and mainInv.Iter or nil
		local mainValid = type(mainInv) == "table"
			and type(mainGetID) == "function"
			and type(mainGetSize) == "function"
			and type(mainIter) == "function"
			and type(mainInv.slots) == "table"
		table.insert(out, "main_inventory_valid=" .. BoolStr(mainValid))

		if (mainValid) then
			local w, h = mainGetSize(mainInv)
			local itemCount = 0
			for _, _ in mainIter(mainInv) do
				itemCount = itemCount + 1
			end

			table.insert(out, "main_inventory_id=" .. tostring(mainGetID(mainInv)) .. " size=" .. tostring(w) .. "x" .. tostring(h) .. " owner=" .. tostring(mainInv.owner or "nil") .. " items=" .. tostring(itemCount))
		else
			table.insert(out, "main_inventory_error=character:GetInventory() missing/invalid")
		end

		local invTable = char.GetInventory and char:GetInventory(true) or nil
		table.insert(out, "character.vars.inv_table_valid=" .. BoolStr(istable(invTable)))

		if (istable(invTable)) then
			local entryCount = 0
			for index, inv in pairs(invTable) do
				entryCount = entryCount + 1

				if (istable(inv) and inv.GetID and inv.GetSize) then
					local iw, ih = inv:GetSize()
					table.insert(out, string.format("vars.inv[%s]=id:%s size:%sx%s owner:%s", tostring(index), tostring(inv:GetID()), tostring(iw), tostring(ih), tostring(inv.owner or "nil")))
				else
					table.insert(out, string.format("vars.inv[%s]=INVALID type:%s value:%s", tostring(index), type(inv), tostring(inv)))
				end
			end

			table.insert(out, "character.vars.inv_entry_count=" .. tostring(entryCount))
		end

		if (charID <= 0) then
			SendServerReport(client, out)
			return
		end

		local query = mysql:Select("ix_inventories")
			query:Select("inventory_id")
			query:Select("character_id")
			query:Select("inventory_type")
			query:Where("character_id", charID)
			query:Callback(function(rows)
				rows = rows or {}
				table.insert(out, "db_ix_inventories_rows=" .. tostring(#rows))

				for i, row in ipairs(rows) do
					table.insert(out, string.format("db_row_%d=id:%s character_id:%s type:%s", i, tostring(row.inventory_id or "nil"), tostring(row.character_id or "nil"), tostring(row.inventory_type or "main")))
				end

				SendServerReport(client, out)
			end)
		query:Execute()
	end

	net.Receive(NET_REQ, function(_, client)
		if (!IsValid(client) or !client:IsPlayer()) then
			return
		end

		if not ENABLE_DEBUG_REPORTS then
			return
		end

		BuildServerInventoryReport(client)
	end)

	net.Receive(NET_RESYNC_REQ, function(_, client)
		if (!IsValid(client) or !client:IsPlayer()) then
			return
		end

		local character = client:GetCharacter()
		if (!character or !character.GetInventory) then
			return
		end

		local inventory = character:GetInventory()
		if (!inventory or !inventory.Sync) then
			return
		end

		character:Sync(client)
		inventory:AddReceiver(client)
		inventory:Sync(client)

		if ENABLE_DEBUG_REPORTS then
			timer.Simple(0.25, function()
				if (IsValid(client)) then
					BuildServerInventoryReport(client)
				end
			end)
		end
	end)
end

if (CLIENT) then
	net.Receive(NET_RES, function()
		if not ENABLE_DEBUG_REPORTS then
			return
		end

		local title = net.ReadString()
		local lines = net.ReadTable() or {}
		PrintReport(title, lines)
	end)

	local function BuildClientInventoryReport()
		local out = {}
		local client = LocalPlayer()
		local character = IsValid(client) and client.GetCharacter and client:GetCharacter() or nil

		table.insert(out, "localplayer_valid=" .. BoolStr(IsValid(client)))
		table.insert(out, "character_valid=" .. BoolStr(character ~= nil))

		if (character and character.GetInventory) then
			local inv = character:GetInventory()
			local validInv = type(inv) == "table"
				and type(inv.GetID) == "function"
				and type(inv.GetSize) == "function"
				and type(inv.slots) == "table"
			table.insert(out, "character_main_inventory_valid=" .. BoolStr(validInv))

			if (validInv) then
				local w, h = inv.GetSize(inv)
				local invID = inv.GetID(inv)
				table.insert(out, "character_main_inventory_id=" .. tostring(invID) .. " size=" .. tostring(w) .. "x" .. tostring(h))
				table.insert(out, "ix.item.inventories_has_main=" .. BoolStr(ix.item and ix.item.inventories and ix.item.inventories[invID] ~= nil))
			end
		else
			table.insert(out, "character_main_inventory_valid=no")
		end

		local menu = ix.gui and ix.gui.menu
		local invPanel = ix.gui and ix.gui.inv1
		table.insert(out, "menu_open=" .. BoolStr(IsValid(menu)))
		table.insert(out, "inv_panel_valid=" .. BoolStr(IsValid(invPanel)))

		if (IsValid(invPanel)) then
			local panelCount = 0
			for _, icon in pairs(invPanel.panels or {}) do
				if (IsValid(icon)) then
					panelCount = panelCount + 1
				end
			end

			local slotCount = 0
			for _, column in pairs(invPanel.slots or {}) do
				for _, _ in pairs(column or {}) do
					slotCount = slotCount + 1
				end
			end

			table.insert(out, "inv_panel_invID=" .. tostring(invPanel.invID or "nil"))
			table.insert(out, "inv_panel_grid=" .. tostring(invPanel.gridW or "nil") .. "x" .. tostring(invPanel.gridH or "nil"))
			table.insert(out, "inv_panel_icon_size=" .. tostring(invPanel.GetIconSize and invPanel:GetIconSize() or "nil"))
			table.insert(out, "inv_panel_slot_count=" .. tostring(slotCount))
			table.insert(out, "inv_panel_icon_count=" .. tostring(panelCount))
		end

		return out
	end

	local function HasValidClientMainInventory(character)
		if (!character or !character.GetInventory) then
			return false
		end

		local inv = character:GetInventory()
		return type(inv) == "table"
			and type(inv.GetID) == "function"
			and type(inv.GetSize) == "function"
			and type(inv.slots) == "table"
	end

	local autoResyncState = {
		charID = 0,
		attempts = 0,
		nextTryAt = 0,
	}

	timer.Create("LeopardRP.InventoryAutoResync", 0.75, 0, function()
		local client = LocalPlayer()
		if (!IsValid(client) or !client.GetCharacter) then
			return
		end

		local character = client:GetCharacter()
		if (!character or !character.GetID) then
			return
		end

		local charID = tonumber(character:GetID() or 0) or 0
		if (charID <= 0) then
			return
		end

		if (autoResyncState.charID ~= charID) then
			autoResyncState.charID = charID
			autoResyncState.attempts = 0
			autoResyncState.nextTryAt = 0
		end

		if (HasValidClientMainInventory(character)) then
			autoResyncState.attempts = 0
			autoResyncState.nextTryAt = 0
			return
		end

		if (autoResyncState.attempts >= 8) then
			return
		end

		if (RealTime() < autoResyncState.nextTryAt) then
			return
		end

		autoResyncState.attempts = autoResyncState.attempts + 1
		autoResyncState.nextTryAt = RealTime() + math.min(1 + autoResyncState.attempts * 0.5, 4)

		net.Start(NET_RESYNC_REQ)
		net.SendToServer()
	end)

	if ENABLE_DEBUG_REPORTS then
		concommand.Add("leopardrp_inv_debug", function()
			PrintReport("Client Report", BuildClientInventoryReport())

			net.Start(NET_REQ)
			net.SendToServer()
		end)

		concommand.Add("leopardrp_inv_resync", function()
			net.Start(NET_RESYNC_REQ)
			net.SendToServer()

			timer.Simple(0.35, function()
				PrintReport("Client Report (After Resync)", BuildClientInventoryReport())
			end)
		end)

		concommand.Add("leopardrp_inv_rebind_local", function()
			local client = LocalPlayer()
			local character = IsValid(client) and client.GetCharacter and client:GetCharacter() or nil

			if (!character or !character.GetID or !character.GetInventory) then
				PrintReport("Client Rebind", {"character_missing=yes"})
				return
			end

			local charID = character:GetID()
			local found

			for _, inventory in pairs(ix.item.inventories or {}) do
				if (type(inventory) == "table" and inventory.GetID and inventory.GetOwner and inventory.GetOwner(inventory) == charID) then
					character.vars.inv = character.vars.inv or {}
					character.vars.inv[1] = inventory
					found = inventory
					break
				end
			end

			if (found and IsValid(ix.gui.inv1)) then
				ix.gui.inv1:SetInventory(found)
			end

			if (found) then
				local w, h = found:GetSize()
				PrintReport("Client Rebind", {
					"rebound=yes",
					"inventory_id=" .. tostring(found:GetID()),
					"size=" .. tostring(w) .. "x" .. tostring(h)
				})
			else
				PrintReport("Client Rebind", {"rebound=no", "reason=no_owned_inventory_in_cache"})
			end
		end)
	end
end
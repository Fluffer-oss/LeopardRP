-- GM Menu - Item Spawning Page
-- Allows staff to spawn items from the Helix inventory system

local PANEL = {}

function PANEL:Init()
	self:DockPadding(10, 10, 10, 10)

	local titleLabel = self:Add("DLabel")
	titleLabel:Dock(TOP)
	titleLabel:SetHeight(30)
	titleLabel:SetFont("ixMenuMiniFont")
	titleLabel:SetTextColor(Color(200, 220, 255))
	titleLabel:SetText("Item Spawner")

	local descLabel = self:Add("DLabel")
	descLabel:Dock(TOP)
	descLabel:SetHeight(50)
	descLabel:SetFont("ixMenuTinyFont")
	descLabel:SetTextColor(Color(150, 170, 200))
	descLabel:SetText("Select an item from the list below and click 'Spawn Item' to add it to the selected player's inventory.")
	descLabel:SetWrap(true)

	local searchLabel = self:Add("DLabel")
	searchLabel:Dock(TOP)
	searchLabel:SetHeight(20)
	searchLabel:SetFont("ixMenuTinyFont")
	searchLabel:SetTextColor(Color(180, 190, 210))
	searchLabel:SetText("Search Items:")

	local searchBox = self:Add("DTextEntry")
	searchBox:Dock(TOP)
	searchBox:SetHeight(25)
	searchBox:SetPlaceholderText("Type item name...")

	local playerLabel = self:Add("DLabel")
	playerLabel:Dock(TOP)
	playerLabel:SetHeight(20)
	playerLabel:SetFont("ixMenuTinyFont")
	playerLabel:SetTextColor(Color(180, 190, 210))
	playerLabel:SetText("Target Player:")

	local playerCombo = self:Add("DComboBox")
	playerCombo:Dock(TOP)
	playerCombo:SetHeight(25)

	-- Populate player list
	for _, ply in ipairs(player.GetAll()) do
		playerCombo:AddChoice(ply:Nick(), ply)
	end

	local itemLabel = self:Add("DLabel")
	itemLabel:Dock(TOP)
	itemLabel:SetHeight(20)
	itemLabel:SetFont("ixMenuTinyFont")
	itemLabel:SetTextColor(Color(180, 190, 210))
	itemLabel:SetText("Available Items:")

	local itemScroll = self:Add("DScrollPanel")
	itemScroll:Dock(FILL)

	local itemList = vgui.Create("DListView", itemScroll)
	itemList:Dock(FILL)
	itemList:AddColumn("Item Name"):SetWidth(250)
	itemList:AddColumn("Unique ID"):SetWidth(200)

	-- Populate items from Helix
	if ix and ix.item and ix.item.list then
		for uniqueID, itemTable in pairs(ix.item.list) do
			if istable(itemTable) then
				local name = itemTable.name or "Unknown"
				itemList:AddLine(name, uniqueID)
			end
		end
	end

	local updateItems = function(searchText)
		itemList:Clear()
		searchText = string.lower(searchText or "")

		if ix and ix.item and ix.item.list then
			for uniqueID, itemTable in pairs(ix.item.list) do
				if istable(itemTable) then
					local name = tostring(itemTable.name or "Unknown")
					if searchText == "" or string.find(string.lower(name), searchText, 1, true) or string.find(string.lower(uniqueID), searchText, 1, true) then
						itemList:AddLine(name, uniqueID)
					end
				end
			end
		end
	end

	searchBox.OnChange = function(self)
		updateItems(self:GetValue())
	end

	local spawnButton = self:Add("DButton")
	spawnButton:Dock(BOTTOM)
	spawnButton:SetHeight(30)
	spawnButton:SetText("Spawn Item")

	function spawnButton:DoClick()
		local selectedLine = itemList:GetLine(itemList:GetSelectedLine())
		local targetPly = playerCombo:GetSelectedValue()

		if !selectedLine then
			chat.AddText(Color(255, 100, 100), "No item selected!")
			return
		end

		if !IsValid(targetPly) then
			chat.AddText(Color(255, 100, 100), "No player selected!")
			return
		end

		local uniqueID = selectedLine:GetColumnText(2)

		net.Start("LeopardRP.GMSpawnItem")
			net.WriteString(uniqueID)
			net.WriteEntity(targetPly)
		net.SendToServer()

		chat.AddText(Color(100, 200, 100), "Item spawned!")
	end

	self.ItemList = itemList
	self.PlayerCombo = playerCombo
	self.SearchBox = searchBox
end

function PANEL:Paint(w, h)
	draw.RoundedBox(0, 0, 0, w, h, Color(20, 20, 30, 240))
end

vgui.Register("LeopardRPGMItemSpawner", PANEL, "DPanel")

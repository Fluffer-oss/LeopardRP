local Combadge = LeopardRP and LeopardRP.Combadge
if not istable(Combadge) then return end

Combadge.ClientState = Combadge.ClientState or {
	Pending = {},
	LastVoiceKey = false,
	Menu = nil,
}

local function addSystemMessage(text)
	chat.AddText(Color(130, 210, 255), "[Combadge] ", Color(255, 255, 255), tostring(text or ""))
end

local function wrapTextLines(font, text, maxWidth)
	text = tostring(text or "")
	maxWidth = math.max(64, tonumber(maxWidth) or 64)

	if string.Wrap then
		local wrapped = string.Wrap(font, text, maxWidth)
		if istable(wrapped) and #wrapped > 0 then
			return wrapped
		end
	end

	surface.SetFont(font)
	local lines = {}
	local current = ""

	for word in string.gmatch(text, "%S+") do
		local candidate = current == "" and word or (current .. " " .. word)
		local candidateWidth = surface.GetTextSize(candidate)
		if candidateWidth <= maxWidth or current == "" then
			current = candidate
		else
			table.insert(lines, current)
			current = word
		end
	end

	if current ~= "" then
		table.insert(lines, current)
	end

	if #lines == 0 then
		lines[1] = ""
	end

	return lines
end

local function getPendingOrder()
	local output = {}
	for callerSid, data in pairs(Combadge.ClientState.Pending or {}) do
		output[#output + 1] = {
			CallerSid = callerSid,
			Data = data,
		}
	end

	table.sort(output, function(a, b)
		return (tonumber(a.Data and a.Data.CreatedAt) or 0) > (tonumber(b.Data and b.Data.CreatedAt) or 0)
	end)

	return output
end

function Combadge:GetCurrentPendingHail()
	local ordered = getPendingOrder()
	return ordered[1] and ordered[1].Data or nil
end

function Combadge:CycleVoiceMode()
	local current = self:GetPlayerVoiceModeIndex(LocalPlayer())
	local _, nextIndex = self:GetVoiceMode(current + 1)
	local modeData = self:GetVoiceMode(nextIndex)

	net.Start("LeopardRP.Combadge.SetVoiceMode")
		net.WriteUInt(nextIndex, 3)
	net.SendToServer()

	addSystemMessage(string.format("Voice range set to %s (%d units).", tostring(modeData and modeData.Label or "Normal"), tonumber(modeData and modeData.Radius) or 0))
	LocalPlayer():SetNWInt("LeopardRP.CombadgeVoiceMode", nextIndex)
	LocalPlayer():SetNWString("LeopardRP.CombadgeVoiceLabel", tostring(modeData and modeData.Label or "Normal"))
	LocalPlayer():SetNWInt("LeopardRP.CombadgeVoiceRadius", tonumber(modeData and modeData.Radius) or 450)
end

function Combadge:HandleWeaponPrimary()
	local pending = self:GetCurrentPendingHail()
	if pending then
		net.Start("LeopardRP.Combadge.RespondHail")
			net.WriteString(tostring(pending.CallerSid or ""))
		net.SendToServer()
		return
	end

	self:OpenHailMenu()
end

function Combadge:HandleWeaponSecondary()
	local pending = self:GetCurrentPendingHail()
	if not pending then
		return
	end

	net.Start("LeopardRP.Combadge.DenyHail")
		net.WriteString(tostring(pending.CallerSid or ""))
	net.SendToServer()
end

function Combadge:CollectHailablePlayers()
	local output = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply ~= LocalPlayer() and ply:GetNWBool("LeopardRP.CombadgeEquipped", false) then
			output[#output + 1] = ply
		end
	end

	table.sort(output, function(a, b)
		local left = string.lower(tostring(a:GetNWString("LeopardRP.CharacterName", a:Nick())))
		local right = string.lower(tostring(b:GetNWString("LeopardRP.CharacterName", b:Nick())))
		return left < right
	end)

	return output
end

function Combadge:GetAvailableDivisions()
	local divisions = {}
	local seen = {}
	for _, ply in ipairs(self:CollectHailablePlayers()) do
		local division = self:GetPlayerDivision(ply)
		if division ~= "" and not seen[division] then
			seen[division] = true
			divisions[#divisions + 1] = division
		end
	end

	table.sort(divisions)
	return divisions
end

local function createStripButton(parent, text)
	local button = vgui.Create("DButton", parent)
	button:SetText("")
	button.LabelText = tostring(text or "")
	button:SetTall(parent:GetTall())
	button:SetWide(math.max(88, #button.LabelText * 7 + 28))
	button.Paint = function(selfButton, w, h)
		local selected = selfButton.Selected == true
		local bg = selected and Color(110, 190, 255, 210) or Color(10, 20, 35, 165)
		local outline = selected and Color(220, 245, 255, 240) or Color(95, 140, 180, 180)
		local fg = selected and Color(8, 20, 32, 255) or Color(230, 242, 255, 235)
		if selfButton:IsHovered() and not selected then
			bg = Color(20, 34, 52, 190)
		end
		draw.RoundedBox(8, 0, 0, w, h, bg)
		surface.SetDrawColor(outline)
		surface.DrawOutlinedRect(0, 0, w, h, 1)
		draw.SimpleText(selfButton.LabelText, "Trebuchet18", w * 0.5, h * 0.5, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	return button
end

local function createChoiceStrip(parent, y, height)
	local holder = vgui.Create("DPanel", parent)
	holder:SetPos(16, y)
	holder:SetSize(parent:GetWide() - 32, height)
	holder.Paint = function() end

	local scroller = vgui.Create("DHorizontalScroller", holder)
	scroller:Dock(FILL)
	scroller:SetOverlap(-2)
	holder.Scroller = scroller
	holder.Buttons = {}
	holder.Choices = {}
	holder.SelectedValue = nil

	function holder:SetChoices(choices, selectedValue, onSelected)
		self.Scroller:Clear()
		self.Buttons = {}
		self.Choices = choices or {}
		self.SelectedValue = selectedValue
		for _, choice in ipairs(self.Choices) do
			local button = createStripButton(self.Scroller, choice.label)
			button.Selected = tostring(choice.value) == tostring(selectedValue)
			button.DoClick = function()
				self.SelectedValue = choice.value
				for _, sibling in ipairs(self.Buttons) do
					sibling.Selected = sibling == button
				end
				if isfunction(onSelected) then
					onSelected(choice)
				end
			end
			self.Scroller:AddPanel(button)
			self.Buttons[#self.Buttons + 1] = button
		end
		self:SetVisible(#self.Choices > 0)
	end

	return holder
end

function Combadge:OpenHailMenu()
	if IsValid(self.ClientState.Menu) then
		self.ClientState.Menu:Remove()
	end

	local frame = vgui.Create("DFrame")
	frame:SetSize(900, 410)
	frame:Center()
	frame:SetTitle("")
	frame:ShowCloseButton(true)
	frame:MakePopup()
	frame:SetDraggable(true)
	frame.Paint = function(_, w, h)
		draw.RoundedBox(18, 0, 0, w, h, Color(6, 12, 22, 205))
		draw.RoundedBox(18, 0, 0, w, 54, Color(26, 62, 90, 225))
		draw.SimpleText("LCARS Combadge", "Trebuchet24", 18, 18, Color(235, 245, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Select target mode, then open hail", "Trebuchet18", 18, 38, Color(180, 215, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		draw.SimpleText("Primary/Secondary while hailed: accept", "Trebuchet18", w - 18, 28, Color(180, 215, 240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
	self.ClientState.Menu = frame

	local modeLabel = vgui.Create("DLabel", frame)
	modeLabel:SetPos(16, 58)
	modeLabel:SetSize(860, 20)
	modeLabel:SetText(string.format("Voice Range: %s", tostring(LocalPlayer():GetNWString("LeopardRP.CombadgeVoiceLabel", "Normal"))))
	modeLabel:SetTextColor(Color(220, 235, 248))

	local state = {
		mode = "person",
		division = "",
		targetSteamID64 = "",
		deck = 0,
		section = 0,
	}

	local modeStrip = createChoiceStrip(frame, 86, 30)
	local divisionStrip = createChoiceStrip(frame, 126, 30)
	local playerStrip = createChoiceStrip(frame, 166, 30)
	local deckStrip = createChoiceStrip(frame, 206, 30)
	local sectionStrip = createChoiceStrip(frame, 246, 30)

	local hint = vgui.Create("DLabel", frame)
	hint:SetPos(16, 292)
	hint:SetSize(860, 40)
	hint:SetWrap(true)
	hint:SetText("Incoming hail: primary or secondary accepts instantly. Use this panel only to start outgoing hails.")
	hint:SetTextColor(Color(205, 225, 240))

	local summary = vgui.Create("DLabel", frame)
	summary:SetPos(16, 336)
	summary:SetSize(640, 24)
	summary:SetTextColor(Color(150, 210, 255))
	summary:SetText("Target: Individual")

	local function updateSummary()
		local text = "Target: Individual"
		if state.mode == "division" then
			text = string.format("Target: %s Division", state.division ~= "" and state.division or "All")
		elseif state.mode == "person" then
			text = string.format("Target: %s", state.targetName or "Select a crewmember")
		elseif state.mode == "deck" then
			if tonumber(state.section) and tonumber(state.section) > 0 then
				text = string.format("Target: %s", Combadge:GetSectionLabel(state.deck, state.section))
			else
				text = string.format("Target: Deck %d", tonumber(state.deck) or 0)
			end
		elseif state.mode == "section" then
			text = string.format("Target: %s", Combadge:GetSectionLabel(state.deck, state.section))
		elseif state.mode == "shipwide" then
			text = "Target: Shipwide"
		end
		summary:SetText(text)
	end

	local function refreshPlayerChoices()
		local selectedDivision = tostring(state.division or "")
		local choices = {}
		for _, ply in ipairs(Combadge:CollectHailablePlayers()) do
			local division = Combadge:GetPlayerDivision(ply)
			if selectedDivision == "" or division == selectedDivision then
				choices[#choices + 1] = {
					label = tostring(ply:GetNWString("LeopardRP.CharacterName", ply:Nick())),
					value = tostring(ply:SteamID64()),
					division = division,
				}
			end
		end
		if state.targetSteamID64 == "" and choices[1] then
			state.targetSteamID64 = tostring(choices[1].value or "")
			state.targetName = tostring(choices[1].label or "")
		end
		playerStrip:SetChoices(choices, state.targetSteamID64, function(choice)
			state.targetSteamID64 = tostring(choice.value or "")
			state.targetName = tostring(choice.label or "")
			updateSummary()
		end)
		updateSummary()
	end

	local function refreshDivisionChoices()
		local choices = {
			{ label = "All Divisions", value = "" },
		}
		for _, division in ipairs(Combadge:GetAvailableDivisions()) do
			choices[#choices + 1] = { label = division, value = division }
		end
		divisionStrip:SetChoices(choices, state.division, function(choice)
			state.division = tostring(choice.value or "")
			state.targetSteamID64 = ""
			state.targetName = nil
			refreshPlayerChoices()
			updateSummary()
		end)
		refreshPlayerChoices()
	end

	local refreshSectionChoices

	local function refreshDeckChoices()
		local decks = (Star_Trek and Star_Trek.Sections and Star_Trek.Sections.Decks) or {}
		local choices = {}
		for deckNumber, deckData in SortedPairs(decks) do
			if istable(deckData) then
				choices[#choices + 1] = { label = string.format("Deck %d", tonumber(deckNumber) or 0), value = tonumber(deckNumber) or 0 }
			end
		end
		if state.deck <= 0 and choices[1] then
			state.deck = tonumber(choices[1].value) or 0
		end
		deckStrip:SetChoices(choices, state.deck, function(choice)
			state.deck = tonumber(choice.value) or 0
			state.section = 0
			refreshSectionChoices()
			updateSummary()
		end)
	end

	function refreshSectionChoices()
		local deckData = Star_Trek and Star_Trek.Sections and Star_Trek.Sections.Decks and Star_Trek.Sections.Decks[state.deck]
		local choices = {}
		if state.mode == "deck" then
			choices[#choices + 1] = { label = "Hail Entire Deck", value = 0 }
		end
		if istable(deckData) and istable(deckData.Sections) then
			for sectionId, sectionData in SortedPairs(deckData.Sections) do
				choices[#choices + 1] = { label = Combadge:GetSectionLabel(state.deck, sectionId), value = tonumber(sectionId) or 0 }
			end
		end
		if state.mode == "deck" and state.section == nil then
			state.section = 0
		elseif state.mode == "section" and state.section <= 0 then
			state.section = tonumber(choices[1].value) or 0
		end
		sectionStrip:SetChoices(choices, state.section, function(choice)
			state.section = tonumber(choice.value) or 0
			updateSummary()
		end)
	end

	local function refreshVisibility()
		local showPlayers = state.mode == "person"
		local showDivisions = state.mode == "division" or state.mode == "person"
		local showDecks = state.mode == "deck" or state.mode == "section"
		local showSections = state.mode == "deck" or state.mode == "section"
		divisionStrip:SetVisible(showDivisions)
		playerStrip:SetVisible(showPlayers)
		deckStrip:SetVisible(showDecks)
		sectionStrip:SetVisible(showSections)
		updateSummary()
	end

	local modeChoices = {
		{ label = "Individual", value = "person" },
		{ label = "Division", value = "division" },
		{ label = "Deck / Section", value = "deck" },
	}
	if self:CanShipwideHail(LocalPlayer()) then
		modeChoices[#modeChoices + 1] = { label = "Shipwide", value = "shipwide" }
	end
	modeStrip:SetChoices(modeChoices, state.mode, function(choice)
		state.mode = tostring(choice.value or "person")
		if state.mode ~= "deck" and state.mode ~= "section" then
			state.section = 0
		end
		refreshSectionChoices()
		refreshVisibility()
	end)

	refreshDivisionChoices()
	refreshDeckChoices()
	refreshSectionChoices()
	refreshVisibility()

	local hailButton = vgui.Create("DButton", frame)
	hailButton:SetPos(686, 334)
	hailButton:SetSize(190, 34)
	hailButton:SetText("")
	hailButton.Paint = function(selfButton, w, h)
		local bg = selfButton:IsHovered() and Color(115, 210, 255, 225) or Color(80, 180, 230, 205)
		draw.RoundedBox(10, 0, 0, w, h, bg)
		draw.SimpleText("Open Hail", "Trebuchet18", w * 0.5, h * 0.5, Color(10, 20, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	hailButton.DoClick = function()
		local payload = {
			mode = state.mode,
		}

		if state.mode == "person" then
			payload.targetSteamID64 = tostring(state.targetSteamID64 or "")
			payload.targetName = tostring(state.targetName or "")
		elseif state.mode == "division" then
			payload.division = tostring(state.division or "")
		elseif state.mode == "deck" then
			payload.deck = tonumber(state.deck) or 0
			if tonumber(state.section) and tonumber(state.section) > 0 then
				payload.mode = "section"
				payload.section = tonumber(state.section) or 0
			end
		elseif state.mode == "section" then
			payload.deck = tonumber(state.deck) or 0
			payload.section = tonumber(state.section) or 0
		end

		net.Start("LeopardRP.Combadge.StartHail")
			net.WriteTable(payload)
		net.SendToServer()

		frame:Remove()
	end
end

hook.Add("Think", "LeopardRP.Combadge.VoiceRangeKey", function()
	if gui.IsGameUIVisible() then return end
	if IsValid(vgui.GetKeyboardFocus()) then return end
	if LeopardRP.Personnel and LeopardRP.Personnel.GetBoundKey then return end

	local keyCode = Combadge.Config.VoiceKey or KEY_COMMA
	if LeopardRP.Config and LeopardRP.Config.KeybindVoiceRangeCycle then
		keyCode = tonumber(LeopardRP.Config.KeybindVoiceRangeCycle) or keyCode
	end

	local isDown = input.IsKeyDown(keyCode)
	if isDown and not Combadge.ClientState.LastVoiceKey then
		Combadge:CycleVoiceMode()
	end
	Combadge.ClientState.LastVoiceKey = isDown
end)

hook.Add("HUDPaint", "LeopardRP.Combadge.PendingHailHUD", function()
	local pending = Combadge:GetCurrentPendingHail()
	if not pending then
		return
	end

	local pendingAge = CurTime() - (tonumber(pending.CreatedAt) or CurTime())
	local maxAge = math.max(10, tonumber(Combadge.Config and Combadge.Config.HailDuration) or 45) + 5
	if pendingAge >= maxAge then
		Combadge.ClientState.Pending[tostring(pending.CallerSid or "")] = nil
		return
	end

	local width = 520
	local textWidth = width - 24
	local descriptorText = string.format("%s | %s", tostring(pending.CallerName or "Unknown"), tostring(pending.Descriptor or "Direct Hail"))
	local descriptorWrapped = wrapTextLines("Trebuchet18", descriptorText, textWidth)
	local descriptorLines = istable(descriptorWrapped) and #descriptorWrapped or 1
	local descriptorHeight = math.max(18, descriptorLines * 18)
	local height = 76 + descriptorHeight
	local x = ScrW() - width - 24
	local y = ScrH() * 0.25

	draw.RoundedBox(8, x, y, width, height, Color(5, 12, 22, 220))
	draw.SimpleText("Incoming Hail", "Trebuchet24", x + 12, y + 8, Color(130, 210, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.DrawText(table.concat(descriptorWrapped, "\n"), "Trebuchet18", x + 12, y + 34, Color(255, 255, 255), TEXT_ALIGN_LEFT)
	draw.SimpleText("Primary: Respond    Secondary: Deny", "Trebuchet18", x + 12, y + 44 + descriptorHeight, Color(220, 230, 240), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)

net.Receive("LeopardRP.Combadge.IncomingHail", function()
	local callerSid = net.ReadString()
	local callerName = net.ReadString()
	local descriptor = net.ReadString()
	local mode = net.ReadString()
	local soundPath = net.ReadString()

	Combadge.ClientState.Pending[callerSid] = {
		CallerSid = callerSid,
		CallerName = callerName,
		Descriptor = descriptor,
		Mode = mode,
		CreatedAt = CurTime(),
	}

	if soundPath ~= "" then
		LocalPlayer():EmitSound(soundPath, 95, 100, tonumber(Combadge.Config.IncomingVolume) or 1, CHAN_AUTO)
	end
	addSystemMessage(string.format("Incoming hail from %s (%s).", tostring(callerName or "Unknown"), tostring(descriptor or "Direct Hail")))
end)

net.Receive("LeopardRP.Combadge.HailEnded", function()
	local callerSid = net.ReadString()
	net.ReadString()
	Combadge.ClientState.Pending[callerSid] = nil
end)

net.Receive("LeopardRP.Combadge.HailResponse", function()
	local callerSid = net.ReadString()
	local responderName = net.ReadString()
	local soundPath = net.ReadString()
	Combadge.ClientState.Pending[callerSid] = nil
	if soundPath ~= "" then
		LocalPlayer():EmitSound(soundPath, 95, 100, tonumber(Combadge.Config.RespondVolume) or 1, CHAN_AUTO)
	end
	addSystemMessage(string.format("%s responded to the hail.", tostring(responderName or "Unknown")))
end)

net.Receive("LeopardRP.Combadge.SystemMessage", function()
	addSystemMessage(net.ReadString())
end)

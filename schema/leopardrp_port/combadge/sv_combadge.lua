local Combadge = LeopardRP and LeopardRP.Combadge
if not istable(Combadge) then return end

util.AddNetworkString("LeopardRP.Combadge.SetVoiceMode")
util.AddNetworkString("LeopardRP.Combadge.StartHail")
util.AddNetworkString("LeopardRP.Combadge.RespondHail")
util.AddNetworkString("LeopardRP.Combadge.DenyHail")
util.AddNetworkString("LeopardRP.Combadge.IncomingHail")
util.AddNetworkString("LeopardRP.Combadge.HailEnded")
util.AddNetworkString("LeopardRP.Combadge.HailResponse")
util.AddNetworkString("LeopardRP.Combadge.SystemMessage")

Combadge.ActiveCalls = Combadge.ActiveCalls or {}
Combadge.PendingIncoming = Combadge.PendingIncoming or {}
Combadge.BodygroupIndexCache = Combadge.BodygroupIndexCache or {}

local function sendSystemMessage(ply, text)
	if not IsValid(ply) then
		return
	end

	net.Start("LeopardRP.Combadge.SystemMessage")
		net.WriteString(tostring(text or ""))
	net.Send(ply)
end

local function getSteamID64(ply)
	if not IsValid(ply) then
		return ""
	end

	return tostring(ply:SteamID64() or "")
end

function Combadge:GetCombadgeBodygroupIndex(entity)
	if not IsValid(entity) then return nil end

	local model = string.lower(tostring(entity:GetModel() or ""))
	local cached = self.BodygroupIndexCache[model]
	if cached ~= nil then
		return cached or nil
	end

	local targetNames = self.Config.BodygroupNames or {}
	local lookup = {}
	for _, name in ipairs(targetNames) do
		lookup[string.lower(tostring(name or ""))] = true
	end

	if entity.FindBodygroupByName then
		for _, name in ipairs(targetNames) do
			local bodygroupIndex = entity:FindBodygroupByName(tostring(name))
			if isnumber(bodygroupIndex) and bodygroupIndex >= 0 then
				self.BodygroupIndexCache[model] = bodygroupIndex
				return bodygroupIndex
			end
		end
	end

	for index = 0, math.max(0, entity:GetNumBodyGroups() - 1) do
		local groupName = string.lower(tostring(entity:GetBodygroupName(index) or ""))
		if lookup[groupName] then
			self.BodygroupIndexCache[model] = index
			return index
		end
	end

	self.BodygroupIndexCache[model] = false
	return nil
end

function Combadge:PlayerHasCombadge(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return false
	end

	for _, className in ipairs(self:GetTrackedWeaponClasses()) do
		if ply:HasWeapon(className) then
			return true, className
		end
	end

	return false, ""
end

function Combadge:SetPlayerCombadgeBodygroup(ply, enabled)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return
	end

	local bodygroupIndex = self:GetCombadgeBodygroupIndex(ply)
	if not isnumber(bodygroupIndex) then
		return
	end

	ply:SetBodygroup(bodygroupIndex, enabled and (tonumber(self.Config.BodygroupOnValue) or 1) or 0)
	ply:SetNWBool("LeopardRP.CombadgeEquipped", enabled == true)
	ply:SetNWString("LeopardRP.CombadgeWeaponClass", enabled and tostring(select(2, self:PlayerHasCombadge(ply)) or self.Config.WeaponClass or "") or "")
end

function Combadge:RefreshPlayerState(ply)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return
	end

	local hasCombadge = self:PlayerHasCombadge(ply)
	self:SetPlayerCombadgeBodygroup(ply, hasCombadge)
	if ply:GetNWInt("LeopardRP.CombadgeVoiceMode", 0) <= 0 then
		ply:SetNWInt("LeopardRP.CombadgeVoiceMode", 3)
	end
	ply:SetNWInt("LeopardRP.CombadgeVoiceRadius", self:GetPlayerVoiceRadius(ply))
	ply:SetNWString("LeopardRP.CombadgeVoiceLabel", tostring((self:GetVoiceMode(self:GetPlayerVoiceModeIndex(ply))).Label or "Normal"))
end

local function clearPendingForRecipient(recipientSid, callerSid)
	local pending = Combadge.PendingIncoming[recipientSid]
	if not istable(pending) then
		return
	end

	pending[callerSid] = nil
	if table.IsEmpty(pending) then
		Combadge.PendingIncoming[recipientSid] = nil
	end
end

function Combadge:ClearCall(callerSid, reason)
	local call = self.ActiveCalls[callerSid]
	if not istable(call) then
		return
	end

	for recipientSid in pairs(call.Recipients or {}) do
		clearPendingForRecipient(recipientSid, callerSid)
		local recipient = player.GetBySteamID64(recipientSid)
		if IsValid(recipient) then
			net.Start("LeopardRP.Combadge.HailEnded")
				net.WriteString(tostring(callerSid))
				net.WriteString(tostring(reason or "ended"))
				net.Send(recipient)
		end
	end

	local caller = player.GetBySteamID64(callerSid)
	if IsValid(caller) then
		net.Start("LeopardRP.Combadge.HailEnded")
			net.WriteString(tostring(callerSid))
			net.WriteString(tostring(reason or "ended"))
			net.Send(caller)
	end

	self.ActiveCalls[callerSid] = nil
end

local function buildRecipientList(ply, payload)
	local recipients = {}
	local targetMode = string.lower(tostring(payload.mode or "person"))

	if targetMode == "person" then
		local target = player.GetBySteamID64(tostring(payload.targetSteamID64 or ""))
		if IsValid(target) and target ~= ply and Combadge:PlayerHasCombadge(target) then
			recipients[#recipients + 1] = target
		end
	elseif targetMode == "division" then
		local wantedDivision = string.lower(string.Trim(tostring(payload.division or "")))
		for _, target in ipairs(player.GetAll()) do
			if target ~= ply and Combadge:PlayerHasCombadge(target) then
				local division = string.lower(Combadge:GetPlayerDivision(target))
				if wantedDivision ~= "" and division == wantedDivision then
					recipients[#recipients + 1] = target
				end
			end
		end
	elseif targetMode == "deck" or targetMode == "section" then
		local wantedDeck = tonumber(payload.deck) or 0
		local wantedSection = tonumber(payload.section) or 0
		if wantedDeck > 0 and Star_Trek and Star_Trek.Sections and Star_Trek.Sections.DetermineSection then
			for _, target in ipairs(player.GetAll()) do
				if target ~= ply and Combadge:PlayerHasCombadge(target) then
					local success, deck, sectionId = Star_Trek.Sections:DetermineSection(target:GetPos())
					if success and tonumber(deck) == wantedDeck and (targetMode == "deck" or tonumber(sectionId) == wantedSection) then
						recipients[#recipients + 1] = target
					end
				end
			end
		end
	elseif targetMode == "shipwide" then
		if Combadge:CanShipwideHail(ply) then
			for _, target in ipairs(player.GetAll()) do
				if target ~= ply and Combadge:PlayerHasCombadge(target) then
					recipients[#recipients + 1] = target
				end
			end
		end
	end

	return recipients
end

local function buildDescriptor(payload)
	local targetMode = string.lower(tostring(payload.mode or "person"))
	if targetMode == "person" then
		return tostring(payload.targetName or "Direct Hail")
	end

	if targetMode == "division" then
		return string.format("%s Division", tostring(payload.division or "Unknown"))
	end

	if targetMode == "deck" then
		return string.format("Deck %d", tonumber(payload.deck) or 0)
	end

	if targetMode == "section" then
		return Combadge:GetSectionLabel(tonumber(payload.deck) or 0, tonumber(payload.section) or 0)
	end

	if targetMode == "shipwide" then
		return "Shipwide"
	end

	return "Open Channel"
end

function Combadge:StartHail(ply, payload)
	if not (IsValid(ply) and ply:IsPlayer()) then
		return false, "Invalid caller"
	end

	if not self:IsCommunicationsOnline() then
		return false, "Communications are currently offline."
	end

	if not self:PlayerHasCombadge(ply) then
		return false, "You need a combadge equipped."
	end

	payload = istable(payload) and payload or {}
	local mode = string.lower(tostring(payload.mode or "person"))
	if mode == "shipwide" and not self:CanShipwideHail(ply) then
		return false, "Shipwide hail requires Lieutenant Commander or higher."
	end

	local recipients = buildRecipientList(ply, payload)
	if #recipients <= 0 then
		return false, "No combadge recipients matched that hail target."
	end

	local callerSid = getSteamID64(ply)
	self:ClearCall(callerSid, "replaced")

	local descriptor = buildDescriptor(payload)
	local call = {
		Caller = ply,
		CallerSid = callerSid,
		CallerName = tostring(ply:GetNWString("LeopardRP.CharacterName", ply:Nick())),
		Recipients = {},
		Responders = {},
		StartedAt = CurTime(),
		ExpiresAt = CurTime() + math.max(10, tonumber(self.Config.HailDuration) or 45),
		Descriptor = descriptor,
		Mode = mode,
	}

	for _, recipient in ipairs(recipients) do
		local recipientSid = getSteamID64(recipient)
		call.Recipients[recipientSid] = true
		self.PendingIncoming[recipientSid] = self.PendingIncoming[recipientSid] or {}
		self.PendingIncoming[recipientSid][callerSid] = true

		net.Start("LeopardRP.Combadge.IncomingHail")
			net.WriteString(callerSid)
			net.WriteString(call.CallerName)
			net.WriteString(descriptor)
			net.WriteString(tostring(mode))
			net.WriteString(tostring(self.Config.IncomingSound or ""))
			net.Send(recipient)
	end

	self.ActiveCalls[callerSid] = call
	return true, string.format("Opened combadge hail to %s (%d recipients).", descriptor, #recipients)
end

function Combadge:RespondToHail(ply, callerSid)
	if not self:IsCommunicationsOnline() then
		return false, "Communications are currently offline."
	end

	callerSid = tostring(callerSid or "")
	if callerSid == "" then
		return false, "No hail to respond to."
	end

	local recipientSid = getSteamID64(ply)
	if not (self.PendingIncoming[recipientSid] and self.PendingIncoming[recipientSid][callerSid]) then
		return false, "That hail is no longer pending."
	end

	local call = self.ActiveCalls[callerSid]
	if not istable(call) then
		clearPendingForRecipient(recipientSid, callerSid)
		return false, "That hail has ended."
	end

	call.Responders[recipientSid] = true
	clearPendingForRecipient(recipientSid, callerSid)

	local caller = player.GetBySteamID64(callerSid)
	local responderName = tostring(ply:GetNWString("LeopardRP.CharacterName", ply:Nick()))
	if IsValid(caller) then
		net.Start("LeopardRP.Combadge.HailResponse")
			net.WriteString(recipientSid)
			net.WriteString(responderName)
			net.WriteString(tostring(self.Config.RespondSound or ""))
			net.Send(caller)
	end

	net.Start("LeopardRP.Combadge.HailResponse")
		net.WriteString(callerSid)
		net.WriteString(call.CallerName)
		net.WriteString(tostring(self.Config.RespondSound or ""))
		net.Send(ply)

	return true, string.format("Responding to %s.", call.CallerName)
end

function Combadge:DenyHail(ply, callerSid)
	callerSid = tostring(callerSid or "")
	if callerSid == "" then
		return false, "No hail to deny."
	end

	local recipientSid = getSteamID64(ply)
	if not (self.PendingIncoming[recipientSid] and self.PendingIncoming[recipientSid][callerSid]) then
		return false, "That hail is no longer pending."
	end

	clearPendingForRecipient(recipientSid, callerSid)
	local call = self.ActiveCalls[callerSid]
	if istable(call) then
		call.Recipients[recipientSid] = nil
		call.Responders[recipientSid] = nil
		if table.IsEmpty(call.Recipients) then
			self:ClearCall(callerSid, "denied")
		end
	end

	return true, "Hail denied."
end

function Combadge:CanPlayerHearVoice(listener, talker)
	if not (IsValid(listener) and listener:IsPlayer() and IsValid(talker) and talker:IsPlayer()) then
		return nil
	end

	local listenerSid = getSteamID64(listener)
	local talkerSid = getSteamID64(talker)

	local outgoing = self.ActiveCalls[talkerSid]
	if istable(outgoing) and outgoing.ExpiresAt > CurTime() and outgoing.Recipients[listenerSid] then
		return true, false
	end

	for callerSid, call in pairs(self.ActiveCalls) do
		if not istable(call) then
			self.ActiveCalls[callerSid] = nil
		elseif call.ExpiresAt <= CurTime() then
			self:ClearCall(callerSid, "expired")
		elseif call.CallerSid == listenerSid and call.Responders[talkerSid] then
			return true, false
		end
	end

	if istable(Star_Trek) and istable(Star_Trek.Operations) and isfunction(Star_Trek.Operations.CanRelayVoiceThroughActiveHail) then
		local relayCanHear, relayIs3D = Star_Trek.Operations:CanRelayVoiceThroughActiveHail(listener, talker)
		if relayCanHear ~= nil then
			return relayCanHear, relayIs3D
		end
	end

	local radius = self:GetPlayerVoiceRadius(talker)
	if listener:GetPos():DistToSqr(talker:GetPos()) <= (radius * radius) then
		return true, true
	end

	return false, false
end

timer.Create("LeopardRP.Combadge.StateRefresh", 2, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		Combadge:RefreshPlayerState(ply)
	end

	if not Combadge:IsCommunicationsOnline() then
		for callerSid in pairs(Combadge.ActiveCalls) do
			Combadge:ClearCall(callerSid, "offline")
		end
		return
	end

	for callerSid, call in pairs(Combadge.ActiveCalls) do
		if not istable(call) or call.ExpiresAt <= CurTime() then
			Combadge:ClearCall(callerSid, "expired")
		end
	end
end)

hook.Add("PlayerCanHearPlayersVoice", "LeopardRP.Combadge.VoiceRouting", function(listener, talker)
	if not istable(Combadge) or not isfunction(Combadge.CanPlayerHearVoice) then
		return
	end

	return Combadge:CanPlayerHearVoice(listener, talker)
end)

hook.Add("PlayerSpawn", "LeopardRP.Combadge.RefreshSpawn", function(ply)
	timer.Simple(0.2, function()
		if IsValid(ply) then
			Combadge:RefreshPlayerState(ply)
		end
	end)
end)

hook.Add("LeopardRPCharacterApplied", "LeopardRP.Combadge.RefreshCharacter", function(ply)
	timer.Simple(0.1, function()
		if IsValid(ply) then
			Combadge:RefreshPlayerState(ply)
		end
	end)
end)

hook.Add("PlayerDisconnected", "LeopardRP.Combadge.CleanupDisconnect", function(ply)
	local sid = getSteamID64(ply)
	Combadge:ClearCall(sid, "disconnect")
	Combadge.PendingIncoming[sid] = nil
	for callerSid, call in pairs(Combadge.ActiveCalls) do
		if istable(call) then
			call.Recipients[sid] = nil
			call.Responders[sid] = nil
			if table.IsEmpty(call.Recipients) then
				Combadge:ClearCall(callerSid, "disconnect")
			end
		end
	end
end)

net.Receive("LeopardRP.Combadge.SetVoiceMode", function(_, ply)
	local requested = net.ReadUInt(3)
	local _, modeIndex = Combadge:GetVoiceMode(requested)
	local modeData = Combadge:GetVoiceMode(modeIndex)
	ply:SetNWInt("LeopardRP.CombadgeVoiceMode", modeIndex)
	ply:SetNWInt("LeopardRP.CombadgeVoiceRadius", tonumber(modeData and modeData.Radius) or 450)
	ply:SetNWString("LeopardRP.CombadgeVoiceLabel", tostring(modeData and modeData.Label or "Normal"))
end)

net.Receive("LeopardRP.Combadge.StartHail", function(_, ply)
	local payload = net.ReadTable() or {}
	local success, result = Combadge:StartHail(ply, payload)
	sendSystemMessage(ply, success and result or tostring(result or "Unable to open hail."))
end)

net.Receive("LeopardRP.Combadge.RespondHail", function(_, ply)
	local callerSid = net.ReadString()
	local success, result = Combadge:RespondToHail(ply, callerSid)
	sendSystemMessage(ply, success and result or tostring(result or "Unable to respond."))
end)

net.Receive("LeopardRP.Combadge.DenyHail", function(_, ply)
	local callerSid = net.ReadString()
	local success, result = Combadge:DenyHail(ply, callerSid)
	sendSystemMessage(ply, success and result or tostring(result or "Unable to deny hail."))
end)

LeopardRP = LeopardRP or {}
LeopardRP.Combadge = LeopardRP.Combadge or {}

local Combadge = LeopardRP.Combadge

Combadge.Config = Combadge.Config or {
	WeaponClass = "weapon_leopardrp_combadge",
	AdditionalWeaponClasses = {
		"2370_combadge",
		"2360_combadge",
		"2380_combadge",
		"2390_combadge",
		"2390a_combadge",
		"2401_combadge",
		"2410_combadge",
		"2410_operations_combadge",
		"2410_science_combadge",
		"2410_tactical_combadge",
	},
	BodygroupNames = { "combadge", "badge" },
	BodygroupOnValue = 1,
	VoiceKey = KEY_COMMA,
	HailDuration = 120,
	IncomingSound = "memory_alpha/computer/tng_fed_hail_textmessage.mp3",
	RespondSound = "memory_alpha/tech/communicators/tng_fed_communicator.mp3",
	IncomingVolume = 1,
	RespondVolume = 1,
	VoiceModes = {
		{ Id = "whisper", Label = "Whisper", Radius = 100 },
		{ Id = "quiet", Label = "Quiet", Radius = 250 },
		{ Id = "normal", Label = "Normal", Radius = 450 },
		{ Id = "yelling", Label = "Yelling", Radius = 850 },
	},
}

function Combadge:GetTrackedWeaponClasses()
	local classes = {
		tostring(self.Config.WeaponClass or "weapon_leopardrp_combadge"),
	}

	for _, className in ipairs(self.Config.AdditionalWeaponClasses or {}) do
		className = tostring(className or "")
		if className ~= "" then
			classes[#classes + 1] = className
		end
	end

	return classes
end

function Combadge:GetVoiceMode(index)
	local modes = self.Config.VoiceModes or {}
	if #modes <= 0 then
		return nil, 1
	end

	local modeIndex = math.floor(tonumber(index) or 3)
	if modeIndex <= 0 then
		modeIndex = #modes
	elseif modeIndex > #modes then
		modeIndex = 1
	end

	return modes[modeIndex], modeIndex
end

function Combadge:GetPlayerVoiceModeIndex(ply)
	local _, modeIndex = self:GetVoiceMode(IsValid(ply) and ply:GetNWInt("LeopardRP.CombadgeVoiceMode", 3) or 3)
	return modeIndex
end

function Combadge:GetPlayerVoiceRadius(ply)
	local modeData = self:GetVoiceMode(self:GetPlayerVoiceModeIndex(ply))
	return tonumber(modeData and modeData.Radius) or 450
end

function Combadge:GetPlayerDivision(ply)
	if not IsValid(ply) then
		return ""
	end

	return string.Trim(tostring(ply:GetNWString("LeopardRP.CharacterDivision", "")))
end

function Combadge:GetRankIDFromText(rankText)
	local lowered = string.lower(string.Trim(tostring(rankText or "")))
	if lowered == "" then
		return ""
	end

	for _, rankData in ipairs((LeopardRP.GetRankList and LeopardRP.GetRankList()) or LeopardRP.Ranks or {}) do
		local rankId = string.lower(tostring(rankData.ID or ""))
		local rankName = string.lower(tostring(rankData.Name or ""))
		local rankShort = string.lower(tostring(rankData.Short or ""))
		if lowered == rankId or lowered == rankName or lowered == rankShort then
			return tostring(rankData.ID or "")
		end
	end

	return ""
end

function Combadge:GetPlayerRankOrder(ply)
	if not IsValid(ply) then
		return 0
	end

	local rankId = self:GetRankIDFromText(ply:GetNWString("LeopardRP.CharacterRank", ""))
	if rankId == "" or not LeopardRP.GetRankOrder then
		return 0
	end

	return tonumber(LeopardRP.GetRankOrder(rankId)) or 0
end

function Combadge:CanShipwideHail(ply)
	return self:GetPlayerRankOrder(ply) >= (tonumber(LeopardRP.GetRankOrder and LeopardRP.GetRankOrder("lieutenant_commander") or 11) or 11)
end

function Combadge:GetSectionLabel(deck, sectionId)
	if Star_Trek and Star_Trek.Sections and Star_Trek.Sections.GetSectionName then
		local success, result = Star_Trek.Sections:GetSectionName(deck, sectionId)
		if success then
			return string.format("Deck %d %s", tonumber(deck) or 0, tostring(result or ""))
		end
	end

	if tonumber(sectionId) and tonumber(sectionId) > 0 then
		return string.format("Deck %d Section %d", tonumber(deck) or 0, tonumber(sectionId) or 0)
	end

	return string.format("Deck %d", tonumber(deck) or 0)
end

function Combadge:IsCommunicationsOnline()
	if not StarTrekEntities then
		return true
	end

	local commsHealth
	if StarTrekEntities.Comms and isfunction(StarTrekEntities.Comms.GetHealthPercent) then
		commsHealth = tonumber(StarTrekEntities.Comms:GetHealthPercent()) or 0
		if commsHealth <= 0 then
			return false
		end
	else
		local repairEnt = Star_Trek and Star_Trek.Comms_Panel and Star_Trek.Comms_Panel.RepairEnt
		if IsValid(repairEnt) then
			local maxhp = tonumber((repairEnt.GetCommsMaxHealth and repairEnt:GetCommsMaxHealth()) or (repairEnt.GetMaxHealth and repairEnt:GetMaxHealth()) or 0) or 0
			local hp = tonumber((repairEnt.GetCommsHealth and repairEnt:GetCommsHealth()) or (repairEnt.Health and repairEnt:Health()) or 0) or 0
			if maxhp > 0 and hp <= 0 then
				return false
			end
		end
	end

	local status = StarTrekEntities.Status and StarTrekEntities.Status.comms
	if istable(status) then
		if status.active == false then
			return false
		end
		if status.active == true then
			return commsHealth == nil or commsHealth > 0
		end
	end

	if commsHealth ~= nil then
		return commsHealth > 0
	end

	return true
end

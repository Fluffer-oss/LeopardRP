LeopardRP = LeopardRP or {}
LeopardRP.STMCompat = LeopardRP.STMCompat or {}

local Compat = LeopardRP.STMCompat

local function HasStardateUtil()
	return Star_Trek and Star_Trek.Util and type(Star_Trek.Util.GetStardate) == "function"
end

local function IsStarTrekDoor(entity)
	return Star_Trek and Star_Trek.Doors and Star_Trek.Doors.IsDoor and Star_Trek.Doors:IsDoor(entity)
end

function Compat.GetDateLine(unixTime)
	local timeValue = tonumber(unixTime) or os.time()

	if (!HasStardateUtil()) then
		return os.date("%A, %B %d, %Y. %H:%M", timeValue)
	end

	local stardateText = Star_Trek.Util.FormatStardate and Star_Trek.Util:FormatStardate(timeValue)
		or tostring(Star_Trek.Util:GetStardate(timeValue))
	local dateText = Star_Trek.Util.GetDate and Star_Trek.Util:GetDate(timeValue) or os.date("%Y-%m-%d", timeValue)
	local timeText = os.date("%H:%M:%S", timeValue)

	return string.format("Stardate %s | %s - %s", tostring(stardateText), tostring(dateText), tostring(timeText))
end

-- Let Helix treat Star Trek prop_dynamic doors as doors for ownership/access systems.
do
	local entityMeta = FindMetaTable("Entity")

	if (entityMeta and !entityMeta.LeopardRP_STMCompatDoorPatchApplied) then
		entityMeta.LeopardRP_STMCompatDoorPatchApplied = true
		entityMeta.LeopardRP_STMCompatOriginalIsDoor = entityMeta.LeopardRP_STMCompatOriginalIsDoor or entityMeta.IsDoor

		function entityMeta:IsDoor()
			local original = entityMeta.LeopardRP_STMCompatOriginalIsDoor

			if (original and original(self)) then
				return true
			end

			if (IsStarTrekDoor(self)) then
				return true
			end

			return false
		end
	end
end

-- Respect LCARS lock state for Helix door usage checks.
if (SERVER) then
	hook.Add("CanPlayerUseDoor", "LeopardRP.STMDoorLockCompat", function(client, entity)
		if (!IsValid(entity) or !IsStarTrekDoor(entity)) then
			return
		end

		local keyData = entity.LCARSKeyData
		if (type(keyData) == "table" and tostring(keyData["lcars_locked"] or "0") == "1") then
			return false
		end
	end)
end

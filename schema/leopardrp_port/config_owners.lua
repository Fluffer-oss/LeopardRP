LeopardRP = LeopardRP or {}
LeopardRP.Config = LeopardRP.Config or {}

-- SteamID64 allowlist for users who may edit the Personnel "Config" pages (Dev Mode + Logistics).
-- Add or remove IDs here without changing code elsewhere.
LeopardRP.Config.ConfigTabOwnerSteamIDs = LeopardRP.Config.ConfigTabOwnerSteamIDs or {
    "76561199122465449"
}

function LeopardRP.Config.IsConfigTabOwner(subject)
    local steamID64 = ""

    if isstring(subject) then
        steamID64 = string.Trim(subject)
    elseif IsValid(subject) and subject.SteamID64 then
        steamID64 = string.Trim(tostring(subject:SteamID64() or ""))
    end

    if steamID64 == "" then
        return false
    end

    for _, allowed in ipairs(LeopardRP.Config.ConfigTabOwnerSteamIDs or {}) do
        if steamID64 == string.Trim(tostring(allowed or "")) then
            return true
        end
    end

    return false
end

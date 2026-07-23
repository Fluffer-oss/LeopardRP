ix.leopardrp = ix.leopardrp or {}
ix.leopardrp.auth = ix.leopardrp.auth or {}

local auth = ix.leopardrp.auth

local AUTH_WORDS = {
    "Alpha",
    "Beta",
    "Gamma",
    "Delta",
    "Omega",
    "Sigma",
    "Theta",
    "Kappa"
}

local AUTH_WORDS_BY_RANK_ID = {
    cadet = "Alpha",
    ensign = "Sigma",
    lieutenant_junior_grade = "Sigma",
    lieutenant = "Omega",
    lieutenant_commander = "Omega",
    commander = "Kappa",
    captain = "Kappa",
    admiral = "Kappa"
}

local function trim(value)
    local text = tostring(value or "")

    if (string.Trim) then
        return string.Trim(text)
    end

    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function titleCaseWord(value)
    local cleaned = trim(value):gsub("%s+", " ")

    if (cleaned == "") then
        return ""
    end

    return (cleaned:gsub("(%a)([%w_']*)", function(firstCharacter, remainder)
        return firstCharacter:upper() .. remainder:lower()
    end))
end

local function letterSeed(value)
    local total = 0

    for index = 1, #value do
        total = total + value:byte(index)
    end

    return total
end

function auth.GetPersonnelNumber(seedText)
    local seed = tostring(seedText or os.time())
    return 100 + (letterSeed(seed) % 900)
end

function auth.GetAuthChecksum(lastName, personnelNumber, codeWord)
    local seed = string.lower(trim(lastName)) .. tostring(personnelNumber or 0) .. tostring(codeWord or "")
    return letterSeed(seed) % 100
end

function auth.ResolveAuthClearanceWord(rankID, assignment, overrideWord, seedText)
    local normalizedOverride = titleCaseWord(overrideWord)

    if (normalizedOverride ~= "" and normalizedOverride ~= "Auto") then
        return normalizedOverride
    end

    local assignmentText = string.lower(trim(assignment))

    if (assignmentText:find("engineering", 1, true)) then
        return "Gamma"
    end

    local normalizedRankID = string.lower(trim(rankID))
    return AUTH_WORDS_BY_RANK_ID[normalizedRankID] or AUTH_WORDS[(letterSeed(tostring(seedText or normalizedRankID)) % #AUTH_WORDS) + 1]
end

function auth.GenerateAuthCode(lastName, personnelNumber, seedText, rankID, assignment, overrideWord)
    local normalizedLastName = titleCaseWord(lastName)
    local normalizedPersonnelNumber = math.Clamp(tonumber(personnelNumber) or auth.GetPersonnelNumber(seedText or normalizedLastName), 100, 999)
    local authWord = auth.ResolveAuthClearanceWord(rankID, assignment, overrideWord, seedText or normalizedLastName .. tostring(normalizedPersonnelNumber))
    local checksum = auth.GetAuthChecksum(normalizedLastName, normalizedPersonnelNumber, authWord)

    return string.format("%s-%03d-%s-%02d", normalizedLastName ~= "" and normalizedLastName or "Unknown", normalizedPersonnelNumber, authWord, checksum)
end

function auth.GetLastName(fullName)
    local cleaned = trim(fullName)

    if (cleaned == "") then
        return ""
    end

    return titleCaseWord(cleaned:match("([^%s]+)$") or cleaned)
end

function auth.GeneratePayloadAuthCode(payload)
    payload = istable(payload) and payload or {}

    local fullName = trim(payload.name)
    local firstName = trim(payload.firstName)
    local explicitLastName = trim(payload.lastName)
    local lastName = explicitLastName ~= "" and explicitLastName or auth.GetLastName(fullName)

    if fullName == "" then
        fullName = string.Trim(string.format("%s %s", firstName, lastName))
    end

    local division = tostring(payload.division or "Starfleet Academy")
    local rankID = tostring(payload.rankID or payload.rankId or payload.rank or (division == "Starfleet Academy" and "cadet" or "ensign"))
    if LeopardRP and LeopardRP.NormalizeRankID then
        rankID = tostring(LeopardRP.NormalizeRankID(rankID) or rankID)
    end

    local customData = istable(payload.customData) and payload.customData or {}
    local assignment = tostring(payload.assignment or customData.assignment or division)
    local clearanceWord = tostring(payload.clearanceWord or customData.clearanceWord or "Auto")
    local personnelNumber = math.Clamp(tonumber(payload.personnelNumber) or auth.GetPersonnelNumber(fullName ~= "" and fullName or lastName), 100, 999)

    return auth.GenerateAuthCode(lastName ~= "" and lastName or fullName, personnelNumber, fullName, rankID, assignment, clearanceWord)
end
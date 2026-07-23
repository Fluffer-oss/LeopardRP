LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}

LeopardRP.Config.UseSchemaClassRanks = LeopardRP.Config.UseSchemaClassRanks ~= false

LeopardRP.Ranks = LeopardRP.Ranks or {
    { ID = "cadet", Name = "Cadet", Short = "CDT", Order = 0 },
    { ID = "crewman_first_class", Name = "Crewman, First Class", Short = "CRW", Order = 1 },
    { ID = "petty_officer_second_class", Name = "Petty Officer, Second Class", Short = "PO2", Order = 2 },
    { ID = "petty_officer_first_class", Name = "Petty Officer, First Class", Short = "PO1", Order = 3 },
    { ID = "chief_petty_officer", Name = "Chief Petty Officer", Short = "CPO", Order = 4 },
    { ID = "senior_chief_petty_officer", Name = "Senior Chief Petty Officer", Short = "SCPO", Order = 5 },
    { ID = "master_chief_petty_officer", Name = "Master Chief Petty Officer", Short = "MCPO", Order = 6 },
    { ID = "warrant_officer", Name = "Warrant Officer", Short = "WO", Order = 7 },
    { ID = "ensign", Name = "Ensign", Short = "ENS", Order = 8 },
    { ID = "lieutenant_junior_grade", Name = "Lieutenant, Junior Grade", Short = "LTJG", Order = 9 },
    { ID = "lieutenant", Name = "Lieutenant", Short = "LT", Order = 10 },
    { ID = "lieutenant_commander", Name = "Lieutenant Commander", Short = "LCDR", Order = 11 },
    { ID = "commander", Name = "Commander", Short = "CDR", Order = 12 },
    { ID = "captain", Name = "Captain", Short = "CAPT", Order = 13 },
    { ID = "fleet_captain", Name = "Fleet Captain", Short = "FCAPT", Order = 14 },
    { ID = "commodore", Name = "Commodore", Short = "COMO", Order = 15 },
    { ID = "rear_admiral", Name = "Rear Admiral", Short = "RADM", Order = 16 },
    { ID = "vice_admiral", Name = "Vice Admiral", Short = "VADM", Order = 17 },
    { ID = "admiral", Name = "Admiral", Short = "ADM", Order = 18 },
    { ID = "fleet_admiral", Name = "Fleet Admiral", Short = "FADM", Order = 19 }
}

local LegacyRankAliases = {
    crewman = "crewman_first_class"
}

local RankPipBodygroupMap = {
    fleet_captain = 18,
    captain = 17,
    commander = 16,
    lieutenant_commander = 15,
    lieutenant = 14,
    lieutenant_junior_grade = 13,
    ensign = 12,
    warrant_officer = 11,
    master_chief_petty_officer = 9,
    senior_chief_petty_officer = 8,
    chief_petty_officer = 7,
    petty_officer_first_class = 6,
    petty_officer_second_class = 5,
    crewman_first_class = 4
}

local AdmiralRankBodygroupMap = {
    commodore = 1,
    rear_admiral = 2,
    vice_admiral = 3,
    admiral = 4,
    fleet_admiral = 5
}

local RankByID = {}
local RankByOrder = {}
local ActiveRanks = {}
local ActiveSignature = ""

local function NormalizeRankIDRaw(rankID)
    local normalizedID = string.lower(string.Trim(tostring(rankID or "")))

    if (normalizedID == "") then
        return "cadet"
    end

    normalizedID = string.gsub(normalizedID, "[^%w%s_%-]", "")
    normalizedID = string.gsub(normalizedID, "[%s%-]+", "_")
    normalizedID = string.gsub(normalizedID, "_+", "_")

    return LegacyRankAliases[normalizedID] or normalizedID
end

local function BuildRankSignature(ranks)
    local parts = {}

    for index, rankData in ipairs(ranks or {}) do
        parts[index] = string.format("%s:%s:%s", tostring(rankData.ID or ""), tostring(rankData.Order or -1), tostring(rankData.Short or ""))
    end

    return table.concat(parts, "|")
end

local function BuildClassRankList()
    if (!LeopardRP.Config.UseSchemaClassRanks) then
        return {}
    end

    if (!ix or !ix.class or !istable(ix.class.list)) then
        return {}
    end

    local classRanks = {}

    for _, classData in pairs(ix.class.list) do
        if (istable(classData) and classData.leopardrpUseAsRank == true) then
            local rankID = NormalizeRankIDRaw(classData.leopardrpRankID or classData.uniqueID or classData.name)
            local rankName = string.Trim(tostring(classData.leopardrpRankName or classData.name or rankID))
            local rankShort = string.Trim(tostring(classData.leopardrpRankShort or classData.short or ""))
            local rankOrder = tonumber(classData.leopardrpRankOrder)

            if (rankName == "") then
                rankName = rankID
            end

            classRanks[#classRanks + 1] = {
                ID = rankID,
                Name = rankName,
                Short = rankShort,
                Order = rankOrder
            }
        end
    end

    if (#classRanks == 0) then
        return classRanks
    end

    table.sort(classRanks, function(a, b)
        local aOrder = tonumber(a.Order)
        local bOrder = tonumber(b.Order)

        if (aOrder and bOrder) then
            if (aOrder == bOrder) then
                return string.lower(tostring(a.ID)) < string.lower(tostring(b.ID))
            end

            return aOrder < bOrder
        end

        if (aOrder) then
            return true
        end

        if (bOrder) then
            return false
        end

        return string.lower(tostring(a.ID)) < string.lower(tostring(b.ID))
    end)

    local nextOrder = 0

    for _, rankData in ipairs(classRanks) do
        if (rankData.Order == nil) then
            rankData.Order = nextOrder
            nextOrder = nextOrder + 1
        else
            rankData.Order = math.floor(rankData.Order)
            nextOrder = math.max(nextOrder, rankData.Order + 1)
        end
    end

    return classRanks
end

local function RebuildRankLookupIfNeeded()
    local resolvedRanks = BuildClassRankList()

    if (#resolvedRanks == 0) then
        resolvedRanks = LeopardRP.Ranks or {}
    end

    local signature = BuildRankSignature(resolvedRanks)

    if (signature == ActiveSignature) then
        return
    end

    ActiveSignature = signature
    ActiveRanks = {}
    RankByID = {}
    RankByOrder = {}

    for index, rankData in ipairs(resolvedRanks) do
        local normalizedID = NormalizeRankIDRaw(rankData.ID)
        local normalizedOrder = math.floor(tonumber(rankData.Order) or (index - 1))
        local normalizedRank = {
            ID = normalizedID,
            Name = tostring(rankData.Name or normalizedID),
            Short = tostring(rankData.Short or ""),
            Order = normalizedOrder
        }

        ActiveRanks[#ActiveRanks + 1] = normalizedRank
        RankByID[normalizedID] = normalizedRank
        RankByOrder[normalizedOrder] = normalizedRank
    end
end

function LeopardRP.GetRankByID(rankID)
    RebuildRankLookupIfNeeded()
    return RankByID[LeopardRP.NormalizeRankID(rankID)]
end

function LeopardRP.GetRankByOrder(order)
    RebuildRankLookupIfNeeded()
    return RankByOrder[tonumber(order) or 0]
end

function LeopardRP.GetRankOrder(rankID)
    local rankData = LeopardRP.GetRankByID(rankID)
    return rankData and rankData.Order or nil
end

function LeopardRP.GetRankName(rankID)
    local rankData = LeopardRP.GetRankByID(rankID)
    return rankData and rankData.Name or tostring(rankID or "")
end

function LeopardRP.GetRankList()
    RebuildRankLookupIfNeeded()
    return table.Copy(ActiveRanks)
end

function LeopardRP.GetStartingRankID(ply, profile)
    local rankCap = "lieutenant_commander"
    local minimumRank = "cadet"

    profile = profile or {}
    local highestOrder = 0

    if istable(profile.characters) then
        for _, characterData in pairs(profile.characters) do
            local characterOrder = LeopardRP.GetRankOrder(characterData.rankID)
            if characterOrder and characterOrder > highestOrder then
                highestOrder = characterOrder
            end
        end
    end

    if highestOrder <= 0 then
        return minimumRank
    end

    local targetOrder = math.max(highestOrder - 1, LeopardRP.GetRankOrder(minimumRank) or 1)
    targetOrder = math.min(targetOrder, LeopardRP.GetRankOrder(rankCap) or targetOrder)

    return (LeopardRP.GetRankByOrder(targetOrder) or LeopardRP.GetRankByID(minimumRank) or { ID = minimumRank }).ID
end

function LeopardRP.GetRankDisplayText(rankID)
    return LeopardRP.GetRankName(rankID)
end

function LeopardRP.NormalizeRankID(rankID)
    RebuildRankLookupIfNeeded()

    local normalizedID = NormalizeRankIDRaw(rankID)
    if RankByID[normalizedID] then
        return normalizedID
    end

    return normalizedID
end

function LeopardRP.GetRankShort(rankID)
    local rankData = LeopardRP.GetRankByID(rankID)
    return rankData and rankData.Short or ""
end

function LeopardRP.GetRankPipBodygroup(rankID)
    local normalizedID = LeopardRP.NormalizeRankID(rankID)
    return RankPipBodygroupMap[normalizedID]
end

function LeopardRP.GetAdmiralRankBodygroup(rankID)
    local normalizedID = LeopardRP.NormalizeRankID(rankID)
    return AdmiralRankBodygroupMap[normalizedID] or 0
end
LeopardRP = LeopardRP or {}
LeopardRP.Modules = LeopardRP.Modules or {}
LeopardRP.Config = LeopardRP.Config or {}
LeopardRP.CharacterCreation = LeopardRP.CharacterCreation or {}
LeopardRP.Modules["CharacterCreation"] = true

local CharacterCreation = LeopardRP.CharacterCreation

CharacterCreation.Bodies = CharacterCreation.Bodies or {}
CharacterCreation.Heads = CharacterCreation.Heads or {}
CharacterCreation.HeadGenderRules = CharacterCreation.HeadGenderRules or {
    Human = {
        Female = { 1, 2, 3, 4 }
    },
    Bajoran = {
        Female = { 2 }
    },
    Orion = {
        Female = { 2 }
    },
    Caitian = {
        Female = {}
    },
    Denobulan = {
        Female = {}
    },
    Trill = {
        Female = {}
    },
    Vulcan = {
        Female = {}
    }
}
CharacterCreation.SpeciesOrder = CharacterCreation.SpeciesOrder or {
    "Human",
    "Vulcan",
    "Andorian",
    "Bajoran",
    "Bolian",
    "Caitian",
    "Denobulan",
    "Klingon",
    "Orion",
    "Trill"
}

CharacterCreation.Divisions = CharacterCreation.Divisions or {
    "Command",
    "Operations",
    "Sciences",
    "Starfleet Academy",
    "Cadet",
    "Admiral"
}

CharacterCreation.Genders = CharacterCreation.Genders or {
    "Male",
    "Female"
}

CharacterCreation.UniformTypes = CharacterCreation.UniformTypes or {
    "Standard",
    "Dress",
    "EVA"
}

function CharacterCreation.GetSpeciesList()
    local speciesList = {}
    for _, speciesName in ipairs(CharacterCreation.SpeciesOrder or {}) do
        local headModels = CharacterCreation.Heads[speciesName]
        if istable(headModels) and #headModels > 0 then
            table.insert(speciesList, speciesName)
        end
    end

    if #speciesList <= 0 then
        for speciesName, headModels in pairs(CharacterCreation.Heads or {}) do
            if istable(headModels) and #headModels > 0 then
                table.insert(speciesList, tostring(speciesName))
            end
        end
        table.sort(speciesList)
    end

    return speciesList
end

function CharacterCreation.GetDivisionList()
    return table.Copy(CharacterCreation.Divisions)
end

function CharacterCreation.GetGenderList()
    return table.Copy(CharacterCreation.Genders)
end

function CharacterCreation.GetUniformTypeList()
    return table.Copy(CharacterCreation.UniformTypes)
end

function CharacterCreation.IsValidSpecies(species)
    if not table.HasValue(CharacterCreation.SpeciesOrder, species) then
        return false
    end

    local headModels = CharacterCreation.Heads[species]
    return istable(headModels) and #headModels > 0
end

function CharacterCreation.GetHeadModels(species)
    local headModels = CharacterCreation.Heads[species]
    if not istable(headModels) then
        return {}
    end

    return table.Copy(headModels)
end

function CharacterCreation.GetHeadGender(species, headIndex)
    local index = tonumber(headIndex) or 0
    if index <= 0 then return "Male" end

    local speciesRules = CharacterCreation.HeadGenderRules[species]
    if istable(speciesRules) and istable(speciesRules.Female) and table.HasValue(speciesRules.Female, index) then
        return "Female"
    end

    return "Male"
end

function CharacterCreation.GetHeadChoices(species, gender)
    local normalizedGender = string.Trim(tostring(gender or "Male"))
    local headModels = CharacterCreation.GetHeadModels(species)
    local choices = {}

    for index, modelPath in ipairs(headModels) do
        local headGender = CharacterCreation.GetHeadGender(species, index)
        if normalizedGender == "" or headGender == normalizedGender then
            table.insert(choices, {
                sourceIndex = index,
                model = modelPath,
                gender = headGender
            })
        end
    end

    return choices
end

function CharacterCreation.SpeciesSupportsGenderHeads(species, gender)
    local choices = CharacterCreation.GetHeadChoices(species, gender)
    return #choices > 0
end

function CharacterCreation.GetCompatibleGender(species, preferredGender)
    local requested = string.Trim(tostring(preferredGender or "Male"))
    if requested == "" then
        requested = "Male"
    end

    if CharacterCreation.SpeciesSupportsGenderHeads(species, requested) then
        return requested
    end

    if CharacterCreation.SpeciesSupportsGenderHeads(species, "Male") then
        return "Male"
    end

    if CharacterCreation.SpeciesSupportsGenderHeads(species, "Female") then
        return "Female"
    end

    return requested
end

function CharacterCreation.GetHeadModelBySourceIndex(species, sourceIndex)
    local headModels = CharacterCreation.GetHeadModels(species)
    return headModels[tonumber(sourceIndex) or 0] or ""
end

function CharacterCreation.GetBodyModel(division, gender, uniformType)
    if division == "Starfleet Academy" then
        division = "Cadet"
    end

    local divisionTable = CharacterCreation.Bodies[division]
    if not istable(divisionTable) then return nil end

    local genderTable = divisionTable[gender]
    if not istable(genderTable) then return nil end

    return genderTable[uniformType]
end

function CharacterCreation.GetRankList()
    return LeopardRP.GetRankList and LeopardRP.GetRankList() or {}
end

function CharacterCreation.GetRankName(rankID)
    return LeopardRP.GetRankName and LeopardRP.GetRankName(rankID) or tostring(rankID or "")
end

function CharacterCreation.GetStartingRankID(ply, profile)
    return LeopardRP.GetStartingRankID and LeopardRP.GetStartingRankID(ply, profile) or "cadet"
end

local function FindRankBodygroupID(entity)
    if not IsValid(entity) then return nil end

    if entity.FindBodygroupByName then
        local bodygroupID = entity:FindBodygroupByName("rank")
        if bodygroupID ~= nil and bodygroupID >= 0 then
            return bodygroupID
        end
    end

    if entity.GetBodyGroups then
        for _, bodygroupData in ipairs(entity:GetBodyGroups() or {}) do
            if string.lower(tostring(bodygroupData.name or "")) == "rank" then
                return tonumber(bodygroupData.id) or nil
            end
        end
    end

    return nil
end

function CharacterCreation.ApplyRankBodygroup(entity, rankID, division, bodyModel)
    if not IsValid(entity) then return end

    local rankBodygroupID = FindRankBodygroupID(entity)
    if rankBodygroupID == nil then return end

    local divisionName = string.Trim(tostring(division or ""))
    local modelPath = string.lower(tostring(bodyModel or (entity.GetModel and entity:GetModel()) or ""))
    local isAdmiralModel = divisionName == "Admiral" or string.find(modelPath, "admiral", 1, true) ~= nil
    local isCadetModel = divisionName == "Cadet" or divisionName == "Starfleet Academy" or string.find(modelPath, "cadet", 1, true) ~= nil

    local value = 0
    if isCadetModel then
        value = 1
    elseif isAdmiralModel and LeopardRP.GetAdmiralRankBodygroup then
        value = tonumber(LeopardRP.GetAdmiralRankBodygroup(rankID)) or 0
    elseif LeopardRP.GetRankPipBodygroup then
        value = tonumber(LeopardRP.GetRankPipBodygroup(rankID)) or 0
    end

    if entity.SetBodygroup then
        entity:SetBodygroup(rankBodygroupID, math.max(0, value))
    end
end

function CharacterCreation.ResolveCharacterAppearance(characterRecord)
    if not istable(characterRecord) then return nil, nil end

    local preferredUniform = string.Trim(tostring(characterRecord.uniformType or "Standard"))
    if preferredUniform == "" then
        preferredUniform = "Standard"
    end

    local gender = CharacterCreation.GetCompatibleGender(characterRecord.species, characterRecord.gender)
    local bodyModel = CharacterCreation.GetBodyModel(characterRecord.division, gender, preferredUniform)
    local headModel = characterRecord.headModel

    if not CharacterCreation.IsValidSpecies(characterRecord.species) then
        return bodyModel, headModel
    end

    local headChoices = CharacterCreation.GetHeadChoices(characterRecord.species, gender)
    local allowedModels = {}
    local fallbackChoice = headChoices[1]
    for _, choice in ipairs(headChoices) do
        allowedModels[choice.model] = choice
    end

    if headModel == nil or headModel == "" then
        local preferredIndex = tonumber(characterRecord.headIndex) or 0
        for _, choice in ipairs(headChoices) do
            if choice.sourceIndex == preferredIndex then
                fallbackChoice = choice
                break
            end
        end
        headModel = fallbackChoice and fallbackChoice.model or ""
    end

    if not LeopardRP.Config.AllowCustomHeads and headModel ~= "" and not allowedModels[headModel] then
        headModel = fallbackChoice and fallbackChoice.model or ""
    end

    return bodyModel, headModel
end

function CharacterCreation.BuildCharacterPayload(characterRecord)
    local bodyModel, headModel = CharacterCreation.ResolveCharacterAppearance(characterRecord)

    return {
        id = characterRecord.id,
        firstName = characterRecord.firstName,
        middleName = characterRecord.middleName,
        lastName = characterRecord.lastName,
        name = characterRecord.name,
        backstory = characterRecord.backstory,
        personnelNumber = characterRecord.personnelNumber,
        authCode = characterRecord.authCode,
        species = characterRecord.species,
        headIndex = tonumber(characterRecord.headIndex) or 1,
        headModel = headModel or characterRecord.headModel or "",
        gender = characterRecord.gender,
        division = characterRecord.division,
        uniformType = characterRecord.uniformType,
        bodyModel = bodyModel or characterRecord.bodyModel or "",
        rank = characterRecord.rank,
        creationDate = characterRecord.creationDate,
        creationStardate = characterRecord.creationStardate,
        customData = istable(characterRecord.customData) and table.Copy(characterRecord.customData) or {},
        createdAt = characterRecord.createdAt,
        updatedAt = characterRecord.updatedAt
    }
end

function CharacterCreation.GetCharacterDisplayName(characterRecord)
    local rank = tostring(characterRecord and characterRecord.rank or "")
    local name = tostring(characterRecord and characterRecord.name or "Unnamed")

    if rank ~= "" then
        return string.format("%s - %s", rank, name)
    end

    return name
end

function CharacterCreation.ApplyHeadToPlayer(ply, headModel)
    if not IsValid(ply) then return false end
    if not LeopardRP.Config.EnableBonemerge then return false end
    if not headModel or headModel == "" then return false end

    if not util.IsValidModel(headModel) then return false end

    if CharacterCreation.RemoveHeadFromPlayer then
        CharacterCreation.RemoveHeadFromPlayer(ply)
    end

    if CharacterCreation.AttachHeadToPlayer then
        return CharacterCreation.AttachHeadToPlayer(ply, headModel)
    end

    return false
end
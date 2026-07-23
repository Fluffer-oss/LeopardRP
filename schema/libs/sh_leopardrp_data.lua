ix.leopardrp = ix.leopardrp or {}
ix.leopardrp.character = ix.leopardrp.character or {}

local characterData = ix.leopardrp.character

characterData.defaultSpecies = "Human"
characterData.defaultGender = "Male"
characterData.defaultDivision = "Starfleet Academy"
characterData.defaultUniformType = "Standard"

characterData.speciesOrder = {
    "Human",
    "Vulcan",
    "Andorian",
    "Bajoran",
    "Bolian",
    "Caitian",
    "Denobulan",
    "Klingon",
    "Orion",
    "Trill",
    "Gorn",
    "Aenar"
}

characterData.genders = {
    "Male",
    "Female"
}

characterData.divisions = {
    "Command",
    "Operations",
    "Sciences",
    "Engineering",
    "Medical",
    "Starfleet Academy",
    "Admiral"
}

characterData.uniformTypes = {
    "Standard",
    "Dress",
    "EVA"
}

characterData.headGenderRules = {
    Human = {
        Female = {1, 2, 3, 4}
    },
    Bajoran = {
        Female = {2}
    },
    Orion = {
        Female = {2}
    }
}

characterData.heads = {
    Bajoran = {
        "models/oninoni/star_trek/heads/bajorans/bajoran_01.mdl",
        "models/oninoni/star_trek/heads/bajorans/bajoran_female_01.mdl"
    },
    Bolian = {
        "models/oninoni/star_trek/heads/bolians/bolian_01.mdl",
        "models/oninoni/star_trek/heads/bolians/bolian_02.mdl",
        "models/oninoni/star_trek/heads/bolians/bolian_03.mdl",
        "models/oninoni/star_trek/heads/bolians/bolian_04.mdl"
    },
    Caitian = {
        "models/oninoni/star_trek/heads/caitian/caitian.mdl"
    },
    Denobulan = {
        "models/oninoni/star_trek/heads/denobulans/denobulan.mdl"
    },
    Orion = {
        "models/oninoni/star_trek/heads/orion/orion_01.mdl",
        "models/oninoni/star_trek/heads/orion/orion_female_01.mdl"
    },
    Trill = {
        "models/oninoni/star_trek/heads/trill/trill_01.mdl",
        "models/oninoni/star_trek/heads/trill/trill_02.mdl",
        "models/oninoni/star_trek/heads/trill/trill_03.mdl"
    },
    Vulcan = {
        "models/oninoni/star_trek/heads/vulcans/vulcan_01.mdl",
        "models/oninoni/star_trek/heads/vulcans/vulcan_02.mdl"
    },
    Human = {
        "models/oninoni/star_trek/heads/humans/female_01.mdl",
        "models/oninoni/star_trek/heads/humans/female_rochelle.mdl",
        "models/oninoni/star_trek/heads/humans/female_wraith.mdl",
        "models/oninoni/star_trek/heads/humans/female_zoey.mdl",
        "models/oninoni/star_trek/heads/humans/male_01.mdl",
        "models/oninoni/star_trek/heads/humans/male_02.mdl",
        "models/oninoni/star_trek/heads/humans/male_03.mdl",
        "models/oninoni/star_trek/heads/humans/male_04.mdl",
        "models/oninoni/star_trek/heads/humans/male_05.mdl",
        "models/oninoni/star_trek/heads/humans/male_06.mdl",
        "models/oninoni/star_trek/heads/humans/male_07.mdl",
        "models/oninoni/star_trek/heads/humans/male_08.mdl",
        "models/oninoni/star_trek/heads/humans/male_09.mdl",
        "models/oninoni/star_trek/heads/humans/male_louis.mdl",
        "models/oninoni/star_trek/heads/humans/male_mp1.mdl",
        "models/oninoni/star_trek/heads/humans/male_mp2.mdl",
        "models/oninoni/star_trek/heads/humans/male_mp3.mdl",
        "models/oninoni/star_trek/heads/humans/male_plr.mdl",
        "models/oninoni/star_trek/heads/humans/male_plr2.mdl"
    },
    Andorian = {
        "models/oninoni/star_trek/heads/andorians/andorian_01.mdl",
        "models/oninoni/star_trek/heads/andorians/aenar_01.mdl"
    },
    Aenar = {
        "models/oninoni/star_trek/heads/andorians/aenar_01.mdl"
    },
    Gorn = {
        "models/characters/gorn_male.mdl",
        "models/characters/gorn_female.mdl"
    },
    Klingon = {
        "models/oninoni/star_trek/heads/klingons/klingon_01.mdl"
    }
}

characterData.bodies = {
    Command = {
        Male = {
            Standard = "models/cheek/startrek/male_red/startrek_male_red.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_red/startrek_male_red.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/cheek/startrek/female_red/startrek_female_red.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_red/startrek_female_red.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    Operations = {
        Male = {
            Standard = "models/cheek/startrek/male_yellow/startrek_male_yellow.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_yellow/startrek_male_yellow.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/cheek/startrek/female_yellow/startrek_female_yellow.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_yellow/startrek_female_yellow.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    Engineering = {
        Male = {
            Standard = "models/cheek/startrek/male_yellow/startrek_male_yellow.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_yellow/startrek_male_yellow.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/cheek/startrek/female_yellow/startrek_female_yellow.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_yellow/startrek_female_yellow.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    Sciences = {
        Male = {
            Standard = "models/cheek/startrek/male_blue/startrek_male_blue.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_blue/startrek_male_blue.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/cheek/startrek/female_blue/startrek_female_blue.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_blue/startrek_female_blue.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    Medical = {
        Male = {
            Standard = "models/cheek/startrek/male_blue/startrek_male_blue.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_blue/startrek_male_blue.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/cheek/startrek/female_blue/startrek_female_blue.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_blue/startrek_female_blue.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    ["Starfleet Academy"] = {
        Male = {
            Standard = "models/nova_canterra/star_trek/playermodels/bodies/2385/standard/male_cadet/startrek_male_cadet.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_cadet/startrek_male_cadet.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/nova_canterra/star_trek/playermodels/bodies/2385/standard/female_cadet/startrek_female_cadet.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_cadet/startrek_female_cadet.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    },
    Admiral = {
        Male = {
            Standard = "models/nova_canterra/star_trek/playermodels/bodies/2385/standard/male_admiral/startrek_male_admiral.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/male_admiral/startrek_male_admiral.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        },
        Female = {
            Standard = "models/nova_canterra/star_trek/playermodels/bodies/2385/standard/female_admiral/startrek_female_admiral.mdl",
            Dress = "models/nova_canterra/star_trek/playermodels/bodies/2385/dress/female_admiral/startrek_female_admiral.mdl",
            EVA = "models/player/startrek_female_spacesuit.mdl"
        }
    }
}

local function inList(value, list)
    for _, listValue in ipairs(list) do
        if (listValue == value) then
            return true
        end
    end

    return false
end

local function hasValue(list, needle)
    for _, value in ipairs(list or {}) do
        if (value == needle) then
            return true
        end
    end

    return false
end

local function clamp(value, minValue, maxValue)
    if (value < minValue) then
        return minValue
    end

    if (value > maxValue) then
        return maxValue
    end

    return value
end

function characterData.NormalizeSpecies(species)
    species = tostring(species or "")

    if (characterData.heads[species]) then
        return species
    end

    return characterData.defaultSpecies
end

function characterData.NormalizeGender(gender, species)
    species = characterData.NormalizeSpecies(species)
    gender = tostring(gender or "")

    if (!inList(gender, characterData.genders)) then
        gender = characterData.defaultGender
    end

    local choices = characterData.GetHeadChoices(species, gender)

    if (#choices > 0) then
        return gender
    end

    for _, fallback in ipairs(characterData.genders) do
        if (#characterData.GetHeadChoices(species, fallback) > 0) then
            return fallback
        end
    end

    return characterData.defaultGender
end

function characterData.NormalizeDivision(division)
    division = tostring(division or "")

    if (inList(division, characterData.divisions)) then
        return division
    end

    return characterData.defaultDivision
end

function characterData.NormalizeUniformType(uniformType)
    uniformType = tostring(uniformType or "")

    if (inList(uniformType, characterData.uniformTypes)) then
        return uniformType
    end

    return characterData.defaultUniformType
end

function characterData.GetHeadGender(species, headIndex)
    species = characterData.NormalizeSpecies(species)
    headIndex = tonumber(headIndex) or 1

    local rules = characterData.headGenderRules[species]

    if (rules and rules.Female and hasValue(rules.Female, headIndex)) then
        return "Female"
    end

    return "Male"
end

function characterData.GetHeadChoices(species, gender)
    species = characterData.NormalizeSpecies(species)
    gender = tostring(gender or "")

    local choices = {}

    for index, modelPath in ipairs(characterData.heads[species] or {}) do
        local headGender = characterData.GetHeadGender(species, index)

        if (gender == "" or headGender == gender) then
            choices[#choices + 1] = {
                sourceIndex = index,
                model = modelPath,
                gender = headGender
            }
        end
    end

    return choices
end

function characterData.GetHeadCount(species, gender)
    return #characterData.GetHeadChoices(species, gender)
end

function characterData.GetHeadModel(species, gender, headIndex)
    species = characterData.NormalizeSpecies(species)
    gender = characterData.NormalizeGender(gender, species)

    local choices = characterData.GetHeadChoices(species, gender)

    if (#choices == 0) then
        return "", 1
    end

    local requested = tonumber(headIndex) or 1
    local clampedListIndex = clamp(requested, 1, #choices)
    local choice = choices[clampedListIndex]

    return tostring(choice.model or ""), tonumber(choice.sourceIndex) or 1
end

function characterData.GetBodyModel(division, gender, uniformType)
    division = characterData.NormalizeDivision(division)
    gender = characterData.NormalizeGender(gender, characterData.defaultSpecies)
    uniformType = characterData.NormalizeUniformType(uniformType)

    local divisionData = characterData.bodies[division] or characterData.bodies[characterData.defaultDivision]

    if (type(divisionData) ~= "table") then
        return ""
    end

    local genderData = divisionData[gender] or divisionData[characterData.defaultGender]

    if (type(genderData) ~= "table") then
        return ""
    end

    return tostring(genderData[uniformType] or genderData[characterData.defaultUniformType] or "")
end

if (ix.anim and ix.anim.SetModelClass) then
    for _, divisionData in pairs(characterData.bodies or {}) do
        if (istable(divisionData)) then
            for _, genderData in pairs(divisionData) do
                if (istable(genderData)) then
                    for _, modelPath in pairs(genderData) do
                        if (isstring(modelPath) and modelPath ~= "") then
                            ix.anim.SetModelClass(modelPath, "player")
                        end
                    end
                end
            end
        end
    end
end

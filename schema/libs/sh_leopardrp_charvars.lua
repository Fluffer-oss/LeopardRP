ix.leopardrp = ix.leopardrp or {}
ix.leopardrp.character = ix.leopardrp.character or {}

local data = ix.leopardrp.character

local function clamp(value, minValue, maxValue)
    if (value < minValue) then
        return minValue
    end

    if (value > maxValue) then
        return maxValue
    end

    return value
end

local function addChoiceCombo(container, options, defaultValue, onSelect)
    local combo = container:Add("DComboBox")
    combo:Dock(TOP)

    for _, option in ipairs(options) do
        combo:AddChoice(option)
    end

    combo:SetValue(defaultValue)
    combo.OnSelect = function(_, _, value)
        onSelect(value)
    end

    return combo
end

local function getAvailableGenders(species)
    local available = {}

    for _, gender in ipairs(data.genders) do
        if (#data.GetHeadChoices(species, gender) > 0) then
            available[#available + 1] = gender
        end
    end

    if (#available == 0) then
        available[1] = data.defaultGender
    end

    return available
end

local function splitNameParts(fullName)
    local cleaned = string.Trim(tostring(fullName or ""))

    if cleaned == "" then
        return "", ""
    end

    local firstName, lastName = string.match(cleaned, "^(%S+)%s+(.+)$")
    if not firstName then
        return cleaned, ""
    end

    return tostring(firstName or ""), tostring(lastName or "")
end

if (ix.char.vars.name and !ix.char.vars.name.LeopardRPSplitNameOverride) then
    local baseValidate = ix.char.vars.name.OnValidate

    ix.char.vars.name.OnDisplay = function(self, container, payload)
        local panel = container:Add("DPanel")
        panel:Dock(TOP)
        panel:SetTall(128)
        panel.Paint = nil

        panel.firstName = panel:Add("ixTextEntry")
        panel.firstName:Dock(TOP)
        panel.firstName:SetTall(56)
        panel.firstName:SetPlaceholderText("First Name")
        panel.firstName:SetFont("ixMenuButtonHugeFont")

        panel.lastName = panel:Add("ixTextEntry")
        panel.lastName:Dock(TOP)
        panel.lastName:DockMargin(0, 10, 0, 0)
        panel.lastName:SetTall(56)
        panel.lastName:SetPlaceholderText("Last Name")
        panel.lastName:SetFont("ixMenuButtonHugeFont")

        local function applyCombinedName()
            local firstName = string.Trim(tostring(panel.firstName:GetValue() or ""))
            local lastName = string.Trim(tostring(panel.lastName:GetValue() or ""))
            local combined = string.Trim(string.format("%s %s", firstName, lastName))

            payload:Set("firstName", firstName)
            payload:Set("lastName", lastName)
            payload:Set("name", combined)
        end

        panel.firstName.OnLoseFocus = applyCombinedName
        panel.lastName.OnLoseFocus = applyCombinedName
        panel.firstName.OnEnter = applyCombinedName
        panel.lastName.OnEnter = applyCombinedName

        local initialFirst = string.Trim(tostring(payload.firstName or ""))
        local initialLast = string.Trim(tostring(payload.lastName or ""))

        if initialFirst == "" and initialLast == "" then
            initialFirst, initialLast = splitNameParts(payload.name)
        end

        panel.firstName:SetText(initialFirst)
        panel.lastName:SetText(initialLast)
        applyCombinedName()

        return panel
    end

    ix.char.vars.name.OnValidate = function(self, value, payload, client)
        local firstName = string.Trim(tostring(payload and payload.firstName or ""))
        local lastName = string.Trim(tostring(payload and payload.lastName or ""))
        local combined = string.Trim(string.format("%s %s", firstName, lastName))

        if combined == "" then
            combined = tostring(value or "")
        end

        if payload then
            payload.firstName = firstName
            payload.lastName = lastName
            payload.name = combined
        end

        if isfunction(baseValidate) then
            return baseValidate(self, combined, payload, client)
        end

        return combined
    end

    ix.char.vars.name.OnPostSetup = nil
    ix.char.vars.name.LeopardRPSplitNameOverride = true
end

if (!ix.char.vars.species) then
    ix.char.RegisterVar("species", {
        field = "species",
        fieldType = ix.type.string,
        default = data.defaultSpecies,
        index = 9,
        OnDisplay = function(self, container, payload)
            local combo = addChoiceCombo(container, data.speciesOrder, data.defaultSpecies, function(value)
                payload:Set("species", data.NormalizeSpecies(value))
            end)

            local selected = data.NormalizeSpecies(payload.species or data.defaultSpecies)
            combo:SetValue(selected)
            payload:Set("species", selected)

            return combo
        end,
        OnValidate = function(self, value)
            value = data.NormalizeSpecies(value)

            if (!data.heads[value]) then
                return false, "invalid", "species"
            end

            return value
        end
    })
end

if (!ix.char.vars.gender) then
    ix.char.RegisterVar("gender", {
        field = "gender",
        fieldType = ix.type.string,
        default = data.defaultGender,
        index = 10,
        OnDisplay = function(self, container, payload)
            local combo = container:Add("DComboBox")
            combo:Dock(TOP)

            local function refreshChoices(species)
                species = data.NormalizeSpecies(species or payload.species or data.defaultSpecies)

                if (combo.Clear) then
                    combo:Clear()
                end

                local options = getAvailableGenders(species)

                for _, option in ipairs(options) do
                    combo:AddChoice(option)
                end

                local resolved = data.NormalizeGender(payload.gender or data.defaultGender, species)
                combo:SetValue(resolved)
                payload:Set("gender", resolved)
            end

            payload:AddHook("species", function(species)
                refreshChoices(species)
            end)

            combo.OnSelect = function(_, _, value)
                local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
                payload:Set("gender", data.NormalizeGender(value, species))
            end

            local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
            refreshChoices(species)

            return combo
        end,
        OnValidate = function(self, value, payload)
            local species = data.NormalizeSpecies(payload.species)
            return data.NormalizeGender(value, species)
        end
    })
end

if (!ix.char.vars.age) then
    ix.char.RegisterVar("age", {
        field = "age",
        fieldType = ix.type.number,
        default = 24,
        index = 14,
        category = "overview",
        OnDisplay = function(self, container, payload)
            local panel = container:Add("DPanel")
            panel:Dock(TOP)
            panel:SetTall(244)

            panel.summary = panel:Add("DLabel")
            panel.summary:Dock(TOP)
            panel.summary:SetWrap(true)
            panel.summary:SetAutoStretchVertical(true)
            panel.summary:SetFont("ixSmallFont")
            panel.summary:SetContentAlignment(7)
            panel.summary:SetTall(108)

            panel.entry = panel:Add("ixTextEntry")
            panel.entry:Dock(TOP)
            panel.entry:DockMargin(0, 12, 0, 0)
            panel.entry:SetFont("ixMenuButtonHugeFont")
            panel.entry:SetUpdateOnType(false)
            panel.isRefreshing = false

            panel.slider = panel:Add("DNumSlider")
            panel.slider:Dock(TOP)
            panel.slider:DockMargin(0, 10, 0, 0)
            panel.slider:SetText("AGE")
            panel.slider:SetDecimals(0)

            local function getAgeRange(species)
                species = data.NormalizeSpecies(species)

                if (species == "Vulcan") then
                    return 24, 180
                end

                return 24, 100
            end

            local function refreshOverview()
                local firstName = string.Trim(tostring(payload.firstName or ""))
                local lastName = string.Trim(tostring(payload.lastName or ""))
                local name = string.Trim(tostring(payload.name or ""))
                if (name == "") then
                    name = string.Trim(string.format("%s %s", firstName, lastName))
                end
                local description = tostring(payload.description or "")
                local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
                local gender = data.NormalizeGender(payload.gender or data.defaultGender, species)
                local division = data.NormalizeDivision(payload.division or data.defaultDivision)
                local uniformType = data.NormalizeUniformType(payload.uniformType or data.defaultUniformType)
                local headIndex = clamp(tonumber(payload.headIndex) or 1, 1, math.max(1, data.GetHeadCount(species, gender)))
                local minAge, maxAge = getAgeRange(species)
                local ageValue = clamp(math.floor(tonumber(payload.age) or minAge), minAge, maxAge)
                local authCode = tostring((ix.leopardrp.auth and ix.leopardrp.auth.GeneratePayloadAuthCode and ix.leopardrp.auth.GeneratePayloadAuthCode(payload)) or payload.authCode or "")

                panel.isRefreshing = true
                panel.entry:SetText(tostring(ageValue))
                panel.slider:SetValue(ageValue)
                panel.isRefreshing = false

                if (tonumber(payload.age) ~= ageValue) then
                    payload:Set("age", ageValue)
                end

                if (tostring(payload.authCode or "") ~= authCode) then
                    payload:Set("authCode", authCode)
                end

                panel.summary:SetText(string.format(
                    "Name: %s\nSpecies: %s\nGender: %s\nDivision: %s\nUniform: %s\nHead: %d\nAge: %d\nAuth Code: %s\nSummary: %s",
                    name ~= "" and name or "Pending",
                    species,
                    gender,
                    division,
                    uniformType,
                    headIndex,
                    ageValue,
                    authCode ~= "" and authCode or "Pending",
                    description ~= "" and string.sub(description, 1, 72) or "Pending"
                ))
            end

            local function commitAgeFromEntry()
                if (panel.isRefreshing) then
                    return
                end

                local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
                local minAge, maxAge = getAgeRange(species)
                local ageValue = clamp(math.floor(tonumber(panel.entry:GetValue()) or minAge), minAge, maxAge)

                payload:Set("age", ageValue)
                refreshOverview()
            end

            panel.entry.OnEnter = commitAgeFromEntry
            panel.entry.OnLoseFocus = commitAgeFromEntry

            panel.slider.OnValueChanged = function(_, value)
                if (panel.isRefreshing) then return end
                local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
                local minAge, maxAge = getAgeRange(species)
                local ageValue = clamp(math.floor(tonumber(value) or minAge), minAge, maxAge)
                payload:Set("age", ageValue)
                refreshOverview()
            end

            payload:AddHook("species", refreshOverview)
            payload:AddHook("gender", refreshOverview)
            payload:AddHook("name", refreshOverview)
            payload:AddHook("firstName", refreshOverview)
            payload:AddHook("lastName", refreshOverview)
            payload:AddHook("description", refreshOverview)
            payload:AddHook("division", refreshOverview)
            payload:AddHook("uniformType", refreshOverview)
            payload:AddHook("headIndex", refreshOverview)

            local minAge, maxAge = getAgeRange(data.NormalizeSpecies(payload.species or data.defaultSpecies))
            panel.slider:SetMin(minAge)
            panel.slider:SetMax(maxAge)

            refreshOverview()

            return panel
        end,
        OnValidate = function(self, value, payload)
            local species = data.NormalizeSpecies(payload.species)
            local minAge = 24
            local maxAge = species == "Vulcan" and 180 or 100

            return clamp(math.floor(tonumber(value) or minAge), minAge, maxAge)
        end
    })
end

if (!ix.char.vars.authCode) then
    ix.char.RegisterVar("authCode", {
        field = "auth_code",
        fieldType = ix.type.string,
        default = "",
        index = 15,
        bNoDisplay = true,
        OnValidate = function(self, value, payload)
            return tostring(ix.leopardrp.auth and ix.leopardrp.auth.GeneratePayloadAuthCode and ix.leopardrp.auth.GeneratePayloadAuthCode(payload) or "")
        end
    })
end

if (!ix.char.vars.division) then
    ix.char.RegisterVar("division", {
        field = "division",
        fieldType = ix.type.string,
        default = data.defaultDivision,
        index = 11,
        bNoDisplay = true,
        OnValidate = function(self, value)
            return data.NormalizeDivision(value)
        end
    })
end

if (!ix.char.vars.uniformType) then
    ix.char.RegisterVar("uniformType", {
        field = "uniform_type",
        fieldType = ix.type.string,
        default = data.defaultUniformType,
        index = 12,
        bNoDisplay = true,
        OnValidate = function(self, value)
            return data.NormalizeUniformType(value)
        end
    })
end

if (!ix.char.vars.headIndex) then
    ix.char.RegisterVar("headIndex", {
        field = "head_index",
        fieldType = ix.type.number,
        default = 1,
        index = 13,
        OnDisplay = function(self, container, payload)
            local panel = container:Add("DPanel")
            panel:Dock(TOP)
            panel:SetTall(56)

            panel.label = panel:Add("DLabel")
            panel.label:Dock(TOP)
            panel.label:SetText("HEAD")
            panel.label:SetFont("ixMenuButtonLabelFont")
            panel.label:SetContentAlignment(4)

            panel.slider = panel:Add("DNumSlider")
            panel.slider:Dock(TOP)
            panel.slider:SetText("")
            panel.slider:SetDecimals(0)

            local function refreshSlider()
                local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
                local gender = data.NormalizeGender(payload.gender or data.defaultGender, species)
                local choices = data.GetHeadChoices(species, gender)
                local count = #choices

                panel.slider:SetMin(1)
                panel.slider:SetMax(math.max(1, count))

                local value = clamp(tonumber(payload.headIndex) or 1, 1, math.max(1, count))
                panel.slider:SetValue(value)

                payload:Set("headIndex", value)
                panel.label:SetText(string.format("HEAD (%d available)", count))
                panel.slider:SetEnabled(count > 0)
            end

            panel.slider.OnValueChanged = function(_, value)
                payload:Set("headIndex", math.max(1, math.floor(tonumber(value) or 1)))
            end

            payload:AddHook("species", refreshSlider)
            payload:AddHook("gender", refreshSlider)

            refreshSlider()
            return panel
        end,
        OnValidate = function(self, value, payload)
            local species = data.NormalizeSpecies(payload.species)
            local gender = data.NormalizeGender(payload.gender, species)
            local count = math.max(1, data.GetHeadCount(species, gender))

            return clamp(math.floor(tonumber(value) or 1), 1, count)
        end
    })
end

if (!ix.char.vars.bodyModel) then
    ix.char.RegisterVar("bodyModel", {
        field = "body_model",
        fieldType = ix.type.string,
        default = "",
        bNoDisplay = true
    })
end

if (!ix.char.vars.headModel) then
    ix.char.RegisterVar("headModel", {
        field = "head_model",
        fieldType = ix.type.string,
        default = "",
        bNoDisplay = true
    })
end

if (ix.char.vars.model) then
    ix.char.vars.model.ShouldDisplay = function()
        return false
    end
end

if (!ix.char.vars.firstName) then
    ix.char.RegisterVar("firstName", {
        default = "",
        bNoDisplay = true,
        OnValidate = function(self, value)
            return string.Trim(tostring(value or ""))
        end
    })
end

if (!ix.char.vars.lastName) then
    ix.char.RegisterVar("lastName", {
        default = "",
        bNoDisplay = true,
        OnValidate = function(self, value)
            return string.Trim(tostring(value or ""))
        end
    })
end


-- Shared schema hooks.

function Schema:CanDrive(client, entity)
	return false
end

do
	local equipmentInventoryTypes = {
		leopardrp_uniform = {4, 4},
		leopardrp_combadge = {1, 1},
	}

	for inventoryType, size in pairs(equipmentInventoryTypes) do
		if (!ix.item.inventoryTypes[inventoryType]) then
			ix.inventory.Register(inventoryType, size[1], size[2])
		end
	end
end

if (SERVER) then
	hook.Add("InitializedConfig", "LeopardRP.OverrideMenuMusic", function()
		local musicPath = "leopardrp/menu/main_menu_theme.ogg"

		if (!file.Exists("sound/" .. musicPath, "GAME")) then
			local fallbackPath = "leopardrp/menu/main_menu_theme.mp3"

			if (file.Exists("sound/" .. fallbackPath, "GAME")) then
				musicPath = fallbackPath
			else
				return
			end
		end

		ix.config.Set("music", musicPath)
	end)
end

function Schema:AdjustCreationPayload(client, payload, newPayload)
	local data = ix.leopardrp and ix.leopardrp.character

	if (!data) then
		return
	end

	local firstName = string.Trim(tostring(payload.firstName or ""))
	local lastName = string.Trim(tostring(payload.lastName or ""))
	local combinedName = string.Trim(string.format("%s %s", firstName, lastName))
	if (combinedName == "") then
		combinedName = string.Trim(tostring(payload.name or ""))
	end

	local species = data.NormalizeSpecies(payload.species)
	local gender = data.NormalizeGender(payload.gender, species)
	local division = data.NormalizeDivision(payload.division)
	local uniformType = data.NormalizeUniformType(payload.uniformType)
	local headModel, sourceIndex = data.GetHeadModel(species, gender, payload.headIndex)
	local bodyModel = data.GetBodyModel(division, gender, uniformType)
	local faction = ix.faction.indices[payload.faction]
	local factionModel

	if (faction and faction.GetModels) then
		local models = faction:GetModels(client)
		local selectedModel = models and models[payload.model]

		if (isstring(selectedModel)) then
			factionModel = selectedModel
		elseif (istable(selectedModel)) then
			factionModel = selectedModel[1]
		end
	end

	newPayload.name = combinedName
	newPayload.firstName = firstName
	newPayload.lastName = lastName
	newPayload.species = species
	newPayload.gender = gender
	newPayload.division = division
	newPayload.uniformType = uniformType
	newPayload.headIndex = sourceIndex
	newPayload.headModel = headModel
	newPayload.bodyModel = bodyModel
	newPayload.authCode = tostring((ix.leopardrp.auth and ix.leopardrp.auth.GeneratePayloadAuthCode and ix.leopardrp.auth.GeneratePayloadAuthCode(newPayload)) or payload.authCode or "")

	if (util.IsValidModel(bodyModel)) then
		newPayload.model = bodyModel
	elseif (util.IsValidModel(factionModel or "")) then
		newPayload.model = factionModel
	end

	if (type(payload.description) == "string") then
		newPayload.description = payload.description
	end
end

function Schema:CanPlayerEarnSalary(client, faction)
	return false
end

function Schema:GetSalaryAmount(client, faction)
	return 0
end

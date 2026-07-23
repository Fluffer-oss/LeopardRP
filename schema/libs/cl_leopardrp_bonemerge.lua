ix.leopardrp = ix.leopardrp or {}
ix.leopardrp.bonemerge = ix.leopardrp.bonemerge or {}

local bonemerge = ix.leopardrp.bonemerge
bonemerge.previewModels = bonemerge.previewModels or {}

local mergeEffects = bit.bor(EF_BONEMERGE, EF_BONEMERGE_FASTCULL, EF_PARENT_ANIMATES)

local function buildBoneNameLookup(entity)
    local lookup = {}

    if (!IsValid(entity) or !entity.GetBoneCount or !entity.GetBoneName) then
        return lookup
    end

    local boneCount = tonumber(entity:GetBoneCount() or 0) or 0

    for index = 0, math.max(0, boneCount - 1) do
        local boneName = string.lower(tostring(entity:GetBoneName(index) or ""))

        if (boneName ~= "") then
            lookup[boneName] = true
        end
    end

    return lookup
end

local function hasSharedBones(parentEnt, headEnt)
    if (!IsValid(parentEnt) or !IsValid(headEnt)) then
        return false
    end

    local parentBones = buildBoneNameLookup(parentEnt)

    if (next(parentBones) == nil) then
        return false
    end

    local headBoneCount = tonumber(headEnt:GetBoneCount() or 0) or 0

    for index = 0, math.max(0, headBoneCount - 1) do
        local boneName = string.lower(tostring(headEnt:GetBoneName(index) or ""))

        if (boneName ~= "" and parentBones[boneName]) then
            return true
        end
    end

    return false
end

local function applyHeadBoneFallback(parentEnt, headEnt)
    if (!IsValid(parentEnt) or !IsValid(headEnt) or !headEnt.FollowBone) then
        return
    end

    local headBone = parentEnt:LookupBone("ValveBiped.Bip01_Head1")

    if (!headBone or headBone < 0) then
        return
    end

    headEnt:FollowBone(parentEnt, headBone)
    headEnt:SetLocalPos(vector_origin)
    headEnt:SetLocalAngles(angle_zero)
end

local function removeModel(store, key)
    local model = store[key]

    if (IsValid(model)) then
        model:Remove()
    end

    store[key] = nil
end

local function ensureModel(store, key, parentEnt, modelPath)
    if (!IsValid(parentEnt) or !isstring(modelPath) or modelPath == "") then
        removeModel(store, key)
        return nil
    end

    local current = store[key]

    if (!IsValid(current) or string.lower(current:GetModel() or "") ~= string.lower(modelPath)) then
        removeModel(store, key)

        current = ClientsideModel(modelPath, RENDERGROUP_BOTH)

        if (!IsValid(current)) then
            return nil
        end

        current:SetNoDraw(false)
        store[key] = current
    end

    if (current:GetParent() ~= parentEnt) then
        current:SetParent(parentEnt, 0)
    end

    current:SetMoveType(MOVETYPE_NONE)
    current:SetSolid(SOLID_NONE)
    current:AddEffects(mergeEffects)
    current:SetLocalPos(vector_origin)
    current:SetLocalAngles(angle_zero)

    if (!hasSharedBones(parentEnt, current)) then
        applyHeadBoneFallback(parentEnt, current)
    end

    return current
end

local function getHeadModelFromPayload(payload)
    local data = ix.leopardrp and ix.leopardrp.character

    if (!data) then
        return ""
    end

    local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
    local gender = data.NormalizeGender(payload.gender or data.defaultGender, species)
    local headModel = data.GetHeadModel(species, gender, payload.headIndex)

    return tostring(headModel or "")
end

local function getBodyModelFromPayload(payload)
    local data = ix.leopardrp and ix.leopardrp.character

    if (!data) then
        return ""
    end

    local species = data.NormalizeSpecies(payload.species or data.defaultSpecies)
    local gender = data.NormalizeGender(payload.gender or data.defaultGender, species)
    local division = data.NormalizeDivision(payload.division or data.defaultDivision)
    local uniformType = data.NormalizeUniformType(payload.uniformType or data.defaultUniformType)

    return tostring(data.GetBodyModel(division, gender, uniformType) or "")
end

local function getRankIDFromPayload(payload)
    local division = tostring(payload.division or "")
    local rankID = tostring(payload.rankID or payload.rankId or payload.rank or "")

    if (rankID == "") then
        rankID = division == "Starfleet Academy" and "cadet" or "ensign"
    end

    if (LeopardRP.NormalizeRankID) then
        rankID = tostring(LeopardRP.NormalizeRankID(rankID) or rankID)
    end

    return rankID
end

local function getFactionModelIndexForBody(payload, bodyModel)
    local faction = ix.faction.indices[payload.faction or 0]

    if (!faction or !isfunction(faction.GetModels)) then
        return nil
    end

    local models = faction:GetModels(LocalPlayer()) or {}
    local wanted = string.lower(tostring(bodyModel or ""))

    for index, modelData in ipairs(models) do
        local candidate = isstring(modelData) and modelData or (istable(modelData) and modelData[1] or "")

        if (string.lower(tostring(candidate or "")) == wanted) then
            return index
        end
    end

    if (#models > 0) then
        return 1
    end

    return nil
end

local function updatePreviewBonemerge(panel)
    if (!IsValid(panel) or !panel.payload) then
        return
    end

    local bodyModel = getBodyModelFromPayload(panel.payload)
    local modelIndex = getFactionModelIndexForBody(panel.payload, bodyModel)

    if (modelIndex and tonumber(panel.payload.model) ~= tonumber(modelIndex)) then
        panel.payload:Set("model", modelIndex)
    end

    local headModel = getHeadModelFromPayload(panel.payload)
    local rankID = getRankIDFromPayload(panel.payload)
    local division = tostring(panel.payload.division or (ix.leopardrp and ix.leopardrp.character and ix.leopardrp.character.defaultDivision) or "Starfleet Academy")

    local modelPanels = {
        faction = panel.factionModel,
        description = panel.descriptionModel,
        overview = panel.overviewModel,
        attributes = panel.attributesModel,
    }

    for key, modelPanel in pairs(modelPanels) do
        local owner = IsValid(modelPanel) and (modelPanel.Entity or (modelPanel.GetEntity and modelPanel:GetEntity())) or nil
        ensureModel(bonemerge.previewModels, key, owner, headModel)

        if (IsValid(owner) and LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.ApplyRankBodygroup) then
            LeopardRP.CharacterCreation.ApplyRankBodygroup(owner, rankID, division, bodyModel)
        end
    end
end

local function drawAttachedPreviewModel(store, key)
    local model = store[key]

    if (!IsValid(model)) then
        return
    end

    model:SetNoDraw(false)
    model:SetupBones()
    model:DrawModel()
end

hook.Add("OnCharacterMenuCreated", "LeopardRP.BonemergePreview", function(menu)
    timer.Simple(0, function()
        if (!IsValid(menu) or !IsValid(menu.newCharacterPanel)) then
            return
        end

        local panel = menu.newCharacterPanel

        if (!isfunction(panel.AddPayloadHook)) then
            return
        end

        local function refresh()
            updatePreviewBonemerge(panel)
        end

        panel:AddPayloadHook("species", refresh)
        panel:AddPayloadHook("gender", refresh)
        panel:AddPayloadHook("headIndex", refresh)
        panel:AddPayloadHook("faction", refresh)
        panel:AddPayloadHook("model", refresh)
        panel:AddPayloadHook("division", refresh)
        panel:AddPayloadHook("uniformType", refresh)

        refresh()
        timer.Simple(0, refresh)
        timer.Simple(0.1, refresh)

        local previewPanels = {
            faction = panel.factionModel,
            description = panel.descriptionModel,
            overview = panel.overviewModel,
            attributes = panel.attributesModel,
        }

        for key, modelPanel in pairs(previewPanels) do
            if (IsValid(modelPanel) and !modelPanel.LeopardRPBonemergeWrapped) then
                local oldDrawModel = modelPanel.DrawModel

                modelPanel.DrawModel = function(this, ...)
                    if (oldDrawModel) then
                        oldDrawModel(this, ...)
                    end

                    drawAttachedPreviewModel(bonemerge.previewModels, key)
                end

                modelPanel.LeopardRPBonemergeWrapped = true
            end
        end

        local oldOnRemove = panel.OnRemove
        panel.OnRemove = function(this)
            removeModel(bonemerge.previewModels, "faction")
            removeModel(bonemerge.previewModels, "description")
            removeModel(bonemerge.previewModels, "overview")
            removeModel(bonemerge.previewModels, "attributes")

            if (oldOnRemove) then
                oldOnRemove(this)
            end
        end
    end)
end)

hook.Add("ShutDown", "LeopardRP.BonemergeShutdown", function()
    for key in pairs(bonemerge.previewModels) do
        removeModel(bonemerge.previewModels, key)
    end
end)

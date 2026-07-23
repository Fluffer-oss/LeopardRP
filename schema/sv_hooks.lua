
-- Here is where all of your serverside hooks should go.

local function applyBonemerge(parentEntity, headEntity)
	if (!IsValid(parentEntity) or !IsValid(headEntity)) then
		return
	end

	headEntity:SetParent(parentEntity, 0)
	headEntity:SetMoveType(MOVETYPE_NONE)
	headEntity:SetSolid(SOLID_NONE)
	headEntity:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	headEntity:SetLocalPos(vector_origin)
	headEntity:SetLocalAngles(angle_zero)
	headEntity:AddEffects(EF_BONEMERGE)
	headEntity:AddEffects(EF_BONEMERGE_FASTCULL)
	headEntity:AddEffects(EF_PARENT_ANIMATES)

	local headBone = parentEntity.LookupBone and parentEntity:LookupBone("ValveBiped.Bip01_Head1") or nil
	if (isnumber(headBone) and headBone >= 0 and headEntity.FollowBone) then
		headEntity:FollowBone(parentEntity, headBone)
	end
end

local function cleanString(value)
	local text = tostring(value or "")

	if (string.Trim) then
		return string.Trim(text)
	end

	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")

	return text
end

local function getEquipmentSlotType(inventory)
	if (!istable(inventory) or !istable(inventory.vars)) then
		return nil
	end

	if (isstring(inventory.vars.leopardSlotType) and inventory.vars.leopardSlotType ~= "") then
		return inventory.vars.leopardSlotType
	end

	if (inventory.vars.isBag == "leopardrp_uniform") then
		return "uniform"
	end

	if (inventory.vars.isBag == "leopardrp_combadge") then
		return "combadge"
	end

	return nil
end

local function getItemSlotType(item)
	if (!item) then
		return nil
	end

	local slotType = tostring(item.slotType or item.equipSlot or item.data and item.data.slotType or item.data and item.data.equipSlot or "")
	if (slotType ~= "") then
		return string.lower(slotType)
	end

	if (item.weaponCategory and string.lower(tostring(item.weaponCategory)) == "combadge") then
		return "combadge"
	end

	if (item.class and string.lower(tostring(item.class)) == "weapon_leopardrp_combadge") then
		return "combadge"
	end

	if (item.category and string.lower(tostring(item.category)) == "uniform") then
		return "uniform"
	end

	return nil
end

local function ensureEquipmentInventory(character, client, slotType)
	if (!character) then
		return
	end

	local inventoryType = slotType == "uniform" and "leopardrp_uniform" or slotType == "combadge" and "leopardrp_combadge" or nil
	if (!inventoryType) then
		return
	end

	character.vars.inv = character.vars.inv or {}

	local function attachInventory(inventory)
		if (!istable(inventory)) then
			return
		end

		inventory.vars = inventory.vars or {}
		inventory.vars.leopardSlotType = slotType
		inventory.vars.isBag = inventoryType

		for _, existing in ipairs(character.vars.inv) do
			if (istable(existing) and existing.GetID and existing:GetID() == inventory:GetID()) then
				return
			end
		end

		table.insert(character.vars.inv, inventory)

		if (IsValid(client)) then
			inventory:AddReceiver(client)
			inventory:Sync(client)
		end
	end

	for _, inventory in ipairs(character:GetInventory(true) or {}) do
		if (getEquipmentSlotType(inventory) == slotType) then
			attachInventory(inventory)
			return
		end
	end

	ix.inventory.New(character:GetID(), inventoryType, function(inventory)
		attachInventory(inventory)
	end)
end

hook.Add("CharacterLoaded", "LeopardRP.EnsureEquipmentInventories", function(character)
	if (!character) then
		return
	end

	local client = character.GetPlayer and character:GetPlayer() or nil
	ensureEquipmentInventory(character, client, "uniform")
	ensureEquipmentInventory(character, client, "combadge")
end)

function Schema:CanTransferItem(itemObject, curInv, inventory)
	local slotType = getEquipmentSlotType(inventory)
	if (!slotType) then
		return
	end

	return getItemSlotType(itemObject) == slotType
end

local function removeAttachedHead(client)
	if (!IsValid(client)) then
		return
	end

	local headEntity = client.LeopardRPHeadEntity

	if (IsValid(headEntity)) then
		headEntity:Remove()
	end

	client.LeopardRPHeadEntity = nil
end

local function isPlayerInVRSession(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	if (vrmod and isfunction(vrmod.IsPlayerInVR)) then
		return vrmod.IsPlayerInVR(client) == true
	end

	return false
end

local function updateHeadTransmitForOwner(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local headEntity = client.LeopardRPHeadEntity
	if (!IsValid(headEntity) or !headEntity.SetPreventTransmit) then
		return
	end

	-- Hide the local bonemerged head only while in VR to prevent HMD obstruction.
	headEntity:SetPreventTransmit(client, isPlayerInVRSession(client))
end

local function stabilizeAttachedHead(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local headEntity = client.LeopardRPHeadEntity
	if (!IsValid(headEntity)) then
		return
	end

	if (headEntity:GetParent() ~= client) then
		applyBonemerge(client, headEntity)
	end

	local headDistanceSqr = headEntity:GetPos():DistToSqr(client:EyePos())
	if (headDistanceSqr > (200 * 200)) then
		applyBonemerge(client, headEntity)
	end
end

local function attachHeadToPlayer(client, headModel)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	headModel = cleanString(headModel)

	if (headModel == "" or !util.IsValidModel(headModel)) then
		removeAttachedHead(client)
		return false
	end

	removeAttachedHead(client)

	local headEntity = ents.Create("prop_dynamic")

	if (!IsValid(headEntity)) then
		return false
	end

	headEntity:SetModel(headModel)
	headEntity:SetPos(client:GetPos())
	headEntity:SetAngles(client:GetAngles())
	headEntity:Spawn()
	headEntity:Activate()

	applyBonemerge(client, headEntity)

	client.LeopardRPHeadEntity = headEntity
	updateHeadTransmitForOwner(client)

	return true
end

hook.Add("VRMod_Start", "LeopardRP.HeadTransmitVRStart", function(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	updateHeadTransmitForOwner(client)
end)

hook.Add("VRMod_Exit", "LeopardRP.HeadTransmitVRExit", function(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	updateHeadTransmitForOwner(client)
end)

local function copyBodygroups(sourceEntity, targetEntity)
	if (!IsValid(sourceEntity) or !IsValid(targetEntity)) then
		return
	end

	for _, bodygroupData in ipairs(sourceEntity:GetBodyGroups() or {}) do
		local bodygroupID = tonumber(bodygroupData.id) or 0
		targetEntity:SetBodygroup(bodygroupID, sourceEntity:GetBodygroup(bodygroupID))
	end
end

local function copyRagdollPhysics(sourceRagdoll, targetRagdoll)
	if (!IsValid(sourceRagdoll) or !IsValid(targetRagdoll)) then
		return
	end

	local count = tonumber(sourceRagdoll:GetPhysicsObjectCount() or 0) or 0

	for i = 0, count - 1 do
		local sourcePhys = sourceRagdoll:GetPhysicsObjectNum(i)
		local targetPhys = targetRagdoll:GetPhysicsObjectNum(i)

		if (IsValid(sourcePhys) and IsValid(targetPhys)) then
			targetPhys:SetPos(sourcePhys:GetPos())
			targetPhys:SetAngles(sourcePhys:GetAngles())
			targetPhys:SetVelocity(sourcePhys:GetVelocity())
			targetPhys:AddAngleVelocity(sourcePhys:GetAngleVelocity())
		end
	end
end

local function ensureCharacterItem(client, uniqueID)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local character = client:GetCharacter()
	if (!character) then
		return
	end

	local inventory = character:GetInventory()
	if (!inventory) then
		return
	end

	if (inventory:HasItem(uniqueID)) then
		return
	end

	inventory:Add(uniqueID)
end

local function isStarfleetCharacter(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	local character = client:GetCharacter()
	if (!character) then
		return false
	end

	local factionIndex = character:GetFaction()

	if (FACTION_STARFLEET and factionIndex == FACTION_STARFLEET) then
		return true
	end

	local faction = ix.faction.indices[factionIndex]
	local factionName = string.lower(tostring(faction and faction.name or ""))

	return string.find(factionName, "starfleet", 1, true) ~= nil
end

local function getCombadgeBodygroupIndex(entity)
	if (!IsValid(entity) or !entity.GetBodyGroups) then
		return nil
	end

	if (entity.FindBodygroupByName) then
		local index = entity:FindBodygroupByName("combadge")
		if (isnumber(index) and index >= 0) then
			return index
		end

		index = entity:FindBodygroupByName("badge")
		if (isnumber(index) and index >= 0) then
			return index
		end
	end

	for _, data in ipairs(entity:GetBodyGroups() or {}) do
		local name = string.lower(tostring(data.name or ""))
		if (name == "combadge" or name == "badge") then
			return tonumber(data.id) or nil
		end
	end

	return nil
end

local function syncCombadgeBodygroup(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local bodygroupIndex = getCombadgeBodygroupIndex(client)
	if (!isnumber(bodygroupIndex)) then
		return
	end

	local hasCombadge = client:HasWeapon("weapon_leopardrp_combadge")
	client:SetBodygroup(bodygroupIndex, hasCombadge and 1 or 0)
	client:SetNWBool("LeopardRP.CombadgeEquipped", hasCombadge)
	client:SetNWString("LeopardRP.CombadgeWeaponClass", hasCombadge and "weapon_leopardrp_combadge" or "")
end

local function ensureStarfleetCombadge(client)
	if (!isStarfleetCharacter(client)) then
		return
	end

	ensureCharacterItem(client, "combadge")

	if (!client:HasWeapon("weapon_leopardrp_combadge")) then
		client:Give("weapon_leopardrp_combadge")
	end

	syncCombadgeBodygroup(client)
end

local function ensureDefaultCharacterTools(client)
	local function resolveItemWeaponClass(itemUniqueID, fallbackClass)
		local itemDef = ix.item.list and ix.item.list[itemUniqueID]
		local className = tostring(itemDef and itemDef.class or fallbackClass or "")

		if (className == "") then
			return ""
		end

		if (weapons.GetStored and weapons.GetStored(className)) then
			return className
		end

		return ""
	end

	ensureStarfleetCombadge(client)
	ensureCharacterItem(client, "lcars_padd_swep")
	ensureCharacterItem(client, "lcars_tricorder_swep")

	local paddClass = resolveItemWeaponClass("lcars_padd_swep", "weapon_grn_medic_datapad")
	local tricorderClass = resolveItemWeaponClass("lcars_tricorder_swep", "weapon_grn_medscanner")

	if (paddClass ~= "" and !client:HasWeapon(paddClass)) then
		client:Give(paddClass)
	end

	if (tricorderClass ~= "" and !client:HasWeapon(tricorderClass)) then
		client:Give(tricorderClass)
	end
end

local noClipCorrectTimers = {}

local function canUseStrictNoClip(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	if (LeopardRP.Personnel and LeopardRP.Personnel.IsForcedOwner and LeopardRP.Personnel.IsForcedOwner(client)) then
		return true
	end

	if (LeopardRP.GameMaster and LeopardRP.GameMaster.GetPermissionRank and LeopardRP.GameMaster.IsClockedIn and LeopardRP.GameMaster.HasRankAtLeast) then
		local gmRank = tostring(LeopardRP.GameMaster.GetPermissionRank(client:SteamID64()) or "none")
		if (LeopardRP.GameMaster.IsClockedIn(client) and LeopardRP.GameMaster.HasRankAtLeast(gmRank, "game_master")) then
			return true
		end
	end

	if (LeopardRP.Personnel and LeopardRP.Personnel.CanAccessAdminPanel and LeopardRP.Personnel.CanAccessAdminPanel(client)) then
		return true
	end

	return false
end

local function applyRankBodygroupToPlayer(client, character, bodyModel, division)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	if (!character) then
		character = client:GetCharacter()
	end

	if (!character) then
		return
	end

	if (!LeopardRP.CharacterCreation or !LeopardRP.CharacterCreation.ApplyRankBodygroup) then
		return
	end

	local rankID = tostring(character:GetData("leopardrpRankID", "cadet") or "cadet")
	local divisionName = tostring(division or character:GetDivision("Starfleet Academy") or "Starfleet Academy")
	local modelPath = tostring(bodyModel or client:GetModel() or "")

	LeopardRP.CharacterCreation.ApplyRankBodygroup(client, rankID, divisionName, modelPath)
	if (IsValid(client.LeopardRPHeadEntity)) then
		LeopardRP.CharacterCreation.ApplyRankBodygroup(client.LeopardRPHeadEntity, rankID, divisionName, modelPath)
	end
end

local function getRankBodygroupIndex(entity)
	if (!IsValid(entity) or !entity.GetBodyGroups) then
		return nil
	end

	if (entity.FindBodygroupByName) then
		local index = entity:FindBodygroupByName("rank")
		if (isnumber(index) and index >= 0) then
			return index
		end
	end

	for _, bodygroupData in ipairs(entity:GetBodyGroups() or {}) do
		if (string.lower(tostring(bodygroupData.name or "")) == "rank") then
			return tonumber(bodygroupData.id) or nil
		end
	end

	return nil
end

local function getExpectedRankBodygroupValue(rankID, divisionName, bodyModel)
	local modelPath = string.lower(tostring(bodyModel or ""))
	local normalizedDivision = tostring(divisionName or "")
	local isAdmiralModel = normalizedDivision == "Admiral" or string.find(modelPath, "admiral", 1, true) ~= nil
	local isCadetModel = normalizedDivision == "Cadet" or normalizedDivision == "Starfleet Academy" or string.find(modelPath, "cadet", 1, true) ~= nil

	if (isCadetModel) then
		return 1
	end

	if (isAdmiralModel and LeopardRP.GetAdmiralRankBodygroup) then
		return math.max(0, tonumber(LeopardRP.GetAdmiralRankBodygroup(rankID)) or 0)
	end

	if (LeopardRP.GetRankPipBodygroup) then
		return math.max(0, tonumber(LeopardRP.GetRankPipBodygroup(rankID)) or 0)
	end

	return 0
end

local function getExpectedCharacterAppearance(client, character)
	if (!character) then
		return nil
	end

	local data = ix.leopardrp and ix.leopardrp.character
	local species = tostring(character:GetSpecies("Human") or "Human")
	local gender = tostring(character:GetGender("Male") or "Male")
	local division = tostring(character:GetDivision("Starfleet Academy") or "Starfleet Academy")
	local uniformType = tostring(character:GetUniformType("Standard") or "Standard")
	local headIndex = tonumber(character:GetHeadIndex(1) or 1) or 1
	local headModel = tostring(character:GetHeadModel("") or "")
	local authCode = tostring(character.GetAuthCode and character:GetAuthCode("") or "")
	local rankID = tostring(character:GetData("leopardrpRankID", "cadet") or "cadet")

	if (LeopardRP.NormalizeRankID) then
		rankID = tostring(LeopardRP.NormalizeRankID(rankID) or rankID)
	end

	if (data) then
		species = data.NormalizeSpecies(species)
		gender = data.NormalizeGender(gender, species)
		division = data.NormalizeDivision(division)
		uniformType = data.NormalizeUniformType(uniformType)
	end

	local fleetCaptainOrder = LeopardRP.GetRankOrder and tonumber(LeopardRP.GetRankOrder("fleet_captain") or 14) or 14
	local currentRankOrder = LeopardRP.GetRankOrder and tonumber(LeopardRP.GetRankOrder(rankID) or 0) or 0
	if (currentRankOrder > fleetCaptainOrder) then
		division = "Admiral"
	end

	local bodyModel = ""
	if (data and data.GetBodyModel) then
		bodyModel = tostring(data.GetBodyModel(division, gender, uniformType) or "")
	end

	if ((headModel == "" or !util.IsValidModel(headModel)) and data and data.GetHeadModel) then
		headModel = tostring(data.GetHeadModel(species, gender, headIndex) or "")
	end

	local faction = ix.faction.indices[character:GetFaction()]
	if ((bodyModel == "" or !util.IsValidModel(bodyModel)) and faction and faction.GetModels) then
		local models = faction:GetModels(client)
		local firstModel = models and models[1]
		if (isstring(firstModel)) then
			bodyModel = firstModel
		elseif (istable(firstModel)) then
			bodyModel = tostring(firstModel[1] or "")
		end
	end

	return {
		species = species,
		gender = gender,
		division = division,
		uniformType = uniformType,
		headIndex = headIndex,
		headModel = headModel,
		bodyModel = bodyModel,
		authCode = authCode,
		rankID = rankID,
		expectedRankBodygroup = getExpectedRankBodygroupValue(rankID, division, bodyModel)
	}
end

local function refreshLiveCharacterAppearance(client, character)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	character = character or client:GetCharacter()
	if (!character) then
		return false
	end

	local expected = getExpectedCharacterAppearance(client, character)
	if (!expected) then
		return false
	end

	local bodyModel = tostring(expected.bodyModel or "")
	local headModel = tostring(expected.headModel or "")
	local species = tostring(expected.species or "Human")
	local gender = tostring(expected.gender or "Male")
	local division = tostring(expected.division or "Starfleet Academy")
	local uniformType = tostring(expected.uniformType or "Standard")
	local authCode = tostring(expected.authCode or "")
	local resolvedModel = bodyModel

	if (util.IsValidModel(resolvedModel)) then
		if (character.SetBodyModel) then
			character:SetBodyModel(resolvedModel)
		end
		if (character.SetDivision) then
			character:SetDivision(division)
		end
		if (character.SetUniformType) then
			character:SetUniformType(uniformType)
		end
		character:SetModel(resolvedModel)
		bodyModel = resolvedModel
		client:SetModel(resolvedModel)
		hook.Run("PlayerModelChanged", client, resolvedModel)
	end

	client:SetNWString("LeopardRP.CharacterSpecies", species)
	client:SetNWString("LeopardRP.CharacterGender", gender)
	client:SetNWString("LeopardRP.CharacterDivision", division)
	client:SetNWString("LeopardRP.CharacterUniformType", uniformType)
	client:SetNWString("LeopardRP.CharacterAuthCode", authCode)
	client:SetNWString("LeopardRP.CharacterHeadModel", headModel)
	client:SetNWString("LeopardRP.CharacterBodyModel", bodyModel)

	applyRankBodygroupToPlayer(client, character, bodyModel, division)

	if (client.SetupHands) then
		client:SetupHands()
	end

	timer.Simple(0, function()
		if (!IsValid(client) or client:GetCharacter() ~= character) then
			return
		end

		attachHeadToPlayer(client, headModel)
		applyRankBodygroupToPlayer(client, character, bodyModel, division)
		ensureDefaultCharacterTools(client)
		syncCombadgeBodygroup(client)
	end)

	timer.Simple(0.25, function()
		if (!IsValid(client) or client:GetCharacter() ~= character) then
			return
		end

		attachHeadToPlayer(client, headModel)
		applyRankBodygroupToPlayer(client, character, bodyModel, division)
		syncCombadgeBodygroup(client)
	end)

	character:Sync(client)
	return true
end

function Schema:RefreshLiveCharacterAppearance(client, character)
	return refreshLiveCharacterAppearance(client, character)
end

hook.Add("PlayerNoClip", "LeopardRP.StrictNoClipCheck", function(client, desiredState)
	if (!IsValid(client) or !client:IsPlayer()) then
		return false
	end

	local allowed = canUseStrictNoClip(client)

	if (!allowed and desiredState) then
		local observerMode = client:GetObserverMode()
		if (observerMode == OBS_MODE_ROAMING or observerMode == OBS_MODE_CHASE or observerMode == OBS_MODE_IN_EYE or observerMode == OBS_MODE_POINT) then
			client:UnSpectate()
		end

		if (client:GetMoveType() == MOVETYPE_NOCLIP) then
			client:SetMoveType(MOVETYPE_WALK)
		end

		local steamID = client:SteamID64()
		if (!noClipCorrectTimers[steamID]) then
			noClipCorrectTimers[steamID] = true
			timer.Simple(0, function()
				if (IsValid(client) and client:GetMoveType() == MOVETYPE_NOCLIP) then
					client:SetMoveType(MOVETYPE_WALK)
				end
				noClipCorrectTimers[steamID] = nil
			end)
		end
	end

	return allowed
end, 1)

local function hasValidMainInventory(character)
	if (!character or !character.GetInventory) then
		return false
	end

	local inventory = character:GetInventory()

	return istable(inventory) and inventory.GetID and isnumber(inventory:GetID()) and inventory:GetID() > 0
end

local function ensureCharacterMainInventory(client, character)
	if (!character or !character.GetID) then
		return
	end

	local function bindInventory(inventory)
		if (!istable(inventory) or !inventory.GetID) then
			return
		end

		character.vars.inv = character.vars.inv or {}
		character.vars.inv[1] = inventory
		inventory:SetOwner(character:GetID())

		if (IsValid(client) and client:GetCharacter() == character) then
			inventory:AddReceiver(client)
			inventory:Sync(client)
		end
	end

	if (hasValidMainInventory(character)) then
		bindInventory(character:GetInventory())
		return
	end

	local retries = 0
	local timerID = "LeopardRP.EnsureMainInventory." .. tostring(character:GetID())

	timer.Create(timerID, 0.2, 15, function()
		if (!character or (IsValid(client) and client:GetCharacter() ~= character)) then
			timer.Remove(timerID)
			return
		end

		if (hasValidMainInventory(character)) then
			bindInventory(character:GetInventory())
			timer.Remove(timerID)
			return
		end

		retries = retries + 1

		if (retries < 15) then
			return
		end

		timer.Remove(timerID)

		local charID = character:GetID()
		local width = math.max(tonumber(ix.config.Get("inventoryWidth", 6)) or 6, 1)
		local height = math.max(tonumber(ix.config.Get("inventoryHeight", 4)) or 4, 1)

		local query = mysql:Insert("ix_inventories")
			query:Insert("character_id", charID)
			query:Callback(function(_, _, inventoryID)
				local numericID = tonumber(inventoryID)

				if (!numericID or numericID <= 0) then
					return
				end

				local inventory = ix.inventory.Create(width, height, numericID)
				bindInventory(inventory)
			end)
		query:Execute()
	end)
end

-- Change death sounds of people in the police faction to the metropolice death sound.
function Schema:GetPlayerDeathSound(client)
	local character = client:GetCharacter()

	if (character and character:IsPolice()) then
		return "NPC_MetroPolice.Die"
	end
end

function Schema:PlayerLoadedCharacter(client, character)

	if (!IsValid(client)) then
		return
	end

	ensureCharacterMainInventory(client, character)

	refreshLiveCharacterAppearance(client, character)

	if (character and character.GetMoney and character.SetMoney and character:GetMoney() ~= 0) then
		character:SetMoney(0)
	end
end

function Schema:PlayerSpawn(client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local headModel = cleanString(client:GetNWString("LeopardRP.CharacterHeadModel", ""))

	timer.Simple(0, function()
		if (IsValid(client)) then
			attachHeadToPlayer(client, headModel)
		end
	end)

	timer.Simple(0.25, function()
		if (IsValid(client)) then
			attachHeadToPlayer(client, headModel)
		end
	end)

	timer.Simple(0, function()
		if (IsValid(client)) then
			ensureDefaultCharacterTools(client)
			syncCombadgeBodygroup(client)
			applyRankBodygroupToPlayer(client)
		end
	end)
end

timer.Create("LeopardRP.AppearanceWatchdog", 1, 0, function()
	for _, client in ipairs(player.GetAll()) do
		if (IsValid(client) and client:IsPlayer()) then
			stabilizeAttachedHead(client)

			local character = client:GetCharacter()
			if (character) then
				local expected = getExpectedCharacterAppearance(client, character)
				if (expected) then
					local expectedModel = tostring(expected.bodyModel or "")
					local currentModel = tostring(client:GetModel() or "")
					local needsRefresh = expectedModel ~= "" and currentModel ~= expectedModel

					local rankBodygroupIndex = getRankBodygroupIndex(client)
					if (!needsRefresh and isnumber(rankBodygroupIndex)) then
						needsRefresh = client:GetBodygroup(rankBodygroupIndex) ~= tonumber(expected.expectedRankBodygroup or 0)
					end

					if (!needsRefresh) then
						local currentDivision = tostring(client:GetNWString("LeopardRP.CharacterDivision", "") or "")
						needsRefresh = currentDivision ~= tostring(expected.division or "")
					end

					if (needsRefresh) then
						refreshLiveCharacterAppearance(client, character)
					end
				end
			end
		end
	end
end)

hook.Add("PlayerSwitchWeapon", "LeopardRP.SyncCombadgeBodygroup", function(client)
	if (!IsValid(client)) then
		return
	end

	timer.Simple(0, function()
		if (IsValid(client)) then
			syncCombadgeBodygroup(client)
		end
	end)
end)

hook.Add("PlayerPickupWeapon", "LeopardRP.SyncCombadgeBodygroupOnPickup", function(client, weapon)
	if (!IsValid(client) or !IsValid(weapon)) then
		return
	end

	local className = string.lower(tostring(weapon:GetClass() or ""))
	if (string.find(className, "combadge", 1, true)) then
		timer.Simple(0, function()
			if (IsValid(client)) then
				syncCombadgeBodygroup(client)
			end
		end)
	end
end)

hook.Add("CreateEntityRagdoll", "LeopardRP.AttachHeadToRagdoll", function(entity, ragdoll)
	if (!IsValid(entity) or !entity:IsPlayer() or !IsValid(ragdoll)) then
		return
	end

	local headModel = cleanString(entity:GetNWString("LeopardRP.CharacterHeadModel", ""))

	if (headModel == "" or !util.IsValidModel(headModel)) then
		return
	end

	local replacement = ents.Create("prop_ragdoll")

	if (IsValid(replacement)) then
		replacement:SetModel(ragdoll:GetModel())
		replacement:SetPos(ragdoll:GetPos())
		replacement:SetAngles(ragdoll:GetAngles())
		replacement:SetSkin(ragdoll:GetSkin())
		replacement:SetColor(ragdoll:GetColor())
		replacement:SetMaterial(ragdoll:GetMaterial())
		replacement:SetCollisionGroup(ragdoll:GetCollisionGroup())
		replacement:Spawn()
		replacement:Activate()

		copyBodygroups(ragdoll, replacement)
		copyRagdollPhysics(ragdoll, replacement)

		ragdoll:Remove()
		ragdoll = replacement
	end

	if (!IsValid(ragdoll)) then
		return
	end

	local headEntity = ents.Create("prop_dynamic")

	if (!IsValid(headEntity)) then
		return
	end

	headEntity:SetModel(headModel)
	headEntity:SetPos(ragdoll:GetPos())
	headEntity:SetAngles(ragdoll:GetAngles())
	headEntity:Spawn()
	headEntity:Activate()

	applyBonemerge(ragdoll, headEntity)
end)

hook.Add("PlayerDisconnected", "LeopardRP.CleanupHeadOnDisconnect", function(client)
	removeAttachedHead(client)
end)

hook.Add("EntityRemoved", "LeopardRP.CleanupHeadReference", function(entity)
	if (!IsValid(entity) or !entity:IsPlayer()) then
		return
	end

	removeAttachedHead(entity)
end)

util.AddNetworkString("LeopardRP.AdminAction")

net.Receive("LeopardRP.AdminAction", function(_, client)
	if (!IsValid(client) or (!client:IsAdmin() and !client:IsSuperAdmin())) then
		return
	end

	local actionID = string.lower(string.Trim(net.ReadString() or ""))
	local target = net.ReadEntity()
	local payload = net.ReadTable() or {}
	local reason = string.sub(string.Trim(tostring(payload.reason or "")), 1, 120)

	if (!IsValid(target) or !target:IsPlayer()) then
		return
	end

	if (actionID == "bring") then
		target:SetPos(client:GetPos() + client:GetForward() * 48)
	elseif (actionID == "goto") then
		client:SetPos(target:GetPos() + target:GetForward() * -48)
	elseif (actionID == "freeze") then
		target:Freeze(true)
	elseif (actionID == "unfreeze") then
		target:Freeze(false)
	elseif (actionID == "slay") then
		if (target:Alive()) then
			target:Kill()
		end
	elseif (actionID == "kick") then
		if (reason == "") then
			reason = "Removed by staff"
		end

		target:Kick(reason)
	end
end)

util.AddNetworkString("LeopardRP.WardrobeApply")

net.Receive("LeopardRP.WardrobeApply", function(_, client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	local character = client:GetCharacter()
	if (!character) then
		return
	end

	local newDivision = tostring(net.ReadString() or "")
	local newUniform = tostring(net.ReadString() or "")

	if (newDivision ~= "") then
		if (character.SetDivision) then
			character:SetDivision(newDivision)
		end
	end

	if (newUniform ~= "") then
		if (character.SetUniformType) then
			character:SetUniformType(newUniform)
		end
	end

	if (character.SetDivision or character.SetUniformType) then
		timer.Simple(0, function()
			if (IsValid(client) and client:GetCharacter() == character) then
				refreshLiveCharacterAppearance(client, character)
			end
		end)
	end
end)

util.AddNetworkString("LeopardRP.GMSpawnItem")

net.Receive("LeopardRP.GMSpawnItem", function(_, client)
	if (!IsValid(client) or !client:IsPlayer()) then
		return
	end

	if (!LeopardRP.Personnel or !LeopardRP.Personnel.CanAccessAdminPanel or !LeopardRP.Personnel.CanAccessAdminPanel(client)) then
		return
	end

	local uniqueID = tostring(net.ReadString() or "")
	local targetPly = net.ReadEntity()

	if (uniqueID == "" or !IsValid(targetPly) or !targetPly:IsPlayer()) then
		return
	end

	local character = targetPly:GetCharacter()
	if (!character or !character.GetInventory) then
		return
	end

	local inventory = character:GetInventory()
	if (!inventory or !inventory.Add) then
		return
	end

	inventory:Add(uniqueID)
end)

-- Auto-refresh menu access when clock in/out events occur
if (SERVER) then
	local function RefreshPlayerMenuAccess(ply)
		if (!IsValid(ply) or !ply:IsPlayer()) then
			return
		end

		timer.Simple(0, function()
			if (!IsValid(ply)) then
				return
			end

			local canGameMaster = false

			if (LeopardRP.GameMaster and LeopardRP.GameMaster.IsClockedIn) then
				canGameMaster = LeopardRP.GameMaster.IsClockedIn(ply)
			end

			local canCrewManager = false

			if (LeopardRP.Personnel and LeopardRP.Personnel.CanAccessCrewManager) then
				canCrewManager = LeopardRP.Personnel.CanAccessCrewManager(ply)
			end

			local networkString = "LeopardRP.Personnel.ReceiveMenuAccess"
			if (LeopardRP.Personnel and LeopardRP.Personnel.NetworkStrings and LeopardRP.Personnel.NetworkStrings.ReceiveMenuAccess) then
				networkString = LeopardRP.Personnel.NetworkStrings.ReceiveMenuAccess
			end

			net.Start(networkString)
				net.WriteString(util.TableToJSON({
					canGameMasterMenu = canGameMaster,
					canAdministrationMenu = false,
					canCrewManager = canCrewManager,
					canAdminPanel = false
				}))
			net.Send(ply)
		end)
	end

	hook.Add("LeopardRP.GMClockIn", "LeopardRP.MenuAccessRefresh", function(ply)
		RefreshPlayerMenuAccess(ply)
	end)

	hook.Add("LeopardRP.GMClockOut", "LeopardRP.MenuAccessRefresh", function(ply)
		RefreshPlayerMenuAccess(ply)
	end)

end

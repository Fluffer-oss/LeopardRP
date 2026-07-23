local PANEL = {}

local PREVIEW_TUNING = {
	zoom = 162,
	minZoom = 112,
	maxZoom = 204,
	zoomStep = 4,
	fov = 30,
	lookHeight = 58,
	idleYawAmplitude = 2.4,
	idleYawSpeed = 0.36,
	idleLookBob = 0.8,
	idleLookBobSpeed = 0.7,
}

local function applyPreviewBodygroups(entity, bodygroups)
	if (!IsValid(entity) or !istable(bodygroups)) then
		return
	end

	for key, value in pairs(bodygroups) do
		local targetIndex = tonumber(key)
		if (!targetIndex and entity.FindBodygroupByName and isstring(key)) then
			targetIndex = entity:FindBodygroupByName(key)
		end

		if (targetIndex and targetIndex >= 0) then
			entity:SetBodygroup(targetIndex, math.max(0, tonumber(value) or 0))
		end
	end
end

local function applyHandsBodygroup(entity, bHideHands)
	if (!IsValid(entity) or !entity.FindBodygroupByName) then
		return
	end

	local handsBodygroup = entity:FindBodygroupByName("hands")
	if (handsBodygroup ~= nil and handsBodygroup >= 0) then
		entity:SetBodygroup(handsBodygroup, bHideHands and 1 or 0)
		return
	end

	handsBodygroup = entity:FindBodygroupByName("gloves")
	if (handsBodygroup ~= nil and handsBodygroup >= 0) then
		entity:SetBodygroup(handsBodygroup, bHideHands and 1 or 0)
	end
end

local function applyBonemerge(parentEntity, headEntity)
	if (!IsValid(parentEntity) or !IsValid(headEntity)) then
		return
	end

	headEntity:SetParent(parentEntity, 0)
	headEntity:SetMoveType(MOVETYPE_NONE)
	headEntity:SetSolid(SOLID_NONE)
	headEntity:SetLocalPos(vector_origin)
	headEntity:SetLocalAngles(angle_zero)
	headEntity:AddEffects(EF_BONEMERGE)
	headEntity:AddEffects(EF_BONEMERGE_FASTCULL)
end

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

local function hasSharedBones(parentEntity, headEntity)
	if (!IsValid(parentEntity) or !IsValid(headEntity)) then
		return false
	end

	local parentBones = buildBoneNameLookup(parentEntity)

	if (next(parentBones) == nil) then
		return false
	end

	local headCount = tonumber(headEntity:GetBoneCount() or 0) or 0

	for index = 0, math.max(0, headCount - 1) do
		local boneName = string.lower(tostring(headEntity:GetBoneName(index) or ""))

		if (boneName ~= "" and parentBones[boneName]) then
			return true
		end
	end

	return false
end

local function applyHeadBoneFallback(parentEntity, headEntity)
	if (!IsValid(parentEntity) or !IsValid(headEntity) or !headEntity.FollowBone) then
		return
	end

	local headBone = parentEntity:LookupBone("ValveBiped.Bip01_Head1")

	if (!headBone or headBone < 0) then
		return
	end

	headEntity:FollowBone(parentEntity, headBone)
	headEntity:SetLocalPos(vector_origin)
	headEntity:SetLocalAngles(angle_zero)
end

local function applyHeadEntity(parentEntity, headModel)
	if (!IsValid(parentEntity) or !isstring(headModel) or headModel == "") then
		return nil
	end

	local headEntity = ClientsideModel(headModel, RENDERGROUP_BOTH)

	if (!IsValid(headEntity)) then
		return nil
	end

	headEntity:SetPos(parentEntity:GetPos())
	headEntity:SetAngles(parentEntity:GetAngles())
	applyBonemerge(parentEntity, headEntity)

	if (!hasSharedBones(parentEntity, headEntity)) then
		applyHeadBoneFallback(parentEntity, headEntity)
	end

	return headEntity
end

function PANEL:Init()
	self.BodyModel = ""
	self.HeadModel = ""
	self.RankID = ""
	self.Division = ""
	self.Bodygroups = {}
	self.HeadEntity = nil
	self.Zoom = PREVIEW_TUNING.zoom
	self.ZoomLerp = self.Zoom
	self.LookHeight = PREVIEW_TUNING.lookHeight
	self.HasModelData = false
	self.HandsHidden = false
	self.SwapAnimStart = 0
	self.SwapAnimEnd = 0
	self.IdleYaw = 0
	self.IdleLookOffset = 0

	self.ModelPanel = vgui.Create("DModelPanel", self)
	self.ModelPanel:Dock(FILL)
	self.ModelPanel:SetFOV(PREVIEW_TUNING.fov)
	self.ModelPanel:SetCamPos(Vector(self.Zoom, 0, self.LookHeight))
	self.ModelPanel:SetLookAt(Vector(0, 0, self.LookHeight))
	self.ModelPanel:SetAmbientLight(Color(28, 36, 50))
	self.ModelPanel:SetDirectionalLight(BOX_RIGHT, Color(46, 110, 170))

	if (self.ModelPanel.SetPaintBackground) then
		self.ModelPanel:SetPaintBackground(false)
	end

	self.ModelPanel.LayoutEntity = function(_, entity)
		if (!IsValid(entity)) then
			return
		end

		entity:SetAngles(Angle(0, self.IdleYaw or 0, 0))
	end

	self.ModelPanel.OnMouseWheeled = function(_, delta)
		self.Zoom = math.Clamp((self.Zoom or PREVIEW_TUNING.zoom) - (delta * PREVIEW_TUNING.zoomStep), PREVIEW_TUNING.minZoom, PREVIEW_TUNING.maxZoom)
		self.ZoomLerp = self.Zoom
		self.ModelPanel:SetCamPos(Vector(self.ZoomLerp, 0, self.LookHeight))
		return true
	end

	self.ModelPanel.PostDrawModel = function(_, entity)
		if (!IsValid(entity) or !IsValid(self.HeadEntity)) then
			return
		end

		self.HeadEntity:SetMaterial(entity:GetMaterial() or "")
		self.HeadEntity:SetSkin(entity:GetSkin() or 0)
		self.HeadEntity:SetColor(entity:GetColor() or color_white)
		self.HeadEntity:SetRenderMode(entity:GetRenderMode() or RENDERMODE_NORMAL)
		self.HeadEntity:SetNoDraw(false)
		self.HeadEntity:SetupBones()
		self.HeadEntity:DrawModel()
	end
end

function PANEL:Think()
	if (!IsValid(self.ModelPanel)) then
		return
	end

	if (!self:IsVisible() or self:GetAlpha() <= 0) then
		if (IsValid(self.HeadEntity)) then
			self.HeadEntity:SetNoDraw(true)
		end
		return
	end

	local parent = self:GetParent()
	if (IsValid(parent) and self:GetAlpha() ~= parent:GetAlpha()) then
		self:SetAlpha(parent:GetAlpha())
		self.ModelPanel:SetAlpha(parent:GetAlpha())
	end

	local zoomTarget = self.Zoom
	local now = CurTime()

	if (self.SwapAnimEnd > CurTime()) then
		local fraction = math.TimeFraction(self.SwapAnimStart, self.SwapAnimEnd, CurTime())
		local eased = 1 - math.ease.OutQuint(math.Clamp(fraction, 0, 1))
		zoomTarget = self.Zoom + (14 * eased)
	end

	self.IdleYaw = math.sin(now * PREVIEW_TUNING.idleYawSpeed) * PREVIEW_TUNING.idleYawAmplitude
	self.IdleLookOffset = math.sin(now * PREVIEW_TUNING.idleLookBobSpeed) * PREVIEW_TUNING.idleLookBob

	self.ZoomLerp = Lerp(FrameTime() * 12, self.ZoomLerp or zoomTarget, zoomTarget)
	self.ModelPanel:SetCamPos(Vector(self.ZoomLerp, 0, self.LookHeight + self.IdleLookOffset))
	self.ModelPanel:SetLookAt(Vector(0, 0, self.LookHeight + self.IdleLookOffset))

	local pulse = 0.55 + (math.sin(now * 0.72) * 0.45)
	local coolFill = 28 + pulse * 28
	local keyFill = 78 + pulse * 42
	self.ModelPanel:SetAmbientLight(Color(coolFill * 0.3, coolFill * 0.44, coolFill * 0.6))
	self.ModelPanel:SetDirectionalLight(BOX_RIGHT, Color(keyFill * 0.12, keyFill * 0.54, keyFill * 0.92))
	self.ModelPanel:SetDirectionalLight(BOX_FRONT, Color(keyFill * 0.08, keyFill * 0.3, keyFill * 0.48))
end

function PANEL:ApplyModelState()
	if (!IsValid(self.ModelPanel)) then
		return
	end

	local bodyModel = self.BodyModel or ""
	self.ModelPanel:SetModel(bodyModel == "" and "models/error.mdl" or bodyModel)
	self.HasModelData = bodyModel ~= "" or (self.HeadModel or "") ~= ""

	local entity = self.ModelPanel.Entity

	if (!IsValid(entity)) then
		return
	end

	local mins, maxs = entity:GetRenderBounds()
	local modelHeight = math.max(42, (maxs.z or 72) - (mins.z or 0))
	self.LookHeight = math.Clamp((mins.z or 0) + modelHeight * 0.56, 44, 78)
	self.Zoom = math.Clamp(modelHeight * 1.15, PREVIEW_TUNING.minZoom, PREVIEW_TUNING.maxZoom)
	self.ZoomLerp = self.Zoom

	entity:SetPos(Vector(0, 0, 0))
	entity:SetAngles(Angle(0, 0, 0))

	if (LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.ApplyRankBodygroup) then
		LeopardRP.CharacterCreation.ApplyRankBodygroup(entity, self.RankID or "", self.Division or "", bodyModel)
	end

	applyPreviewBodygroups(entity, self.Bodygroups)
	applyHandsBodygroup(entity, self.HandsHidden)

	if (IsValid(self.HeadEntity)) then
		self.HeadEntity:Remove()
		self.HeadEntity = nil
	end

	if (self.HeadModel and self.HeadModel ~= "") then
		self.HeadEntity = applyHeadEntity(entity, self.HeadModel)

		if (IsValid(self.HeadEntity)) then
			self.HeadEntity:SetNoDraw(false)
		end
	end

	self.ModelPanel:SetFOV(PREVIEW_TUNING.fov)
	self.ModelPanel:SetCamPos(Vector(self.ZoomLerp or self.Zoom, 0, self.LookHeight))
	self.ModelPanel:SetLookAt(Vector(0, 0, self.LookHeight))
end

function PANEL:SetCharacterData(characterData)
	characterData = characterData or {}

	self.BodyModel = characterData.bodyModel or ""
	self.HeadModel = characterData.headModel or ""
	self.RankID = characterData.rankID or ""
	self.Division = characterData.division or ""
	self.Bodygroups = istable(characterData.bodygroups) and table.Copy(characterData.bodygroups) or {}
	self.HandsHidden = tobool(characterData.handsHidden or characterData.hideHands or self.HandsHidden)
	self.SwapAnimStart = CurTime()
	self.SwapAnimEnd = CurTime() + 0.22
	self:ApplyModelState()
end

function PANEL:SetHandsHidden(bHidden)
	self.HandsHidden = tobool(bHidden)
	self:ApplyModelState()
end

function PANEL:SetBodyModel(bodyModel)
	self.BodyModel = bodyModel or ""
	self:ApplyModelState()
end

function PANEL:SetHeadModel(headModel)
	self.HeadModel = headModel or ""
	self:ApplyModelState()
end

function PANEL:OnRemove()
	if (IsValid(self.HeadEntity)) then
		self.HeadEntity:Remove()
		self.HeadEntity = nil
	end
end

vgui.Register("LeopardRPCharacterPreview", PANEL, "DPanel")

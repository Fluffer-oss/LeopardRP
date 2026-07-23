LeopardRP = LeopardRP or {}
LeopardRP.VR = LeopardRP.VR or {}

local VR = LeopardRP.VR

function VR:IsAvailable()
	return vrmod ~= nil and isfunction(vrmod.IsPlayerInVR)
end

function VR:IsPlayerInVR(ply)
	if not self:IsAvailable() then
		return false
	end

	if CLIENT and not IsValid(ply) then
		ply = LocalPlayer()
	end

	if not IsValid(ply) then
		return false
	end

	return vrmod.IsPlayerInVR(ply) == true
end

function VR:GetHMDPose(ply)
	if not self:IsPlayerInVR(ply) then
		return nil, nil
	end

	if isfunction(vrmod.GetHMDPose) then
		local pos, ang = vrmod.GetHMDPose(ply)
		if isvector(pos) and isangle(ang) then
			return pos, ang
		end
	end

	if isfunction(vrmod.GetHMDPos) and isfunction(vrmod.GetHMDAng) then
		local pos = vrmod.GetHMDPos(ply)
		local ang = vrmod.GetHMDAng(ply)
		if isvector(pos) and isangle(ang) then
			return pos, ang
		end
	end

	return nil, nil
end

function VR:GetHandPose(ply, hand)
	if not self:IsPlayerInVR(ply) then
		return nil, nil
	end

	hand = tostring(hand or "right")

	if hand == "left" then
		if isfunction(vrmod.GetLeftHandPose) then
			local pos, ang = vrmod.GetLeftHandPose(ply)
			if isvector(pos) and isangle(ang) then
				return pos, ang
			end
		end

		if isfunction(vrmod.GetLeftHandPos) and isfunction(vrmod.GetLeftHandAng) then
			local pos = vrmod.GetLeftHandPos(ply)
			local ang = vrmod.GetLeftHandAng(ply)
			if isvector(pos) and isangle(ang) then
				return pos, ang
			end
		end
	else
		if isfunction(vrmod.GetRightHandPose) then
			local pos, ang = vrmod.GetRightHandPose(ply)
			if isvector(pos) and isangle(ang) then
				return pos, ang
			end
		end

		if isfunction(vrmod.GetRightHandPos) and isfunction(vrmod.GetRightHandAng) then
			local pos = vrmod.GetRightHandPos(ply)
			local ang = vrmod.GetRightHandAng(ply)
			if isvector(pos) and isangle(ang) then
				return pos, ang
			end
		end
	end

	return self:GetHMDPose(ply)
end

function VR:GetInteractionPose(ply)
	if not self:IsPlayerInVR(ply) then
		return nil, nil
	end

	if CLIENT and isfunction(vrmod.GetInput) then
		if vrmod.GetInput("boolean_right_pickup") then
			return self:GetHandPose(ply, "right")
		end

		if vrmod.GetInput("boolean_left_pickup") then
			return self:GetHandPose(ply, "left")
		end
	end

	local rightPos, rightAng = self:GetHandPose(ply, "right")
	if isvector(rightPos) and isangle(rightAng) then
		return rightPos, rightAng
	end

	return self:GetHMDPose(ply)
end

if CLIENT then
	local function hasOpenMenuPanels()
		if IsValid(ix and ix.gui and ix.gui.menu) then
			return true
		end

		if IsValid(ix and ix.gui and ix.gui.characterMenu) then
			return true
		end

		if IsValid(LeopardRP and LeopardRP.CharacterCreation and LeopardRP.CharacterCreation.ActiveMenuFrame) then
			return true
		end

		if IsValid(LeopardRP and LeopardRP.Personnel and LeopardRP.Personnel.ActivePanel) then
			return true
		end

		if IsValid(LeopardRP and LeopardRP.GameMaster and LeopardRP.GameMaster.ActivePanel) then
			return true
		end

		if IsValid(LeopardRP and LeopardRP.Administration and LeopardRP.Administration.ActivePanel) then
			return true
		end

		return false
	end

	function VR:SetMenuInteractionEnabled(enabled)
		enabled = enabled == true

		if enabled then
			gui.EnableScreenClicker(true)
			return
		end

		if hasOpenMenuPanels() then
			return
		end

		gui.EnableScreenClicker(false)
	end

	function VR:OpenMainMenu()
		if LeopardRP and LeopardRP.CharacterCreation and isfunction(LeopardRP.CharacterCreation.RequestMainMenu) then
			LeopardRP.CharacterCreation.RequestMainMenu()
			return
		end

		if IsValid(ix and ix.gui and ix.gui.menu) then
			ix.gui.menu:Remove()
		end

		vgui.Create("ixMenu")
	end

	function VR:OpenCharacterSelection()
		if LeopardRP and LeopardRP.CharacterCreation and isfunction(LeopardRP.CharacterCreation.RequestCharacterSelection) then
			LeopardRP.CharacterCreation.RequestCharacterSelection()
			return
		end

		if IsValid(ix and ix.gui and ix.gui.menu) then
			ix.gui.menu:Remove()
		end

		vgui.Create("ixCharMenu")
	end

	function VR:OpenStaffSelector()
		if LeopardRP and LeopardRP.Personnel and isfunction(LeopardRP.Personnel.RequestMenuAccess) then
			LeopardRP.Personnel.RequestMenuAccess("staff")
		end
	end

	function VR:OpenPersonnelSelector()
		if LeopardRP and LeopardRP.Personnel and isfunction(LeopardRP.Personnel.RequestMenuAccess) then
			LeopardRP.Personnel.RequestMenuAccess("personnel")
		end
	end

	function VR:OpenInventory()
		if LeopardRP and LeopardRP.Personnel and isfunction(LeopardRP.Personnel.OpenHelixInventory) then
			LeopardRP.Personnel.OpenHelixInventory()
			return
		end

		if not IsValid(ix and ix.gui and ix.gui.menu) then
			vgui.Create("ixMenu")
		end
	end

	local quickMenuItemsAdded = false

	local function addQuickMenuItems()
		if quickMenuItemsAdded or not (vrmod and isfunction(vrmod.AddInGameMenuItem)) then
			return
		end

		quickMenuItemsAdded = true

		vrmod.AddInGameMenuItem("LeopardRP Main Menu", 4, 0, function()
			VR:OpenMainMenu()
		end)

		vrmod.AddInGameMenuItem("LeopardRP Characters", 4, 1, function()
			VR:OpenCharacterSelection()
		end)

		vrmod.AddInGameMenuItem("LeopardRP Staff Menu", 4, 2, function()
			VR:OpenStaffSelector()
		end)

		vrmod.AddInGameMenuItem("LeopardRP Personnel", 4, 3, function()
			VR:OpenPersonnelSelector()
		end)

		vrmod.AddInGameMenuItem("LeopardRP Inventory", 4, 4, function()
			VR:OpenInventory()
		end)
	end

	local function removeQuickMenuItems()
		if not quickMenuItemsAdded or not (vrmod and isfunction(vrmod.RemoveInGameMenuItem)) then
			return
		end

		quickMenuItemsAdded = false

		vrmod.RemoveInGameMenuItem("LeopardRP Main Menu")
		vrmod.RemoveInGameMenuItem("LeopardRP Characters")
		vrmod.RemoveInGameMenuItem("LeopardRP Staff Menu")
		vrmod.RemoveInGameMenuItem("LeopardRP Personnel")
		vrmod.RemoveInGameMenuItem("LeopardRP Inventory")
	end

	hook.Add("VRMod_Start", "LeopardRP.VR.SessionState", function(ply)
		if not IsValid(ply) or ply ~= LocalPlayer() then
			return
		end

		VR.LocalSessionActive = true
		addQuickMenuItems()
	end)

	hook.Add("VRMod_Exit", "LeopardRP.VR.SessionState", function(ply)
		if not IsValid(ply) or ply ~= LocalPlayer() then
			return
		end

		VR.LocalSessionActive = false
		removeQuickMenuItems()
	end)

	hook.Add("InitPostEntity", "LeopardRP.VR.QuickMenuBootstrap", function()
		if VR:IsPlayerInVR(LocalPlayer()) then
			addQuickMenuItems()
		end
	end)
end

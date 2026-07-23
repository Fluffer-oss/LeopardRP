include("shared.lua")

function ENT:Draw()
	self:DrawModel()
end

net.Receive("LeopardRP.WardrobeOpen", function()
	local wardrobe = net.ReadEntity()
	local characterData = net.ReadTable()

	if not IsValid(wardrobe) then return end

	local frame = vgui.Create("DFrame")
	frame:SetTitle("Wardrobe")
	frame:SetSize(400, 300)
	frame:Center()
	frame:MakePopup()

	local divisionLabel = frame:Add("DLabel")
	divisionLabel:SetText("Division:")
	divisionLabel:SetPos(10, 30)
	divisionLabel:SetSize(100, 20)

	local divisionCombo = frame:Add("DComboBox")
	divisionCombo:SetPos(120, 30)
	divisionCombo:SetSize(260, 20)

	if ix.leopardrp and ix.leopardrp.character and ix.leopardrp.character.GetDivisions then
		for divName, _ in pairs(ix.leopardrp.character.GetDivisions() or {}) do
			divisionCombo:AddChoice(divName, divName, divName == characterData.division)
		end
	end

	local uniformLabel = frame:Add("DLabel")
	uniformLabel:SetText("Uniform Type:")
	uniformLabel:SetPos(10, 60)
	uniformLabel:SetSize(100, 20)

	local uniformCombo = frame:Add("DComboBox")
	uniformCombo:SetPos(120, 60)
	uniformCombo:SetSize(260, 20)

	if ix.leopardrp and ix.leopardrp.character and ix.leopardrp.character.GetUniformTypes then
		for uniformType, _ in pairs(ix.leopardrp.character.GetUniformTypes() or {}) do
			uniformCombo:AddChoice(uniformType, uniformType, uniformType == characterData.uniformType)
		end
	end

	local applyButton = frame:Add("DButton")
	applyButton:SetText("Apply Appearance")
	applyButton:SetPos(10, 260)
	applyButton:SetSize(380, 30)

	function applyButton:DoClick()
		local newDivision = divisionCombo:GetSelectedValue() or characterData.division
		local newUniform = uniformCombo:GetSelectedValue() or characterData.uniformType

		net.Start("LeopardRP.WardrobeApply")
			net.WriteString(newDivision)
			net.WriteString(newUniform)
		net.SendToServer()

		frame:Close()
	end
end)

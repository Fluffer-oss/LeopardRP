ITEM.name = "Combadge"
ITEM.description = "A standard Starfleet combadge used for voice hails and channel communication."
ITEM.category = "Equipment"
ITEM.model = "models/oninoni/star_trek/props/combadge.mdl"
ITEM.class = "weapon_leopardrp_combadge"
ITEM.slotType = "combadge"
ITEM.width = 1
ITEM.height = 1
ITEM.isWeapon = true
ITEM.weaponCategory = "combadge"
ITEM.noBusiness = true
ITEM.base = "base_weapons"
ITEM.CanUseOnPlayer = false

if CLIENT then
    function ITEM:PopulateTooltip(tooltip)
        if self:GetData("equip") then
            local name = tooltip:GetRow("name")

            if name then
                name:SetBackgroundColor(derma.GetColor("Success", tooltip))
            end
        end
    end
end
if SERVER then
    AddCSLuaFile()
end

SWEP = SWEP or {}

SWEP.Base = "weapon_base"
SWEP.PrintName = "Combadge"
SWEP.Author = "LeopardRP"
SWEP.Instructions = "Primary: Hail/Respond | Secondary: Deny incoming hail | , : Cycle voice range"
SWEP.Category = "LeopardRP"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.UseHands = false
SWEP.HoldType = "slam"
SWEP.ViewModel = "models/oninoni/star_trek/props/combadge.mdl"
SWEP.WorldModel = "models/oninoni/star_trek/props/combadge.mdl"
SWEP.ViewModelFOV = 65
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Slot = 3
SWEP.SlotPos = 1
SWEP.ShowViewModel = false
SWEP.ShowWorldModel = false
SWEP.ChestModel = "models/combadges/2370s_combadge.mdl"

if CLIENT then
    SWEP.WepSelectIcon = surface.GetTextureID("entities/weapon_pistol")
end

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    if self.BaseClass and self.BaseClass.Initialize then
        self.BaseClass.Initialize(self)
    end

    self:SetHoldType(self.HoldType)
end

function SWEP:Deploy()
    if self.BaseClass and self.BaseClass.Deploy then
        self.BaseClass.Deploy(self)
    end

    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.3)

    if CLIENT and IsFirstTimePredicted() and LeopardRP and LeopardRP.Combadge and LeopardRP.Combadge.HandleWeaponPrimary then
        LeopardRP.Combadge:HandleWeaponPrimary()
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.3)

    if CLIENT and IsFirstTimePredicted() and LeopardRP and LeopardRP.Combadge and LeopardRP.Combadge.HandleWeaponSecondary then
        LeopardRP.Combadge:HandleWeaponSecondary()
    end
end

function SWEP:Reload()
    return false
end

if CLIENT then
    function SWEP:DrawHUD()
        return
    end
end

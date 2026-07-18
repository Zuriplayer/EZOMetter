-- Deteccion automatica conservadora de rol por armas y habilidades sloteadas.
EZOMetter_RoleDetector = EZOMetter_RoleDetector or {}

local Detector = EZOMetter_RoleDetector
local ADDON_NAME = "EZOMetter"

local ROLE_DD = "dd"
local ROLE_HEALER = "healer"
local ROLE_TANK = "tank"

local updatePending = false

local tankSkillHints = {
    "puncture",
    "pierce armor",
    "ransack",
    "inner fire",
    "inner rage",
    "frost clench",
    "destructive clench",
    "silver leash",
    "beckoning armor",
    "chains",
    "perforacion",
    "armadura perforante",
    "saqueo",
    "fuego interior",
    "ira interior",
    "agarre helado",
    "agarre destructivo",
    "lazo de plata",
}

local healerSkillHints = {
    "grand healing",
    "healing springs",
    "illustrious healing",
    "regeneration",
    "rapid regeneration",
    "radiating regeneration",
    "blessing of protection",
    "combat prayer",
    "steadfast ward",
    "healing ward",
    "ward ally",
    "force siphon",
    "siphon spirit",
    "energy orb",
    "mystic orb",
    "breath of life",
    "honor the dead",
    "budding seeds",
    "enchanted growth",
    "gran curacion",
    "curacion ilustre",
    "regeneracion",
    "regeneracion rapida",
    "regeneracion radiante",
    "bendicion de proteccion",
    "plegaria de combate",
    "resguardo firme",
    "resguardo curativo",
    "orbe de energia",
    "orbe mistico",
    "aliento de vida",
    "honrar a los muertos",
    "semillas en ciernes",
    "crecimiento encantado",
}

local accentMap = {
    ["á"] = "a",
    ["é"] = "e",
    ["í"] = "i",
    ["ó"] = "o",
    ["ú"] = "u",
    ["Á"] = "a",
    ["É"] = "e",
    ["Í"] = "i",
    ["Ó"] = "o",
    ["Ú"] = "u",
    ["ñ"] = "n",
    ["Ñ"] = "n",
}

local function IsAutoEnabled()
    return EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.roleMode == "auto"
end

local function NormalizeName(name)
    name = tostring(name or "")
    if name == "" then return "" end

    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        name = zo_strformat(SI_ABILITY_NAME, name)
    end
    name = string.gsub(name, "%^.*", "")
    name = string.gsub(name, "[%z\1-\31]", "")
    name = string.gsub(name, "[%z\127-\255][\128-\191]*", accentMap)
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function ContainsAny(name, hints)
    local normalized = NormalizeName(name)
    if normalized == "" then return false end

    for _, hint in ipairs(hints) do
        if string.find(normalized, hint, 1, true) then
            return true
        end
    end
    return false
end

local function GetWeaponType(slot)
    if not BAG_WORN or not slot then return nil end

    if type(GetItemWeaponType) == "function" then
        local weaponType = GetItemWeaponType(BAG_WORN, slot)
        if weaponType and weaponType ~= 0 then return weaponType end
    end

    if type(GetItemLink) == "function" and type(GetItemLinkWeaponType) == "function" then
        local itemLink = GetItemLink(BAG_WORN, slot)
        if itemLink and itemLink ~= "" then
            local weaponType = GetItemLinkWeaponType(itemLink)
            if weaponType and weaponType ~= 0 then return weaponType end
        end
    end

    return nil
end

local function IsOneHandWeapon(weaponType)
    if not weaponType then return false end
    if WEAPONTYPE_AXE and weaponType == WEAPONTYPE_AXE then return true end
    if WEAPONTYPE_DAGGER and weaponType == WEAPONTYPE_DAGGER then return true end
    if WEAPONTYPE_HAMMER and weaponType == WEAPONTYPE_HAMMER then return true end
    if WEAPONTYPE_SWORD and weaponType == WEAPONTYPE_SWORD then return true end
    return false
end

local function ScanWeapons()
    local tankScore = 0
    local healerScore = 0

    local pairsToScan = {
        { main = EQUIP_SLOT_MAIN_HAND, off = EQUIP_SLOT_OFF_HAND },
        { main = EQUIP_SLOT_BACKUP_MAIN, off = EQUIP_SLOT_BACKUP_OFF },
    }

    for _, pair in ipairs(pairsToScan) do
        local mainType = GetWeaponType(pair.main)
        local offType = GetWeaponType(pair.off)

        if (WEAPONTYPE_RESTORATION_STAFF and mainType == WEAPONTYPE_RESTORATION_STAFF)
            or (WEAPONTYPE_HEALING_STAFF and mainType == WEAPONTYPE_HEALING_STAFF)
        then
            healerScore = healerScore + 3
        end

        if WEAPONTYPE_FROST_STAFF and mainType == WEAPONTYPE_FROST_STAFF then
            tankScore = tankScore + 1
        end

        if WEAPONTYPE_SHIELD and offType == WEAPONTYPE_SHIELD and IsOneHandWeapon(mainType) then
            tankScore = tankScore + 4
        end
    end

    return tankScore, healerScore
end

local function GetHotbarCategories()
    local categories = {}
    if HOTBAR_CATEGORY_PRIMARY then table.insert(categories, HOTBAR_CATEGORY_PRIMARY) end
    if HOTBAR_CATEGORY_BACKUP then table.insert(categories, HOTBAR_CATEGORY_BACKUP) end
    if #categories == 0 and type(GetActiveHotbarCategory) == "function" then
        table.insert(categories, GetActiveHotbarCategory())
    end
    return categories
end

local function ScanSkills()
    local tankScore = 0
    local healerScore = 0

    if type(GetSlotName) ~= "function" then
        return tankScore, healerScore
    end

    for _, hotbarCategory in ipairs(GetHotbarCategories()) do
        for slot = 3, 8 do
            local slotName = GetSlotName(slot, hotbarCategory)
            if ContainsAny(slotName, tankSkillHints) then
                tankScore = tankScore + 2
            end
            if ContainsAny(slotName, healerSkillHints) then
                healerScore = healerScore + 2
            end
        end
    end

    return tankScore, healerScore
end

local function RefreshVisualModules()
    if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
        EZOMetter_BuffAlert.ApplySettings()
    end
    if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
        EZOMetter_OffBalance.ApplySettings()
    end
    if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
        EZOMetter_Coral.ApplySettings()
    end
    if EZOMetter_Alkosh and EZOMetter_Alkosh.ApplySettings then
        EZOMetter_Alkosh.ApplySettings()
    end
    if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
        EZOMetter_DDStats.ApplySettings()
    end
    if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
        EZOMetter_ObservedDamage.ApplySettings()
    end
    if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
        EZOMetter_ObservedHealing.ApplySettings()
    end
    if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.ApplySettings then
        EZOMetter_AbilityTracker.ApplySettings()
    end
end

function Detector.DetectRole()
    local weaponTank, weaponHealer = ScanWeapons()
    local skillTank, skillHealer = ScanSkills()
    local tankScore = weaponTank + skillTank
    local healerScore = weaponHealer + skillHealer

    if tankScore >= 4 and tankScore > healerScore then
        return ROLE_TANK, tankScore, healerScore
    end
    if healerScore >= 3 and healerScore > tankScore then
        return ROLE_HEALER, tankScore, healerScore
    end
    return ROLE_DD, tankScore, healerScore
end

function Detector.Refresh(force)
    if not IsAutoEnabled() then return end

    local role, tankScore, healerScore = Detector.DetectRole()
    local currentRole = EZOMetter.sv.general.role or ROLE_DD
    EZOMetter.sv.general.autoRoleTankScore = tankScore
    EZOMetter.sv.general.autoRoleHealerScore = healerScore
    if force or role ~= currentRole then
        EZOMetter.sv.general.role = role
        RefreshVisualModules()
    end
end

local function QueueRefresh()
    if updatePending then return end
    updatePending = true
    zo_callLater(function()
        updatePending = false
        Detector.Refresh(false)
    end, 250)
end

function Detector.Init()
    Detector.Refresh(true)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_RoleDetectorActivated", EVENT_PLAYER_ACTIVATED, QueueRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_RoleDetectorSlots", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, QueueRefresh)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_RoleDetectorSlotUpdated", EVENT_ACTION_SLOT_UPDATED, QueueRefresh)

    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_RoleDetectorWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, QueueRefresh)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_RoleDetectorInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, QueueRefresh)
    end
end

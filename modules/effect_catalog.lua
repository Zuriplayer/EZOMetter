-- Catalogo pequeno de efectos por rol. Se puede ampliar sin mezclar logica de UI.
EZOMetter.Effects = EZOMetter.Effects or {}

local Effects = EZOMetter.Effects
local localizedNamesByKey = {}
local equippedSetByKey = {}

Effects.ROLE_DD = "dd"
Effects.ROLE_HEALER = "healer"
Effects.ROLE_TANK = "tank"

Effects.Definitions = {
    major_brutality = {
        key = "major_brutality",
        nameString = "EZOM_EFFECT_MAJOR_BRUTALITY",
        abilityIds = { 61665 },
    },
    major_savagery = {
        key = "major_savagery",
        nameString = "EZOM_EFFECT_MAJOR_SAVAGERY",
        abilityIds = { 61667 },
    },
    banner_bearer = {
        key = "banner_bearer",
        nameString = "EZOM_EFFECT_BANNER_BEARER",
        abilityIds = { 217699, 230289 },
        ownToggleOnly = true,
        buffAbilityIds = {
            227066,
            227067,
            227069,
            227003,
            227004,
            227007,
            227008,
            227009,
            227070,
            227071,
            227073,
            227075,
            227082,
            227085,
            227086,
            227087,
            227088,
            227089,
            217704,
            217705,
            217706,
        },
        requiresSlotted = true,
        requiresCastByPlayer = true,
        aliases = {
            "Banner Bearer",
            "Binding Banner",
            "Fiery Banner",
            "Fortifying Banner",
            "Magical Banner",
            "Restorative Banner",
            "Shattering Banner",
            "Shocking Banner",
            "Sundering Banner",
            "Portaestandarte",
            "Estandarte ardiente",
            "Estandarte demoledor",
            "Estandarte electrizante",
            "Estandarte escindidor",
            "Estandarte fortalecedor",
            "Estandarte magico",
            "Estandarte mágico",
            "Estandarte restaurador",
            "Estandarte vinculante",
        },
    },
    spaulder_aura = {
        key = "spaulder_aura",
        nameString = "EZOM_EFFECT_SPAULDER_AURA",
        -- Aura of Pride is emitted as a ground-AOE combat event rather than
        -- a player buff. 163359 is the native Spaulders of Ruin event ID.
        combatAbilityIds = { 163359 },
        -- This is the fallback texture when the equipped shoulder item cannot
        -- be read yet.
        icon = "EsoUI/Art/Icons/ability_mage_065.dds",
        iconSlot = "shoulders",
        setId = 627,
        setAliases = {
            "Spaulder of Ruin",
            "Bufa de la ruina",
        },
        requiresEquippedSet = true,
        requiresCastByPlayer = true,
        aliases = {
            "Aura of Pride",
            "Aura de orgullo",
        },
    },
}

Effects.RequiredKeysByRole = {
    dd = {
        "major_brutality",
        "major_savagery",
        "banner_bearer",
    },
    healer = {
        "major_brutality",
        "major_savagery",
        "spaulder_aura",
    },
    tank = {},
}

function Effects.GetRequiredForRole(role)
    local keys = Effects.RequiredKeysByRole[tostring(role or Effects.ROLE_DD)] or {}
    local effects = {}
    for _, key in ipairs(keys) do
        if Effects.Definitions[key] then
            table.insert(effects, Effects.Definitions[key])
        end
    end
    return effects
end

function Effects.GetPrimaryAbilityId(effect)
    if not effect or not effect.abilityIds then return nil end
    return effect.abilityIds[1]
end

function Effects.InvalidateEquipmentConditions()
    equippedSetByKey = {}
end

function Effects.IsRequiredSetEquipped(effect)
    if not effect or effect.requiresEquippedSet ~= true then return true end
    if equippedSetByKey[effect.key] ~= nil then
        return equippedSetByKey[effect.key]
    end

    local equipped = false
    if EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.GetWornSetSnapshot then
        local snapshot = EZOMetter_EquipmentSets.GetWornSetSnapshot(function(setName, setId)
            if tonumber(setId) == tonumber(effect.setId) then return true end
            return EZOMetter_EquipmentSets.NameMatches(setName, effect.setAliases)
        end)
        equipped = snapshot and snapshot.hasSet == true and (tonumber(snapshot.numEquipped) or 0) >= 1
    end

    equippedSetByKey[effect.key] = equipped
    return equipped
end

function Effects.GetEquippedSetIcon(effect)
    if not effect
        or effect.requiresEquippedSet ~= true
        or effect.iconSlot ~= "shoulders"
        or BAG_WORN == nil
        or EQUIP_SLOT_SHOULDERS == nil
        or type(GetItemLink) ~= "function"
        or type(GetItemLinkIcon) ~= "function"
        or not EZOMetter_EquipmentSets
        or type(EZOMetter_EquipmentSets.GetSetSnapshotFromItemLink) ~= "function" then
        return nil
    end

    local itemLink = GetItemLink(BAG_WORN, EQUIP_SLOT_SHOULDERS)
    if not itemLink or itemLink == "" then return nil end

    local snapshot = EZOMetter_EquipmentSets.GetSetSnapshotFromItemLink(itemLink, function(setName, setId)
        if tonumber(setId) == tonumber(effect.setId) then return true end
        return EZOMetter_EquipmentSets.NameMatches(setName, effect.setAliases)
    end)
    if not snapshot or snapshot.hasSet ~= true then return nil end

    local icon = GetItemLinkIcon(itemLink)
    if icon and icon ~= "" then
        return icon
    end

    return nil
end

local function NormalizeName(name)
    name = tostring(name or "")
    if name == "" then return "" end
    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        name = zo_strformat(SI_ABILITY_NAME, name)
    end
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function GetLocalizedNames(effect)
    if not effect or not effect.key then return {} end
    if localizedNamesByKey[effect.key] then
        return localizedNamesByKey[effect.key]
    end

    local names = {}
    if effect.abilityIds and type(GetAbilityName) == "function" then
        for _, abilityId in ipairs(effect.abilityIds) do
            local abilityName = GetAbilityName(abilityId)
            local normalized = NormalizeName(abilityName)
            if normalized ~= "" then
                names[normalized] = true
            end
        end
    end

    if effect.aliases then
        for _, alias in ipairs(effect.aliases) do
            local normalized = NormalizeName(alias)
            if normalized ~= "" then
                names[normalized] = true
            end
        end
    end

    localizedNamesByKey[effect.key] = names
    return names
end

function Effects.Matches(effect, abilityId, effectName)
    if not effect then return false end

    if abilityId and effect.abilityIds then
        for _, effectAbilityId in ipairs(effect.abilityIds) do
            if effectAbilityId == abilityId then
                return true
            end
        end
    end

    local normalizedName = NormalizeName(effectName)
    if normalizedName == "" then return false end

    return GetLocalizedNames(effect)[normalizedName] == true
end

function Effects.MatchesBuffAbility(effect, abilityId, effectName)
    if not effect then return false end

    if abilityId and effect.buffAbilityIds then
        for _, effectAbilityId in ipairs(effect.buffAbilityIds) do
            if effectAbilityId == abilityId then
                return true
            end
        end
    end

    return Effects.Matches(effect, abilityId, effectName)
end

function Effects.MatchesBuff(effect, abilityId, effectName, castByPlayer)
    if not effect then return false end
    if effect.requiresCastByPlayer == true and castByPlayer ~= true then
        return false
    end

    return Effects.MatchesBuffAbility(effect, abilityId, effectName)
end

local function GetHotbarCategories()
    local categories = {}
    if HOTBAR_CATEGORY_PRIMARY then
        table.insert(categories, HOTBAR_CATEGORY_PRIMARY)
    end
    if HOTBAR_CATEGORY_BACKUP then
        table.insert(categories, HOTBAR_CATEGORY_BACKUP)
    end
    if #categories == 0 and type(GetActiveHotbarCategory) == "function" then
        table.insert(categories, GetActiveHotbarCategory())
    end
    return categories
end

function Effects.IsSlotted(effect)
    if not effect or type(GetSlotBoundId) ~= "function" or type(GetSlotType) ~= "function" then
        return false
    end

    for _, hotbarCategory in ipairs(GetHotbarCategories()) do
        for slotIndex = 3, 8 do
            local actionType = GetSlotType(slotIndex, hotbarCategory)
            local boundId = GetSlotBoundId(slotIndex, hotbarCategory)
            local trueAbilityId = boundId
            local slotName = ""

            if type(GetSlotName) == "function" then
                slotName = GetSlotName(slotIndex, hotbarCategory) or ""
            end

            if actionType == ACTION_TYPE_CRAFTED_ABILITY and type(GetAbilityIdForCraftedAbilityId) == "function" then
                trueAbilityId = GetAbilityIdForCraftedAbilityId(boundId)
            end

            if slotName == "" and trueAbilityId and type(GetAbilityName) == "function" then
                slotName = GetAbilityName(trueAbilityId)
            end

            if Effects.Matches(effect, trueAbilityId, slotName) or Effects.Matches(effect, boundId, slotName) then
                return true
            end
        end
    end

    return false
end

-- Some persistent skills are best identified from the player's own slotted
-- toggle state. This avoids treating a matching group buff as the player's
-- Banner Bearer.
function Effects.IsOwnToggleActive(effect)
    if not effect
        or effect.ownToggleOnly ~= true
        or type(GetSlotBoundId) ~= "function"
        or type(GetSlotType) ~= "function"
        or type(IsSlotToggled) ~= "function" then
        return false
    end

    for _, hotbarCategory in ipairs(GetHotbarCategories()) do
        for slotIndex = 3, 8 do
            local actionType = GetSlotType(slotIndex, hotbarCategory)
            local boundId = GetSlotBoundId(slotIndex, hotbarCategory)
            local trueAbilityId = boundId
            local slotName = ""

            if type(GetSlotName) == "function" then
                slotName = GetSlotName(slotIndex, hotbarCategory) or ""
            end

            if actionType == ACTION_TYPE_CRAFTED_ABILITY and type(GetAbilityIdForCraftedAbilityId) == "function" then
                trueAbilityId = GetAbilityIdForCraftedAbilityId(boundId)
            end

            if slotName == "" and trueAbilityId and type(GetAbilityName) == "function" then
                slotName = GetAbilityName(trueAbilityId)
            end

            if (Effects.Matches(effect, trueAbilityId, slotName) or Effects.Matches(effect, boundId, slotName))
                and IsSlotToggled(slotIndex, hotbarCategory) == true then
                return true
            end
        end
    end

    return false
end

function Effects.ShouldRequire(effect)
    if not effect then return false end
    if not Effects.IsRequiredSetEquipped(effect) then return false end
    if effect.requiresSlotted == true then
        return Effects.IsSlotted(effect)
    end
    return true
end

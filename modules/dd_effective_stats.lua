-- Catalogo y calculo de stats DD efectivos sobre el objetivo.
EZOMetter_DDEffectiveStats = EZOMetter_DDEffectiveStats or {}

local Effective = EZOMetter_DDEffectiveStats

local TARGET_TAGS = { "reticleover", "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }
local DEFAULT_TARGET_RESISTANCE = 18200
local DEFAULT_CRIT_DAMAGE_CAP = 125
local DEFAULT_CRUSHER = 2108
local DEFAULT_ALKOSH = 6000
local DEFAULT_TREMORSCALE = 2640

local function NormalizeName(name)
    name = tostring(name or "")
    if name == "" then return "" end
    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        name = zo_strformat(SI_ABILITY_NAME, name)
    end
    name = string.gsub(name, "%^.*", "")
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function IsReadableTarget(unitTag)
    if type(DoesUnitExist) ~= "function" or not DoesUnitExist(unitTag) then return false end
    if unitTag == "reticleover" and type(IsUnitAttackable) == "function" then
        return IsUnitAttackable(unitTag)
    end
    return string.sub(unitTag, 1, 4) == "boss"
end

local function GetSetting(settings, key, fallback)
    local value = settings and tonumber(settings[key]) or nil
    if not value or value < 0 then return fallback end
    return value
end

function Effective.GetTargetResistance(settings)
    return GetSetting(settings, "targetResistance", DEFAULT_TARGET_RESISTANCE)
end

function Effective.GetCritDamageCap(settings)
    return GetSetting(settings, "critDamageCap", DEFAULT_CRIT_DAMAGE_CAP)
end

local function GetModifierValue(modifier, settings)
    if modifier.settingKey then
        return GetSetting(settings, modifier.settingKey, modifier.defaultValue or 0)
    end
    return modifier.value or 0
end

local TARGET_MODIFIERS = {
    {
        key = "majorBreach",
        stat = "penetration",
        value = 5948,
        abilityIds = { 61743 },
    },
    {
        key = "minorBreach",
        stat = "penetration",
        value = 2974,
        abilityIds = { 61742 },
    },
    {
        key = "crusher",
        stat = "penetration",
        settingKey = "crusherValue",
        defaultValue = DEFAULT_CRUSHER,
        abilityIds = { 120007, 17906 },
    },
    {
        key = "crystalWeapon",
        stat = "penetration",
        value = 1000,
        abilityIds = { 143808 },
    },
    {
        key = "alkosh",
        stat = "penetration",
        settingKey = "alkoshValue",
        defaultValue = DEFAULT_ALKOSH,
        abilityIds = { 120018, 76667 },
    },
    {
        key = "crimsonOath",
        stat = "penetration",
        value = 3541,
        abilityIds = { 159288 },
    },
    {
        key = "runicSunder",
        stat = "penetration",
        value = 2200,
        abilityIds = { 187742 },
    },
    {
        key = "tremorscale",
        stat = "penetration",
        settingKey = "tremorscaleValue",
        defaultValue = DEFAULT_TREMORSCALE,
        abilityIds = { 80866 },
    },
    {
        key = "ecFlame",
        stat = "critDamage",
        group = "elementalCatalyst",
        value = 5,
        abilityIds = { 142610 },
    },
    {
        key = "ecShock",
        stat = "critDamage",
        group = "elementalCatalyst",
        value = 5,
        abilityIds = { 142653 },
    },
    {
        key = "ecFrost",
        stat = "critDamage",
        group = "elementalCatalyst",
        value = 5,
        abilityIds = { 142652 },
    },
    {
        key = "elementalCatalyst",
        stat = "critDamage",
        group = "elementalCatalyst",
        groupCap = 15,
        value = 15,
        abilityIds = { 181606 },
    },
    {
        key = "minorBrittle",
        stat = "critDamage",
        value = 10,
        abilityIds = { 145975 },
    },
    {
        key = "majorBrittle",
        stat = "critDamage",
        value = 20,
        abilityIds = { 145977 },
    },
}

local modifierByAbilityId = {}
local modifierNamesReady = false

local function EnsureModifierIndexes()
    if next(modifierByAbilityId) == nil then
        for _, modifier in ipairs(TARGET_MODIFIERS) do
            for _, abilityId in ipairs(modifier.abilityIds or {}) do
                modifierByAbilityId[abilityId] = modifier
            end
        end
    end

    if modifierNamesReady or type(GetAbilityName) ~= "function" then return end
    for _, modifier in ipairs(TARGET_MODIFIERS) do
        modifier.names = modifier.names or {}
        for _, abilityId in ipairs(modifier.abilityIds or {}) do
            local normalized = NormalizeName(GetAbilityName(abilityId))
            if normalized ~= "" then
                modifier.names[normalized] = true
            end
        end
    end
    modifierNamesReady = true
end

local function GetModifier(abilityId, effectName)
    EnsureModifierIndexes()

    abilityId = tonumber(abilityId)
    if abilityId and modifierByAbilityId[abilityId] then
        return modifierByAbilityId[abilityId]
    end

    local normalized = NormalizeName(effectName)
    if normalized == "" then return nil end
    for _, modifier in ipairs(TARGET_MODIFIERS) do
        if modifier.names and modifier.names[normalized] then
            return modifier
        end
    end
    return nil
end

local function AddModifier(result, modifier, settings)
    if not modifier or result.byKey[modifier.key] then return end

    local value = GetModifierValue(modifier, settings)
    if value <= 0 then return end

    result.byKey[modifier.key] = true
    table.insert(result.active, {
        key = modifier.key,
        stat = modifier.stat,
        value = value,
    })

    if modifier.group then
        local group = result.groups[modifier.group] or {
            stat = modifier.stat,
            value = 0,
            cap = modifier.groupCap,
        }
        group.value = group.value + value
        group.cap = modifier.groupCap or group.cap
        result.groups[modifier.group] = group
        return
    end

    result[modifier.stat] = (result[modifier.stat] or 0) + value
end

local function FinalizeGroups(result)
    for _, group in pairs(result.groups) do
        local value = group.value
        if group.cap then
            value = math.min(group.cap, value)
        end
        result[group.stat] = (result[group.stat] or 0) + value
    end
end

function Effective.ScanTarget(settings)
    local result = {
        penetration = 0,
        critDamage = 0,
        byKey = {},
        groups = {},
        active = {},
        targetTag = nil,
        hasReadableTarget = false,
    }

    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return result
    end

    for _, unitTag in ipairs(TARGET_TAGS) do
        if IsReadableTarget(unitTag) then
            result.hasReadableTarget = true
            result.targetTag = result.targetTag or unitTag
            for index = 1, GetNumBuffs(unitTag) do
                local buffName, _, _, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, index)
                AddModifier(result, GetModifier(abilityId, buffName), settings)
            end
            if #result.active > 0 then
                result.targetTag = unitTag
                break
            end
        end
    end

    FinalizeGroups(result)
    result.groups = nil
    return result
end

function Effective.BuildValues(ownValues, settings)
    ownValues = ownValues or {}
    local target = Effective.ScanTarget(settings)
    local targetResistance = Effective.GetTargetResistance(settings)
    local critDamageCap = Effective.GetCritDamageCap(settings)

    local penetrationOwn = tonumber(ownValues.penetration)
    local critDamageOwn = tonumber(ownValues.critDamage)
    local penetrationUncapped = penetrationOwn and (penetrationOwn + target.penetration) or nil
    local critDamageUncapped = critDamageOwn and (critDamageOwn + target.critDamage) or nil

    return {
        target = target,
        targetResistance = targetResistance,
        critDamageCap = critDamageCap,
        values = {
            damage = tonumber(ownValues.damage),
            crit = tonumber(ownValues.crit),
            penetration = penetrationUncapped and math.min(targetResistance, penetrationUncapped) or nil,
            critDamage = critDamageUncapped and math.min(critDamageCap, critDamageUncapped) or nil,
        },
        uncappedValues = {
            damage = tonumber(ownValues.damage),
            crit = tonumber(ownValues.crit),
            penetration = penetrationUncapped,
            critDamage = critDamageUncapped,
        },
    }
end

function Effective.GetModifiers()
    return TARGET_MODIFIERS
end

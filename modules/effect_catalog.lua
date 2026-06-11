-- Catalogo pequeno de efectos por rol. Se puede ampliar sin mezclar logica de UI.
EZOMetter.Effects = EZOMetter.Effects or {}

local Effects = EZOMetter.Effects
local localizedNamesByKey = {}

Effects.ROLE_DD = "dd"
Effects.ROLE_HEALER = "healer"
Effects.ROLE_TANK = "tank"

Effects.RequiredByRole = {
    dd = {
        {
            key = "major_brutality",
            nameString = "EZOM_EFFECT_MAJOR_BRUTALITY",
            abilityIds = { 61665 },
        },
        {
            key = "major_sorcery",
            nameString = "EZOM_EFFECT_MAJOR_SORCERY",
            abilityIds = { 61687 },
        },
        {
            key = "major_savagery",
            nameString = "EZOM_EFFECT_MAJOR_SAVAGERY",
            abilityIds = { 61667 },
        },
        {
            key = "major_prophecy",
            nameString = "EZOM_EFFECT_MAJOR_PROPHECY",
            abilityIds = { 61689 },
        },
        {
            key = "banner_bearer",
            nameString = "EZOM_EFFECT_BANNER_BEARER",
            abilityIds = { 217699 },
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
    },
    healer = {},
    tank = {},
}

function Effects.GetRequiredForRole(role)
    return Effects.RequiredByRole[tostring(role or Effects.ROLE_DD)] or {}
end

function Effects.GetPrimaryAbilityId(effect)
    if not effect or not effect.abilityIds then return nil end
    return effect.abilityIds[1]
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

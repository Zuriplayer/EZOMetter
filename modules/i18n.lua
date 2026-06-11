-- Capa sencilla para elegir idioma sin complicar el addon.
EZOMetter_Lang = EZOMetter_Lang or {}

local function ApplyString(id, value, version)
    local stringId = _G[id]
    if stringId == nil then
        ZO_CreateStringId(id, value)
        stringId = _G[id]
    end

    if stringId ~= nil then
        SafeAddString(stringId, value, version)
    end
end

function EZOMetter_Lang.Apply(language)
    local effectiveLanguage = language
    if EZOMetter and type(EZOMetter.GetEffectiveLanguage) == "function" then
        effectiveLanguage = EZOMetter.GetEffectiveLanguage(language)
    end

    local source = (effectiveLanguage == "es" and EZOMETTER_STRINGS_ES) or EZOMETTER_STRINGS_EN
    if not source then return end

    EZOMetter_Lang._stringVersion = (tonumber(EZOMetter_Lang._stringVersion) or 0) + 1
    for key, value in pairs(source) do
        ApplyString(key, value, EZOMetter_Lang._stringVersion)
    end

    EZOMetter_Lang.current = (effectiveLanguage == "es") and "es" or "en"
    EZOMetter_Lang.configured = tostring(language or "auto")
end

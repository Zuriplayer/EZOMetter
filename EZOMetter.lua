-- Arranque principal del addon.
EZOMetter = EZOMetter or {}
local EZOM = EZOMetter

local ADDON_NAME = "EZOMetter"
local LANGUAGE_AUTO = "auto"

local function Print(message)
    if LibChatMessage then
        LibChatMessage(ADDON_NAME, "EZOM"):Print(tostring(message))
    else
        d(tostring(message))
    end
end

EZOM.Print = Print

local function GetClientLanguage()
    if type(GetCVar) == "function" then
        local language = zo_strlower(tostring(GetCVar("Language.2") or ""))
        local prefix = language:sub(1, 2)
        if prefix == "es" then return "es" end
        if prefix == "en" then return "en" end
    end
    return "en"
end

function EZOM.GetDefaultLanguage()
    return LANGUAGE_AUTO
end

function EZOM.GetClientLanguage()
    return GetClientLanguage()
end

function EZOM.GetEffectiveLanguage(language)
    language = tostring(language or LANGUAGE_AUTO)
    if language == "es" or language == "en" then
        return language
    end
    return GetClientLanguage()
end

function EZOM.IsForcedLanguage(language)
    language = tostring(language or LANGUAGE_AUTO)
    return language == "es" or language == "en"
end

function EZOM:Initialize()
    if self.savedVars and self.savedVars.Init then
        self.savedVars.Init()
    end

    if EZOMetter_Lang and EZOMetter_Lang.Apply then
        local language = self.sv and self.sv.general and self.sv.general.language or LANGUAGE_AUTO
        EZOMetter_Lang.Apply(language)
    end

    if self.DebugLog then
        self.DebugLog(GetString(EZOM_DEBUG_SAVED_VARIABLES_LOADED))
    end

    if EZOMetter_Menu and EZOMetter_Menu.Init then
        EZOMetter_Menu.Init()
    end

    if EZOMetter_BuffAlert and EZOMetter_BuffAlert.Init then
        EZOMetter_BuffAlert.Init()
    end

    if EZOMetter_ChampionPoints and EZOMetter_ChampionPoints.Init then
        EZOMetter_ChampionPoints.Init()
    end

    if EZOMetter_OffBalance and EZOMetter_OffBalance.Init then
        EZOMetter_OffBalance.Init()
    end

    if EZOMetter_Coral and EZOMetter_Coral.Init then
        EZOMetter_Coral.Init()
    end

    if EZOMetter_DDStats and EZOMetter_DDStats.Init then
        EZOMetter_DDStats.Init()
    end

    if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.Init then
        EZOMetter_ObservedDamage.Init()
    end

    if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.Init then
        EZOMetter_ObservedHealing.Init()
    end

    if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.Init then
        EZOMetter_AbilityTracker.Init()
    end

    if EZOMetter_CombatReporter and EZOMetter_CombatReporter.Init then
        EZOMetter_CombatReporter.Init()
    end

    if EZOMetter_RoleDetector and EZOMetter_RoleDetector.Init then
        EZOMetter_RoleDetector.Init()
    end

    Print(GetString(EZOM_MSG_INIT))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EZOMetter:Initialize()
end)

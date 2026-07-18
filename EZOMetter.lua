-- Arranque principal del addon.
EZOMetter = EZOMetter or {}
local EZOM = EZOMetter

local ADDON_NAME = "EZOMetter"
local LANGUAGE_INHERIT = "inherit"
local LANGUAGE_AUTO = "auto"
EZOM.LANGUAGE_INHERIT = LANGUAGE_INHERIT
EZOM.LANGUAGE_AUTO = LANGUAGE_AUTO

local languageCallbackRegistered = false
local ezocoreRegistered = false
local layoutSurfaceRegistered = false
local debugControllerRegistered = false

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
    language = tostring(language or EZOM.GetDefaultLanguage())
    if EZOM.IsLanguageManagedByEZOCore and EZOM.IsLanguageManagedByEZOCore() then
        local ok, inherited = pcall(function()
            return EZOCore:GetLanguage()
        end)
        if ok and (inherited == "es" or inherited == "en") then
            return inherited
        end
    end
    if language == LANGUAGE_INHERIT then
        language = LANGUAGE_AUTO
    end
    if language == "es" or language == "en" then
        return language
    end
    return GetClientLanguage()
end

function EZOM.IsForcedLanguage(language)
    language = tostring(language or EZOM.GetDefaultLanguage())
    if EZOM.IsLanguageManagedByEZOCore and EZOM.IsLanguageManagedByEZOCore() then
        return false
    end
    return language == "es" or language == "en"
end

function EZOM.IsLanguageManagedByEZOCore()
    if not (EZOCore and type(EZOCore.IsLanguageGloballyManaged) == "function") then
        return false
    end
    local ok, managed = pcall(function()
        return EZOCore:IsLanguageGloballyManaged()
    end)
    return ok and managed == true
end

function EZOM.ApplyLanguagePreference(language)
    local configuredLanguage = tostring(language or EZOM.GetDefaultLanguage())
    if EZOMetter_Lang and EZOMetter_Lang.Apply then
        EZOMetter_Lang.Apply(configuredLanguage)
    end
end

function EZOM.RegisterEZOCoreLanguageCallback()
    if languageCallbackRegistered
        or not (EZOCore and type(EZOCore.RegisterCallback) == "function") then
        return false
    end

    local eventName = EZOCore.EVENT_LANGUAGE_CHANGED or "EZO_CORE_LANGUAGE_CHANGED"
    local ok, result = pcall(function()
        return EZOCore:RegisterCallback(eventName, function()
            if EZOM.sv and EZOM.sv.general then
                EZOM.ApplyLanguagePreference(EZOM.sv.general.language or EZOM.GetDefaultLanguage())
                if EZOMetter_ObservedMetricPanel and EZOMetter_ObservedMetricPanel.Refresh then
                    EZOMetter_ObservedMetricPanel.Refresh()
                end
            end
        end)
    end)
    languageCallbackRegistered = ok and result == true
    return languageCallbackRegistered
end

function EZOM.RegisterWithEZOCore()
    if ezocoreRegistered
        or not (EZOCore and type(EZOCore.RegisterAddon) == "function") then
        return false
    end

    local ok, result = pcall(function()
        return EZOCore:RegisterAddon({
            id = "ezometter",
            name = EZOM.ADDON_NAME or ADDON_NAME,
            version = EZOM.ADDON_VERSION or "0.0.0",
            addOnVersion = 10022,
            apiVersion = 1,
            capabilities = {
                "combat.metrics",
                "combat.observedPanels",
                "family.debug.controller",
                "family.language.consumer",
                "family.layout.consumer",
                "family.settings.consumer",
            },
        })
    end)

    ezocoreRegistered = ok and result == true
    return ezocoreRegistered
end

function EZOM.IsDebugModeEnabled()
    return EZOM.sv and EZOM.sv.general and EZOM.sv.general.debugMode == true
end

function EZOM.SetDebugModeEnabled(enabled)
    if not (EZOM.sv and EZOM.sv.general) then
        return false
    end
    EZOM.sv.general.debugMode = enabled == true
    return EZOM.sv.general.debugMode == (enabled == true)
end

function EZOM.RegisterDebugWithEZOCore()
    if debugControllerRegistered
        or not (EZOCore and type(EZOCore.GetService) == "function") then
        return false
    end

    local service = EZOCore:GetService("family.debug", 1)
    if not service or type(service.RegisterController) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return service:RegisterController({
            id = "ezometter.debug",
            addonId = "ezometter",
            addonName = "EZOMetter",
            name = function() return GetString(EZOM_OPTION_DEBUG_MODE) end,
            isEnabled = EZOM.IsDebugModeEnabled,
            setEnabled = function(enabled)
                return EZOM.SetDebugModeEnabled(enabled == true)
            end,
        })
    end)

    debugControllerRegistered = ok and result == true
    return debugControllerRegistered
end

function EZOM.RefreshVisualModules()
    local moduleNames = {
        "EZOMetter_BuffAlert",
        "EZOMetter_OffBalance",
        "EZOMetter_Coral",
        "EZOMetter_Alkosh",
        "EZOMetter_Zen",
        "EZOMetter_DDStats",
        "EZOMetter_ObservedDamage",
        "EZOMetter_ObservedHealing",
        "EZOMetter_AbilityTracker",
    }
    for _, moduleName in ipairs(moduleNames) do
        local visualModule = _G[moduleName]
        if visualModule and type(visualModule.ApplySettings) == "function" then
            visualModule.ApplySettings()
        end
    end
end

function EZOM.IsHudLayoutEditMode()
    return EZOM.runtime and EZOM.runtime.hudLayoutEditMode == true
end

function EZOM.SetHudLayoutEditMode(enabled)
    EZOM.runtime = EZOM.runtime or {}
    EZOM.runtime.hudLayoutEditMode = enabled == true
    if EZOM.sv and EZOM.sv.general then
        EZOM.sv.general.unlockHud = false
    end
    EZOM.RefreshVisualModules()
    return EZOM.runtime.hudLayoutEditMode
end

function EZOM.RegisterLayoutWithEZOCore()
    if layoutSurfaceRegistered
        or not (EZOCore and type(EZOCore.GetService) == "function") then
        return false
    end

    local service = EZOCore:GetService("family.layout", 1)
    if not service or type(service.RegisterSurface) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return service:RegisterSurface({
            id = "ezometter.hud",
            addonId = "ezometter",
            addonName = "EZOMetter",
            name = function() return GetString(EZOM_OPTION_UNLOCK_HUD) end,
            tooltip = function() return GetString(EZOM_OPTION_UNLOCK_HUD_TOOLTIP) end,
            setEditMode = function(enabled)
                EZOM.SetHudLayoutEditMode(enabled)
                return EZOM.IsHudLayoutEditMode() == (enabled == true)
            end,
            isEditMode = function()
                return EZOM.IsHudLayoutEditMode()
            end,
        })
    end)

    layoutSurfaceRegistered = ok and result == true
    return layoutSurfaceRegistered
end

function EZOM:Initialize()
    if self.savedVars and self.savedVars.Init then
        self.savedVars.Init()
    end

    local language = self.sv and self.sv.general and self.sv.general.language or EZOM.GetDefaultLanguage()
    EZOM.ApplyLanguagePreference(language)
    EZOM.RegisterEZOCoreLanguageCallback()
    EZOM.RegisterWithEZOCore()
    EZOM.RegisterDebugWithEZOCore()
    self.runtime = self.runtime or {}
    self.runtime.hudLayoutEditMode = false

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

    if EZOMetter_Alkosh and EZOMetter_Alkosh.Init then
        EZOMetter_Alkosh.Init()
    end

    if EZOMetter_Zen and EZOMetter_Zen.Init then
        EZOMetter_Zen.Init()
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

    EZOM.RegisterLayoutWithEZOCore()

    Print(GetString(EZOM_MSG_INIT))
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    EZOMetter:Initialize()
end)

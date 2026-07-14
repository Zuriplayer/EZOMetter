-- Panel LibAddonMenu.
EZOMetter_Menu = EZOMetter_Menu or {}

local ADDON_NAME = "EZOMetter"
local PANEL_ID = ADDON_NAME .. "_Options"
local INFO_HEADER_TEXTURE = "EsoUI/Art/Miscellaneous/help_icon.dds"

local function CreateInfoHeader(name, tooltip)
    return {
        type = "header",
        name = zo_strformat(
            "<<1>> |cB040FF|t26:26:<<2>>:inheritcolor|t|r",
            tostring(name or ""),
            INFO_HEADER_TEXTURE
        ),
        tooltip = tooltip,
    }
end

local function RefreshLanguage()
    if EZOMetter.ApplyLanguagePreference and EZOMetter.sv and EZOMetter.sv.general then
        EZOMetter.ApplyLanguagePreference(EZOMetter.sv.general.language or EZOMetter.GetDefaultLanguage())
    elseif EZOMetter_Lang and EZOMetter_Lang.Apply and EZOMetter.sv and EZOMetter.sv.general then
        EZOMetter_Lang.Apply(EZOMetter.sv.general.language or EZOMetter.GetDefaultLanguage())
    end
end

function EZOMetter_Menu.Init()
    if not LibAddonMenu2 or not EZOMetter.sv or not EZOMetter.sv.general then
        return
    end

    local panelData = {
        type = "panel",
        name = "EZOMetter",
        displayName = "E|cB040FFZ|rOMetter",
        author = EZOMetter.AUTHOR,
        version = EZOMetter.ADDON_VERSION,
        ezoStage = "development",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local function RefreshVisualModules()
        if EZOMetter and type(EZOMetter.RefreshVisualModules) == "function" then
            EZOMetter.RefreshVisualModules()
        end
    end

    local options = {
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_GENERAL),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_GENERAL), GetString(EZOM_OPTION_GENERAL_HEADER_TOOLTIP)),
                {
                    type = "dropdown",
                    name = GetString(EZOM_OPTION_LANGUAGE),
                    tooltip = GetString(EZOM_OPTION_LANGUAGE_TOOLTIP),
                    choices = {
                        GetString(EZOM_OPTION_LANGUAGE_AUTO),
                        "English",
                        "Espanol",
                    },
                    choicesValues = {
                        "auto",
                        "en",
                        "es",
                    },
                    getFunc = function()
                        local value = EZOMetter.sv.general.language or EZOMetter.GetDefaultLanguage()
                        if value == "inherit" then value = "auto" end
                        return value
                    end,
                    setFunc = function(value)
                        if value == "inherit" then value = "auto" end
                        EZOMetter.sv.general.language = value
                        RefreshLanguage()
                    end,
                    disabled = function()
                        return EZOMetter.IsLanguageManagedByEZOCore and EZOMetter.IsLanguageManagedByEZOCore()
                    end,
                    default = EZOMetter.GetDefaultLanguage(),
                },
                {
                    type = "dropdown",
                    name = GetString(EZOM_OPTION_ROLE_MODE),
                    tooltip = GetString(EZOM_OPTION_ROLE_MODE_TOOLTIP),
                    choices = {
                        GetString(EZOM_OPTION_ROLE_MODE_MANUAL),
                        GetString(EZOM_OPTION_ROLE_MODE_AUTO),
                    },
                    choicesValues = {
                        "manual",
                        "auto",
                    },
                    getFunc = function()
                        return EZOMetter.sv.general.roleMode or "manual"
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.general.roleMode = value == "auto" and "auto" or "manual"
                        if EZOMetter.sv.general.roleMode == "auto"
                            and EZOMetter_RoleDetector
                            and EZOMetter_RoleDetector.Refresh
                        then
                            EZOMetter_RoleDetector.Refresh(true)
                        else
                            RefreshVisualModules()
                        end
                    end,
                    default = "manual",
                },
                {
                    type = "dropdown",
                    name = GetString(EZOM_OPTION_ROLE),
                    tooltip = GetString(EZOM_OPTION_ROLE_TOOLTIP),
                    disabled = function()
                        return EZOMetter.sv.general.roleMode == "auto"
                    end,
                    choices = {
                        GetString(EZOM_OPTION_ROLE_DD),
                        GetString(EZOM_OPTION_ROLE_HEALER),
                        GetString(EZOM_OPTION_ROLE_TANK),
                    },
                    choicesValues = {
                        "dd",
                        "healer",
                        "tank",
                    },
                    getFunc = function()
                        return EZOMetter.sv.general.role or "dd"
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.general.role = value
                        RefreshVisualModules()
                    end,
                    default = "dd",
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_UNLOCK_HUD),
                    tooltip = GetString(EZOM_OPTION_UNLOCK_HUD_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.IsHudLayoutEditMode()
                    end,
                    setFunc = function(value)
                        EZOMetter.SetHudLayoutEditMode(value)
                    end,
                    default = false,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_COMBAT_REPORT),
                    tooltip = GetString(EZOM_OPTION_COMBAT_REPORT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.general.combatReportEnabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.general.combatReportEnabled = value == true
                    end,
                    default = false,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_ALERTS),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_ALERTS), GetString(EZOM_OPTION_ALERTS_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_MISSING_BUFF_ALERTS),
                    tooltip = GetString(EZOM_OPTION_MISSING_BUFF_ALERTS_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.alerts and EZOMetter.sv.alerts.missingBuffAlerts == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.alerts.missingBuffAlerts = value == true
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_ALERT_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_ALERT_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.alerts.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.alerts.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_ALERT_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_ALERT_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.alerts.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.alerts.showBorder = value == true
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                    end,
                    default = true,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_OFF_BALANCE),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_OFF_BALANCE), GetString(EZOM_OPTION_OFF_BALANCE_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_ENABLED),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.enabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.enabled = value == true
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_ONLY_COMBAT),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_ONLY_COMBAT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.onlyCombat ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.onlyCombat = value == true
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_ONLY_BOSSES),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_ONLY_BOSSES_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.onlyBosses == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.onlyBosses = value == true
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = false,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.offBalance.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.showBorder = value == true
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_DEBUG_EVENTS),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_DEBUG_EVENTS_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.debugEvents == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.debugEvents = value == true
                    end,
                    default = false,
                },
                {
                    type = "button",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_DEBUG_SCAN),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_DEBUG_SCAN_TOOLTIP),
                    func = function()
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.DebugScanReticle then
                            EZOMetter_OffBalance.DebugScanReticle()
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_CORAL),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_CORAL), GetString(EZOM_OPTION_CORAL_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_CORAL_ENABLED),
                    tooltip = GetString(EZOM_OPTION_CORAL_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.coral and EZOMetter.sv.coral.enabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.enabled = value == true
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_CORAL_DD_ONLY),
                    tooltip = GetString(EZOM_OPTION_CORAL_DD_ONLY_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.coral and EZOMetter.sv.coral.ddOnly ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.ddOnly = value == true
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_CORAL_ONLY_COMBAT),
                    tooltip = GetString(EZOM_OPTION_CORAL_ONLY_COMBAT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.coral and EZOMetter.sv.coral.onlyCombat ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.onlyCombat = value == true
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_CORAL_SIZE),
                    tooltip = GetString(EZOM_OPTION_CORAL_SIZE_TOOLTIP),
                    min = 70,
                    max = 140,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.coral.size or 100
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.size = tonumber(value) or 100
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = 100,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_CORAL_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_CORAL_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.coral.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_CORAL_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_CORAL_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.coral.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.showBorder = value == true
                        if EZOMetter_Coral and EZOMetter_Coral.ApplySettings then
                            EZOMetter_Coral.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_CORAL_DEBUG_EQUIPMENT),
                    tooltip = GetString(EZOM_OPTION_CORAL_DEBUG_EQUIPMENT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.coral and EZOMetter.sv.coral.debugEquipment == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.coral.debugEquipment = value == true
                    end,
                    default = false,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_DD_STATS),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_DD_STATS), GetString(EZOM_OPTION_DD_STATS_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DD_STATS_ENABLED),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.ddStats and EZOMetter.sv.ddStats.enabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.enabled = value == true
                        if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
                            EZOMetter_DDStats.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DD_STATS_DD_ONLY),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_DD_ONLY_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.ddStats and EZOMetter.sv.ddStats.ddOnly ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.ddOnly = value == true
                        if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
                            EZOMetter_DDStats.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DD_STATS_ONLY_COMBAT),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_ONLY_COMBAT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.ddStats and EZOMetter.sv.ddStats.onlyCombat == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.onlyCombat = value == true
                        if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
                            EZOMetter_DDStats.ApplySettings()
                        end
                    end,
                    default = false,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
                            EZOMetter_DDStats.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DD_STATS_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.ddStats.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.showBorder = value == true
                        if EZOMetter_DDStats and EZOMetter_DDStats.ApplySettings then
                            EZOMetter_DDStats.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_DAMAGE_TARGET),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_DAMAGE_TARGET_TOOLTIP),
                    min = 0,
                    max = 10000,
                    step = 100,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.damageTarget or 5000
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.damageTarget = tonumber(value) or 5000
                    end,
                    default = 5000,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_CRIT_TARGET),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_CRIT_TARGET_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.critTarget or 50
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.critTarget = tonumber(value) or 50
                    end,
                    default = 50,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_CRIT_HIGH),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_CRIT_HIGH_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.critHigh or 70
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.critHigh = tonumber(value) or 70
                    end,
                    default = 70,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_PEN_TARGET),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_PEN_TARGET_TOOLTIP),
                    min = 0,
                    max = 18200,
                    step = 100,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.penetrationTarget or 7200
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.penetrationTarget = tonumber(value) or 7200
                    end,
                    default = 7200,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_PEN_HIGH),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_PEN_HIGH_TOOLTIP),
                    min = 0,
                    max = 18200,
                    step = 100,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.penetrationHigh or 7700
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.penetrationHigh = tonumber(value) or 7700
                    end,
                    default = 7700,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_CRIT_DAMAGE_TARGET),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_CRIT_DAMAGE_TARGET_TOOLTIP),
                    min = 50,
                    max = 125,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.critDamageTarget or 125
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.critDamageTarget = tonumber(value) or 125
                    end,
                    default = 125,
                },
                CreateInfoHeader(
                    GetString(EZOM_OPTION_DD_STATS_EFFECTIVE_HEADER),
                    GetString(EZOM_OPTION_DD_STATS_EFFECTIVE_HEADER_TOOLTIP)
                ),
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_TARGET_RESISTANCE),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_TARGET_RESISTANCE_TOOLTIP),
                    min = 0,
                    max = 25000,
                    step = 100,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.targetResistance or 18200
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.targetResistance = tonumber(value) or 18200
                    end,
                    default = 18200,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_CRUSHER_VALUE),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_CRUSHER_VALUE_TOOLTIP),
                    min = 0,
                    max = 5000,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.crusherValue or 2108
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.crusherValue = tonumber(value) or 2108
                    end,
                    default = 2108,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_ALKOSH_VALUE),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_ALKOSH_VALUE_TOOLTIP),
                    min = 0,
                    max = 6000,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.alkoshValue or 6000
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.alkoshValue = tonumber(value) or 6000
                    end,
                    default = 6000,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DD_STATS_TREMORSCALE_VALUE),
                    tooltip = GetString(EZOM_OPTION_DD_STATS_TREMORSCALE_VALUE_TOOLTIP),
                    min = 0,
                    max = 5000,
                    step = 1,
                    getFunc = function()
                        return EZOMetter.sv.ddStats.tremorscaleValue or 2640
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.ddStats.tremorscaleValue = tonumber(value) or 2640
                    end,
                    default = 2640,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_DAMAGE),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_DAMAGE), GetString(EZOM_OPTION_DAMAGE_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DAMAGE_ENABLED),
                    tooltip = GetString(EZOM_OPTION_DAMAGE_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedDamage and EZOMetter.sv.observedDamage.enabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedDamage.enabled = value == true
                        if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
                            EZOMetter_ObservedDamage.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DAMAGE_DD_ONLY),
                    tooltip = GetString(EZOM_OPTION_DAMAGE_DD_ONLY_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedDamage and EZOMetter.sv.observedDamage.ddOnly ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedDamage.ddOnly = value == true
                        if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
                            EZOMetter_ObservedDamage.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DAMAGE_ONLY_COMBAT),
                    tooltip = GetString(EZOM_OPTION_DAMAGE_ONLY_COMBAT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedDamage and EZOMetter.sv.observedDamage.onlyCombat ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedDamage.onlyCombat = value == true
                        if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
                            EZOMetter_ObservedDamage.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_DAMAGE_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_DAMAGE_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.observedDamage.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedDamage.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
                            EZOMetter_ObservedDamage.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DAMAGE_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_DAMAGE_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedDamage.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedDamage.showBorder = value == true
                        if EZOMetter_ObservedDamage and EZOMetter_ObservedDamage.ApplySettings then
                            EZOMetter_ObservedDamage.ApplySettings()
                        end
                    end,
                    default = true,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_HEALING),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_HEALING), GetString(EZOM_OPTION_HEALING_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_HEALING_ENABLED),
                    tooltip = GetString(EZOM_OPTION_HEALING_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedHealing and EZOMetter.sv.observedHealing.enabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedHealing.enabled = value == true
                        if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
                            EZOMetter_ObservedHealing.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_HEALING_HEALER_ONLY),
                    tooltip = GetString(EZOM_OPTION_HEALING_HEALER_ONLY_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedHealing and EZOMetter.sv.observedHealing.healerOnly ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedHealing.healerOnly = value == true
                        if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
                            EZOMetter_ObservedHealing.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_HEALING_ONLY_COMBAT),
                    tooltip = GetString(EZOM_OPTION_HEALING_ONLY_COMBAT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedHealing and EZOMetter.sv.observedHealing.onlyCombat ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedHealing.onlyCombat = value == true
                        if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
                            EZOMetter_ObservedHealing.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_HEALING_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_HEALING_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.observedHealing.backgroundOpacity or 86
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedHealing.backgroundOpacity = tonumber(value) or 86
                        if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
                            EZOMetter_ObservedHealing.ApplySettings()
                        end
                    end,
                    default = 86,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_HEALING_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_HEALING_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.observedHealing.showBorder ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.observedHealing.showBorder = value == true
                        if EZOMetter_ObservedHealing and EZOMetter_ObservedHealing.ApplySettings then
                            EZOMetter_ObservedHealing.ApplySettings()
                        end
                    end,
                    default = true,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_ABILITIES),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_ABILITIES), GetString(EZOM_OPTION_ABILITIES_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_FATECARVER_ENABLED),
                    tooltip = GetString(EZOM_OPTION_FATECARVER_ENABLED_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.abilities and EZOMetter.sv.abilities.fatecarverEnabled == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.abilities.fatecarverEnabled = value == true
                        if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.ApplySettings then
                            EZOMetter_AbilityTracker.ApplySettings()
                        end
                    end,
                    default = true,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_FATECARVER_WARNING),
                    tooltip = GetString(EZOM_OPTION_FATECARVER_WARNING_TOOLTIP),
                    min = 0,
                    max = 3000,
                    step = 100,
                    getFunc = function()
                        return EZOMetter.sv.abilities.fatecarverWarningMs or 800
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.abilities.fatecarverWarningMs = tonumber(value) or 800
                        if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.ApplySettings then
                            EZOMetter_AbilityTracker.ApplySettings()
                        end
                    end,
                    default = 800,
                },
                {
                    type = "slider",
                    name = GetString(EZOM_OPTION_ABILITIES_BACKGROUND_OPACITY),
                    tooltip = GetString(EZOM_OPTION_ABILITIES_BACKGROUND_OPACITY_TOOLTIP),
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function()
                        return EZOMetter.sv.abilities.backgroundOpacity or 22
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.abilities.backgroundOpacity = tonumber(value) or 22
                        if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.ApplySettings then
                            EZOMetter_AbilityTracker.ApplySettings()
                        end
                    end,
                    default = 22,
                },
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_ABILITIES_SHOW_BORDER),
                    tooltip = GetString(EZOM_OPTION_ABILITIES_SHOW_BORDER_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.abilities.showBorder == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.abilities.showBorder = value == true
                        if EZOMetter_AbilityTracker and EZOMetter_AbilityTracker.ApplySettings then
                            EZOMetter_AbilityTracker.ApplySettings()
                        end
                    end,
                    default = false,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_DEBUG),
            controls = {
                CreateInfoHeader(GetString(EZOM_OPTION_DEBUG), GetString(EZOM_OPTION_DEBUG_HEADER_TOOLTIP)),
                {
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_DEBUG_MODE),
                    tooltip = GetString(EZOM_OPTION_DEBUG_MODE_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.general.debugMode == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.general.debugMode = value == true
                        if EZOMetter.Print then
                            EZOMetter.Print(GetString(value and EZOM_DEBUG_MODE_ENABLED or EZOM_DEBUG_MODE_DISABLED))
                        end
                    end,
                    default = false,
                },
            },
        },
    }

    if EZOCore and type(EZOCore.RegisterSettingsPanel) == "function" then
        local registered = EZOCore:RegisterSettingsPanel(ADDON_NAME, PANEL_ID, panelData, options)
        if registered then
            EZOMetter.ezoSettingsRegistered = true
            return
        end
    end

    EZOMetter._lamPanel = LibAddonMenu2:RegisterAddonPanel(PANEL_ID, panelData)
    LibAddonMenu2:RegisterOptionControls(PANEL_ID, options)
end

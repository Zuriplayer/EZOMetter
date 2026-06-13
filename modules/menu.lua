-- Panel LibAddonMenu.
EZOMetter_Menu = EZOMetter_Menu or {}

local ADDON_NAME = "EZOMetter"

local function RefreshLanguage()
    if EZOMetter_Lang and EZOMetter_Lang.Apply and EZOMetter.sv and EZOMetter.sv.general then
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
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Options", panelData)

    local offBalanceColorDefaults = {
        readyColor = { r = 0.9, g = 0.9, b = 0.9, a = 1 },
        activeColor = { r = 0.15, g = 1, b = 0.35, a = 1 },
        cooldownColor = { r = 1, g = 0.25, b = 0.2, a = 1 },
    }

    local function GetOffBalanceColor(key)
        local fallback = offBalanceColorDefaults[key]
        local color = EZOMetter.sv.offBalance and EZOMetter.sv.offBalance[key] or fallback
        return color.r or fallback.r, color.g or fallback.g, color.b or fallback.b, color.a or fallback.a
    end

    local function SetOffBalanceColor(key, r, g, b, a)
        EZOMetter.sv.offBalance[key] = { r = r, g = g, b = b, a = a }
        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
            EZOMetter_OffBalance.ApplySettings()
        end
    end

    local options = {
        {
            type = "description",
            title = GetString(EZOM_OPTION_STATUS),
            text = GetString(EZOM_OPTION_STATUS_TEXT),
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_GENERAL),
            controls = {
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
                        return EZOMetter.sv.general.language or EZOMetter.GetDefaultLanguage()
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.general.language = value
                        RefreshLanguage()
                    end,
                    default = EZOMetter.GetDefaultLanguage(),
                },
                {
                    type = "dropdown",
                    name = GetString(EZOM_OPTION_ROLE),
                    tooltip = GetString(EZOM_OPTION_ROLE_TOOLTIP),
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
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                    default = "dd",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_ALERTS),
            controls = {
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
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_UNLOCK_ALERT),
                    tooltip = GetString(EZOM_OPTION_UNLOCK_ALERT_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.alerts and EZOMetter.sv.alerts.unlockAlert == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.alerts.unlockAlert = value == true
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                    end,
                    default = false,
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
                {
                    type = "button",
                    name = GetString(EZOM_OPTION_TEST_ALERT),
                    tooltip = GetString(EZOM_OPTION_TEST_ALERT_TOOLTIP),
                    func = function()
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ShowTest then
                            EZOMetter_BuffAlert.ShowTest()
                        end
                    end,
                },
                {
                    type = "button",
                    name = GetString(EZOM_OPTION_RESET_ALERT_POSITION),
                    tooltip = GetString(EZOM_OPTION_RESET_ALERT_POSITION_TOOLTIP),
                    func = function()
                        EZOMetter.sv.alerts.alertX = 0
                        EZOMetter.sv.alerts.alertY = -180
                        if EZOMetter_BuffAlert and EZOMetter_BuffAlert.ApplySettings then
                            EZOMetter_BuffAlert.ApplySettings()
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_OFF_BALANCE),
            controls = {
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
                    name = GetString(EZOM_OPTION_OFF_BALANCE_DD_ONLY),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_DD_ONLY_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.ddOnly ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.ddOnly = value == true
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
                    name = GetString(EZOM_OPTION_OFF_BALANCE_BOSS_FOCUS),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_BOSS_FOCUS_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.bossFocus ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.bossFocus = value == true
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
                    type = "checkbox",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_UNLOCK),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_UNLOCK_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.unlock == true
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.unlock = value == true
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
                    name = GetString(EZOM_OPTION_OFF_BALANCE_PULSE_ON_ACTIVE),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_PULSE_ON_ACTIVE_TOOLTIP),
                    getFunc = function()
                        return EZOMetter.sv.offBalance and EZOMetter.sv.offBalance.pulseOnActive ~= false
                    end,
                    setFunc = function(value)
                        EZOMetter.sv.offBalance.pulseOnActive = value == true
                    end,
                    default = true,
                },
                {
                    type = "colorpicker",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_READY_COLOR),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_READY_COLOR_TOOLTIP),
                    getFunc = function()
                        return GetOffBalanceColor("readyColor")
                    end,
                    setFunc = function(r, g, b, a)
                        SetOffBalanceColor("readyColor", r, g, b, a)
                    end,
                    default = offBalanceColorDefaults.readyColor,
                },
                {
                    type = "colorpicker",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_ACTIVE_COLOR),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_ACTIVE_COLOR_TOOLTIP),
                    getFunc = function()
                        return GetOffBalanceColor("activeColor")
                    end,
                    setFunc = function(r, g, b, a)
                        SetOffBalanceColor("activeColor", r, g, b, a)
                    end,
                    default = offBalanceColorDefaults.activeColor,
                },
                {
                    type = "colorpicker",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_COOLDOWN_COLOR),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_COOLDOWN_COLOR_TOOLTIP),
                    getFunc = function()
                        return GetOffBalanceColor("cooldownColor")
                    end,
                    setFunc = function(r, g, b, a)
                        SetOffBalanceColor("cooldownColor", r, g, b, a)
                    end,
                    default = offBalanceColorDefaults.cooldownColor,
                },
                {
                    type = "button",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_TEST),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_TEST_TOOLTIP),
                    func = function()
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ShowTest then
                            EZOMetter_OffBalance.ShowTest()
                        end
                    end,
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
                {
                    type = "button",
                    name = GetString(EZOM_OPTION_OFF_BALANCE_RESET_POSITION),
                    tooltip = GetString(EZOM_OPTION_OFF_BALANCE_RESET_POSITION_TOOLTIP),
                    func = function()
                        EZOMetter.sv.offBalance.x = 0
                        EZOMetter.sv.offBalance.y = -80
                        if EZOMetter_OffBalance and EZOMetter_OffBalance.ApplySettings then
                            EZOMetter_OffBalance.ApplySettings()
                        end
                    end,
                },
            },
        },
        {
            type = "submenu",
            name = GetString(EZOM_OPTION_DEBUG),
            controls = {
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

    LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Options", options)
end

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

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

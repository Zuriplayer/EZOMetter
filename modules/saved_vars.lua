-- Defaults y SavedVariables centralizados.
EZOMetter.savedVars = EZOMetter.savedVars or {}

function EZOMetter.savedVars.Init()
    local world = GetWorldName()
    local defaults = {
        general = {
            language = EZOMetter.GetDefaultLanguage(),
            role = "dd",
            debugMode = false,
        },
        alerts = {
            missingBuffAlerts = true,
            unlockAlert = false,
            backgroundOpacity = 86,
            showBorder = true,
            alertX = 0,
            alertY = -180,
        },
    }

    EZOMetter.sv = ZO_SavedVars:NewCharacterIdSettings("EZOMetter_Saved", 1, world, defaults)
    EZOMetter.sv.general = EZOMetter.sv.general or defaults.general
    EZOMetter.sv.alerts = EZOMetter.sv.alerts or defaults.alerts
    EZOMetter.sv.general.language = EZOMetter.sv.general.language or defaults.general.language
    EZOMetter.sv.general.role = EZOMetter.sv.general.role or defaults.general.role
    EZOMetter.sv.general.debugMode = EZOMetter.sv.general.debugMode or defaults.general.debugMode
    if EZOMetter.sv.alerts.missingBuffAlerts == nil then
        EZOMetter.sv.alerts.missingBuffAlerts = defaults.alerts.missingBuffAlerts
    end
    EZOMetter.sv.alerts.unlockAlert = EZOMetter.sv.alerts.unlockAlert or defaults.alerts.unlockAlert
    EZOMetter.sv.alerts.backgroundOpacity = EZOMetter.sv.alerts.backgroundOpacity or defaults.alerts.backgroundOpacity
    if EZOMetter.sv.alerts.showBorder == nil then
        EZOMetter.sv.alerts.showBorder = defaults.alerts.showBorder
    end
    EZOMetter.sv.alerts.alertX = EZOMetter.sv.alerts.alertX or defaults.alerts.alertX
    EZOMetter.sv.alerts.alertY = EZOMetter.sv.alerts.alertY or defaults.alerts.alertY
end

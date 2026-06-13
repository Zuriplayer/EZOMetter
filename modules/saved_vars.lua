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
        offBalance = {
            enabled = true,
            ddOnly = true,
            onlyCombat = true,
            bossFocus = true,
            onlyBosses = false,
            unlock = false,
            backgroundOpacity = 86,
            showBorder = true,
            pulseOnActive = true,
            debugEvents = false,
            readyColor = { r = 0.9, g = 0.9, b = 0.9, a = 1 },
            activeColor = { r = 0.15, g = 1, b = 0.35, a = 1 },
            cooldownColor = { r = 1, g = 0.25, b = 0.2, a = 1 },
            x = 0,
            y = -80,
        },
    }

    EZOMetter.sv = ZO_SavedVars:NewCharacterIdSettings("EZOMetter_Saved", 1, world, defaults)
    EZOMetter.sv.general = EZOMetter.sv.general or defaults.general
    EZOMetter.sv.alerts = EZOMetter.sv.alerts or defaults.alerts
    EZOMetter.sv.offBalance = EZOMetter.sv.offBalance or defaults.offBalance
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
    if EZOMetter.sv.offBalance.enabled == nil then
        EZOMetter.sv.offBalance.enabled = defaults.offBalance.enabled
    end
    if EZOMetter.sv.offBalance.ddOnly == nil then
        EZOMetter.sv.offBalance.ddOnly = defaults.offBalance.ddOnly
    end
    if EZOMetter.sv.offBalance.onlyCombat == nil then
        EZOMetter.sv.offBalance.onlyCombat = defaults.offBalance.onlyCombat
    end
    if EZOMetter.sv.offBalance.bossFocus == nil then
        EZOMetter.sv.offBalance.bossFocus = defaults.offBalance.bossFocus
    end
    EZOMetter.sv.offBalance.onlyBosses = EZOMetter.sv.offBalance.onlyBosses or defaults.offBalance.onlyBosses
    EZOMetter.sv.offBalance.unlock = EZOMetter.sv.offBalance.unlock or defaults.offBalance.unlock
    EZOMetter.sv.offBalance.backgroundOpacity = EZOMetter.sv.offBalance.backgroundOpacity or defaults.offBalance.backgroundOpacity
    if EZOMetter.sv.offBalance.showBorder == nil then
        EZOMetter.sv.offBalance.showBorder = defaults.offBalance.showBorder
    end
    if EZOMetter.sv.offBalance.pulseOnActive == nil then
        EZOMetter.sv.offBalance.pulseOnActive = defaults.offBalance.pulseOnActive
    end
    if EZOMetter.sv.offBalance.debugEvents == nil then
        EZOMetter.sv.offBalance.debugEvents = defaults.offBalance.debugEvents
    end
    EZOMetter.sv.offBalance.readyColor = EZOMetter.sv.offBalance.readyColor or defaults.offBalance.readyColor
    EZOMetter.sv.offBalance.activeColor = EZOMetter.sv.offBalance.activeColor or defaults.offBalance.activeColor
    EZOMetter.sv.offBalance.cooldownColor = EZOMetter.sv.offBalance.cooldownColor or defaults.offBalance.cooldownColor
    EZOMetter.sv.offBalance.x = EZOMetter.sv.offBalance.x or defaults.offBalance.x
    EZOMetter.sv.offBalance.y = EZOMetter.sv.offBalance.y or defaults.offBalance.y
end

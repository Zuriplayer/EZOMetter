-- Defaults y SavedVariables centralizados.
EZOMetter.savedVars = EZOMetter.savedVars or {}

function EZOMetter.savedVars.Init()
    local world = GetWorldName()
    local defaults = {
        general = {
            language = EZOMetter.GetDefaultLanguage(),
            role = "dd",
            debugMode = false,
            unlockHud = false,
            combatReportEnabled = false,
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
        coral = {
            enabled = true,
            ddOnly = true,
            onlyCombat = true,
            unlock = false,
            backgroundOpacity = 86,
            showBorder = true,
            debugEquipment = false,
            x = 0,
            y = 40,
        },
        ddStats = {
            enabled = true,
            ddOnly = true,
            onlyCombat = false,
            unlock = false,
            backgroundOpacity = 86,
            showBorder = true,
            damageTarget = 5000,
            critTarget = 50,
            critHigh = 70,
            penetrationTarget = 7200,
            penetrationHigh = 7700,
            critDamageTarget = 125,
            critDamageHigh = 125,
            targetResistance = 18200,
            crusherValue = 2108,
            alkoshValue = 6000,
            tremorscaleValue = 2640,
            critDamageCap = 125,
            lastCombat = nil,
            x = 0,
            y = 170,
        },
        observedDamage = {
            enabled = true,
            ddOnly = true,
            onlyCombat = true,
            backgroundOpacity = 86,
            showBorder = true,
            x = 0,
            y = 315,
        },
        abilities = {
            fatecarverEnabled = true,
            fatecarverWarningMs = 800,
            backgroundOpacity = 86,
            showBorder = true,
            x = 0,
            y = 445,
        },
    }

    EZOMetter.sv = ZO_SavedVars:NewCharacterIdSettings("EZOMetter_Saved", 1, world, defaults)
    EZOMetter.sv.general = EZOMetter.sv.general or defaults.general
    EZOMetter.sv.alerts = EZOMetter.sv.alerts or defaults.alerts
    EZOMetter.sv.offBalance = EZOMetter.sv.offBalance or defaults.offBalance
    EZOMetter.sv.coral = EZOMetter.sv.coral or defaults.coral
    EZOMetter.sv.ddStats = EZOMetter.sv.ddStats or defaults.ddStats
    EZOMetter.sv.observedDamage = EZOMetter.sv.observedDamage or defaults.observedDamage
    EZOMetter.sv.abilities = EZOMetter.sv.abilities or defaults.abilities
    EZOMetter.sv.general.language = EZOMetter.sv.general.language or defaults.general.language
    EZOMetter.sv.general.role = EZOMetter.sv.general.role or defaults.general.role
    EZOMetter.sv.general.debugMode = EZOMetter.sv.general.debugMode or defaults.general.debugMode
    EZOMetter.sv.general.unlockHud = EZOMetter.sv.general.unlockHud or defaults.general.unlockHud
    if EZOMetter.sv.general.combatReportEnabled == nil then
        EZOMetter.sv.general.combatReportEnabled = defaults.general.combatReportEnabled
    end
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
    if EZOMetter.sv.coral.enabled == nil then
        EZOMetter.sv.coral.enabled = defaults.coral.enabled
    end
    if EZOMetter.sv.coral.ddOnly == nil then
        EZOMetter.sv.coral.ddOnly = defaults.coral.ddOnly
    end
    if EZOMetter.sv.coral.onlyCombat == nil then
        EZOMetter.sv.coral.onlyCombat = defaults.coral.onlyCombat
    end
    EZOMetter.sv.coral.unlock = EZOMetter.sv.coral.unlock or defaults.coral.unlock
    EZOMetter.sv.coral.backgroundOpacity = EZOMetter.sv.coral.backgroundOpacity or defaults.coral.backgroundOpacity
    if EZOMetter.sv.coral.showBorder == nil then
        EZOMetter.sv.coral.showBorder = defaults.coral.showBorder
    end
    if EZOMetter.sv.coral.debugEquipment == nil then
        EZOMetter.sv.coral.debugEquipment = defaults.coral.debugEquipment
    end
    EZOMetter.sv.coral.x = EZOMetter.sv.coral.x or defaults.coral.x
    EZOMetter.sv.coral.y = EZOMetter.sv.coral.y or defaults.coral.y
    if EZOMetter.sv.ddStats.enabled == nil then
        EZOMetter.sv.ddStats.enabled = defaults.ddStats.enabled
    end
    if EZOMetter.sv.ddStats.ddOnly == nil then
        EZOMetter.sv.ddStats.ddOnly = defaults.ddStats.ddOnly
    end
    if EZOMetter.sv.ddStats.onlyCombat == nil then
        EZOMetter.sv.ddStats.onlyCombat = defaults.ddStats.onlyCombat
    end
    EZOMetter.sv.ddStats.unlock = EZOMetter.sv.ddStats.unlock or defaults.ddStats.unlock
    EZOMetter.sv.ddStats.backgroundOpacity = EZOMetter.sv.ddStats.backgroundOpacity or defaults.ddStats.backgroundOpacity
    if EZOMetter.sv.ddStats.showBorder == nil then
        EZOMetter.sv.ddStats.showBorder = defaults.ddStats.showBorder
    end
    EZOMetter.sv.ddStats.damageTarget = EZOMetter.sv.ddStats.damageTarget or defaults.ddStats.damageTarget
    EZOMetter.sv.ddStats.critTarget = EZOMetter.sv.ddStats.critTarget or defaults.ddStats.critTarget
    EZOMetter.sv.ddStats.critHigh = EZOMetter.sv.ddStats.critHigh or defaults.ddStats.critHigh
    EZOMetter.sv.ddStats.penetrationTarget = EZOMetter.sv.ddStats.penetrationTarget or defaults.ddStats.penetrationTarget
    EZOMetter.sv.ddStats.penetrationHigh = EZOMetter.sv.ddStats.penetrationHigh or defaults.ddStats.penetrationHigh
    EZOMetter.sv.ddStats.critDamageTarget = EZOMetter.sv.ddStats.critDamageTarget or defaults.ddStats.critDamageTarget
    EZOMetter.sv.ddStats.critDamageHigh = EZOMetter.sv.ddStats.critDamageHigh or defaults.ddStats.critDamageHigh
    EZOMetter.sv.ddStats.targetResistance = EZOMetter.sv.ddStats.targetResistance or defaults.ddStats.targetResistance
    EZOMetter.sv.ddStats.crusherValue = EZOMetter.sv.ddStats.crusherValue or defaults.ddStats.crusherValue
    EZOMetter.sv.ddStats.alkoshValue = EZOMetter.sv.ddStats.alkoshValue or defaults.ddStats.alkoshValue
    EZOMetter.sv.ddStats.tremorscaleValue = EZOMetter.sv.ddStats.tremorscaleValue or defaults.ddStats.tremorscaleValue
    EZOMetter.sv.ddStats.critDamageCap = EZOMetter.sv.ddStats.critDamageCap or defaults.ddStats.critDamageCap
    EZOMetter.sv.ddStats.x = EZOMetter.sv.ddStats.x or defaults.ddStats.x
    EZOMetter.sv.ddStats.y = EZOMetter.sv.ddStats.y or defaults.ddStats.y
    if EZOMetter.sv.observedDamage.enabled == nil then
        EZOMetter.sv.observedDamage.enabled = defaults.observedDamage.enabled
    end
    if EZOMetter.sv.observedDamage.ddOnly == nil then
        EZOMetter.sv.observedDamage.ddOnly = defaults.observedDamage.ddOnly
    end
    if EZOMetter.sv.observedDamage.onlyCombat == nil then
        EZOMetter.sv.observedDamage.onlyCombat = defaults.observedDamage.onlyCombat
    end
    EZOMetter.sv.observedDamage.backgroundOpacity = EZOMetter.sv.observedDamage.backgroundOpacity or defaults.observedDamage.backgroundOpacity
    if EZOMetter.sv.observedDamage.showBorder == nil then
        EZOMetter.sv.observedDamage.showBorder = defaults.observedDamage.showBorder
    end
    EZOMetter.sv.observedDamage.x = EZOMetter.sv.observedDamage.x or defaults.observedDamage.x
    EZOMetter.sv.observedDamage.y = EZOMetter.sv.observedDamage.y or defaults.observedDamage.y
    if EZOMetter.sv.abilities.fatecarverEnabled == nil then
        EZOMetter.sv.abilities.fatecarverEnabled = defaults.abilities.fatecarverEnabled
    end
    EZOMetter.sv.abilities.fatecarverWarningMs = EZOMetter.sv.abilities.fatecarverWarningMs or defaults.abilities.fatecarverWarningMs
    EZOMetter.sv.abilities.backgroundOpacity = EZOMetter.sv.abilities.backgroundOpacity or defaults.abilities.backgroundOpacity
    if EZOMetter.sv.abilities.showBorder == nil then
        EZOMetter.sv.abilities.showBorder = defaults.abilities.showBorder
    end
    EZOMetter.sv.abilities.x = EZOMetter.sv.abilities.x or defaults.abilities.x
    EZOMetter.sv.abilities.y = EZOMetter.sv.abilities.y or defaults.abilities.y
end

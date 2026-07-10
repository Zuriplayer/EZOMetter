-- Aviso movible para buffs requeridos que no estan activos en el jugador.
EZOMetter_BuffAlert = EZOMetter_BuffAlert or {}

local BuffAlert = EZOMetter_BuffAlert
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterMissingBuffAlert"
local ROW_HEIGHT = 32
local ROW_GAP = 4
local WIDTH = 280
local COMBAT_SAMPLE_INTERVAL_MS = 250
local IDLE_SCAN_INTERVAL_MS = 1000
local SUMMARY_TOLERANCE_MS = 250

local activeEffects = {}
local lastMissing = {}
local lastIconByKey = {}
local rows = {}
local control
local backdrop
local testPreviewActive = false
local testPreviewToken = 0
local isCombat = false
local statsUpdateRegistered = false
local idleUpdateRegistered = false
local statsTracker
local lastCombatSummary
local ScanPlayerBuffs
local ScanPlayerBuffsOnly

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.alerts = EZOMetter.sv.alerts or {}
    return EZOMetter.sv.alerts
end

local function GetRole()
    return EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.role or "dd"
end

local function IsEnabled()
    local settings = GetSettings()
    if not settings or settings.missingBuffAlerts ~= true then return false end
    local required = EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}
    return #required > 0
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

local function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function GetEffectName(effect)
    local stringId = effect and effect.nameString and _G[effect.nameString]
    if stringId then
        return GetString(stringId)
    end
    return tostring(effect and effect.key or "")
end

local function GetEffectIcon(effect)
    if not effect then return "" end
    if lastIconByKey[effect.key] then
        return lastIconByKey[effect.key]
    end

    local abilityId = EZOMetter.Effects and EZOMetter.Effects.GetPrimaryAbilityId(effect) or nil
    if abilityId and type(GetAbilityIcon) == "function" then
        return GetAbilityIcon(abilityId)
    end

    return ""
end

local function GetSummaryEffects()
    local effects = {}
    if not lastCombatSummary or not lastCombatSummary.hasIssues then
        return effects
    end

    local required = EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}
    for _, effect in ipairs(required) do
        if lastCombatSummary.byKey and lastCombatSummary.byKey[effect.key] then
            table.insert(effects, effect)
        end
    end

    return effects
end

local function BuildTooltipText()
    if not lastCombatSummary or not lastCombatSummary.rows then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        GetString(EZOM_LAST_COMBAT_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. EZOMetter_CombatSummary.FormatSeconds(lastCombatSummary.durationMs) .. "s",
    }

    if not lastCombatSummary.hasIssues then
        table.insert(lines, GetString(EZOM_LAST_COMBAT_ALL_OK))
        return table.concat(lines, "\n")
    end

    for _, row in ipairs(lastCombatSummary.rows) do
        table.insert(lines, string.format(
            "%s: %s | %ss | %s %d",
            row.name,
            EZOMetter_CombatSummary.FormatPercent(row.uptime),
            EZOMetter_CombatSummary.FormatSeconds(row.missingMs),
            GetString(EZOM_SUMMARY_DROPS),
            row.drops
        ))
    end

    return table.concat(lines, "\n")
end

function BuffAlert.GetReportSection()
    if not lastCombatSummary or not lastCombatSummary.rows then return nil end
    return BuildTooltipText()
end

local function ShowTooltip()
    if EZOMetter_CombatSummary then
        EZOMetter_CombatSummary.ShowTooltip(control, BuildTooltipText())
    end
end

local function HideTooltip()
    if EZOMetter_CombatSummary then
        EZOMetter_CombatSummary.HideTooltip()
    end
end

local function SavePosition()
    local settings = GetSettings()
    if not settings or not control then return end

    settings.alertX = control:GetLeft() - GuiRoot:GetWidth() / 2 + control:GetWidth() / 2
    settings.alertY = control:GetTop() - GuiRoot:GetHeight() / 2 + control:GetHeight() / 2
end

local function ApplyPosition()
    if not control then return end

    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.alertX) or 0, tonumber(settings.alertY) or -180)
end

local function SetMoveMode(enabled)
    if not control then return end

    control:SetMouseEnabled(true)
    control:SetMovable(enabled == true)
end

local function ApplyStyle()
    if not backdrop then return end

    local settings = GetSettings() or {}
    local opacity = tonumber(settings.backgroundOpacity) or 86
    if opacity < 0 then opacity = 0 end
    if opacity > 100 then opacity = 100 end

    backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.75, 0.25, 0.95, 0.95)
    end
end

local function CreateRow(index)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl(CONTROL_NAME .. "Row" .. index, control, CT_CONTROL)
    row:SetDimensions(WIDTH - 20, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 10 + (index - 1) * (ROW_HEIGHT + ROW_GAP))

    row.icon = wm:CreateControl(CONTROL_NAME .. "Row" .. index .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(28, 28)
    row.icon:SetAnchor(LEFT, row, LEFT, 0, 0)

    row.label = wm:CreateControl(CONTROL_NAME .. "Row" .. index .. "Label", row, CT_LABEL)
    row.label:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)
    row.label:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    row.label:SetFont("ZoFontGameMedium")
    row.label:SetColor(1, 0.92, 0.78, 1)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    rows[index] = row
    return row
end

local function EnsureControl()
    if control then return control end

    local wm = WINDOW_MANAGER
    control = wm:CreateTopLevelWindow(CONTROL_NAME)
    control:SetDimensions(WIDTH, 48)
    control:SetClampedToScreen(true)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    control:SetHandler("OnMoveStop", SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    ApplyStyle()

    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function HideAlert()
    if control and (not CanShowHud() or not IsHudUnlocked()) then
        control:SetHidden(true)
    end
end

local function ShowEffects(effects)
    EnsureControl()

    if not CanShowHud() then
        control:SetHidden(true)
        return
    end

    local count = #effects
    if count == 0 then
        HideAlert()
        return
    end

    control:SetDimensions(WIDTH, 20 + count * ROW_HEIGHT + (count - 1) * ROW_GAP)

    for index, effect in ipairs(effects) do
        local row = rows[index] or CreateRow(index)
        row.icon:SetTexture(GetEffectIcon(effect))
        row.label:SetText(GetEffectName(effect))
        row:SetHidden(false)
    end

    for index = count + 1, #rows do
        rows[index]:SetHidden(true)
    end

    control:SetHidden(false)
end

local function EffectIsActive(effect)
    return effect and activeEffects[effect.key] == true
end

local function EffectMatchesBuff(effect, abilityId, effectName, castByPlayer)
    if not EZOMetter.Effects or not effect then return false end
    if EZOMetter.Effects.MatchesBuff then
        return EZOMetter.Effects.MatchesBuff(effect, abilityId, effectName, castByPlayer)
    end
    return EZOMetter.Effects.Matches(effect, abilityId, effectName)
end

local function EffectMatchesBuffEvent(effect, abilityId, effectName)
    if not EZOMetter.Effects or not effect then return false end
    if EZOMetter.Effects.MatchesBuffAbility then
        return EZOMetter.Effects.MatchesBuffAbility(effect, abilityId, effectName)
    end
    return EZOMetter.Effects.Matches(effect, abilityId, effectName)
end

local function GetMissingEffects()
    local missing = {}
    local required = EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}

    for _, effect in ipairs(required) do
        if EZOMetter.Effects.ShouldRequire(effect) and not EffectIsActive(effect) then
            table.insert(missing, effect)
        end
    end

    return missing
end

local function GetPreviewEffects()
    return EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}
end

local function ShouldShowPreview()
    return testPreviewActive == true or IsHudUnlocked()
end

local function ShowPreview()
    ShowEffects(GetPreviewEffects())
end

local function MissingChanged(missing)
    local current = {}
    for _, effect in ipairs(missing) do
        current[effect.key] = true
    end

    for key in pairs(current) do
        if lastMissing[key] ~= true then
            lastMissing = current
            return true
        end
    end

    for key in pairs(lastMissing) do
        if current[key] ~= true then
            lastMissing = current
            return false
        end
    end

    lastMissing = current
    return false
end

local function Refresh()
    if ShouldShowPreview() then
        activeEffects = {}
        lastMissing = {}
        ShowPreview()
        return
    end

    if not IsEnabled() then
        activeEffects = {}
        lastMissing = {}
        if control then control:SetHidden(true) end
        return
    end

    local missing = GetMissingEffects()
    MissingChanged(missing)
    ShowEffects(missing)
end

local function RegisterStatsUpdate()
    if statsUpdateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_BuffAlertStats", COMBAT_SAMPLE_INTERVAL_MS, function()
        if ScanPlayerBuffsOnly then
            ScanPlayerBuffsOnly()
        end
        if statsTracker then
            statsTracker:Sample(EZOMetter_CombatSummary.GetNowMs())
        end
        Refresh()
    end)
    statsUpdateRegistered = true
end

local function UnregisterStatsUpdate()
    if not statsUpdateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_BuffAlertStats")
    statsUpdateRegistered = false
end

local function RegisterIdleUpdate()
    if idleUpdateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_BuffAlertIdle", IDLE_SCAN_INTERVAL_MS, function()
        if isCombat or not IsEnabled() then return end
        if ScanPlayerBuffsOnly then
            ScanPlayerBuffsOnly()
        end
        Refresh()
    end)
    idleUpdateRegistered = true
end

local function UnregisterIdleUpdate()
    if not idleUpdateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_BuffAlertIdle")
    idleUpdateRegistered = false
end

local function OnCombatState(_, inCombat)
    local nowInCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    if nowInCombat == isCombat then return end

    isCombat = nowInCombat
    if isCombat then
        UnregisterIdleUpdate()
        ScanPlayerBuffs()
        if statsTracker then
            statsTracker:Start(EZOMetter_CombatSummary.GetNowMs())
            lastCombatSummary = nil
        end
        RegisterStatsUpdate()
    else
        if statsTracker then
            lastCombatSummary = statsTracker:Finish(EZOMetter_CombatSummary.GetNowMs())
        end
        UnregisterStatsUpdate()
        RegisterIdleUpdate()
        ScanPlayerBuffs()
        Refresh()
    end
end

function ScanPlayerBuffsOnly()
    activeEffects = {}

    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return
    end

    local buffCount = GetNumBuffs("player") or 0
    for index = 1, buffCount do
        local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player", index)
        if EZOMetter.Effects then
            for _, effect in ipairs(EZOMetter.Effects.GetRequiredForRole(GetRole())) do
                if EffectMatchesBuff(effect, abilityId, buffName, castByPlayer) then
                    activeEffects[effect.key] = true
                    if iconFilename then
                        lastIconByKey[effect.key] = iconFilename
                    end
                end
            end
        end
    end
end

function ScanPlayerBuffs()
    ScanPlayerBuffsOnly()
    Refresh()
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, _, _, iconName, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" then return end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if EZOMetter.Effects then
            for _, effect in ipairs(EZOMetter.Effects.GetRequiredForRole(GetRole())) do
                if EffectMatchesBuffEvent(effect, abilityId, effectName) then
                    if effect.requiresCastByPlayer == true then
                        ScanPlayerBuffs()
                        return
                    end
                    activeEffects[effect.key] = true
                    if iconName then
                        lastIconByKey[effect.key] = iconName
                    end
                end
            end
        end
        Refresh()
    elseif changeType == EFFECT_RESULT_FADED then
        ScanPlayerBuffs()
    end
end

function BuffAlert.Refresh()
    ScanPlayerBuffs()
end

function BuffAlert.ShowTest()
    testPreviewActive = true
    testPreviewToken = testPreviewToken + 1
    local token = testPreviewToken

    if CanShowHud() then
        ShowPreview()
    end

    zo_callLater(function()
        if token ~= testPreviewToken then return end
        testPreviewActive = false
        ScanPlayerBuffs()
    end, 5000)
end

function BuffAlert.ApplySettings()
    EnsureControl()
    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    if isCombat or not IsEnabled() then
        UnregisterIdleUpdate()
    else
        RegisterIdleUpdate()
    end
    ScanPlayerBuffs()
end

local function OnPlayerStateRefresh()
    zo_callLater(function()
        if not isCombat and IsEnabled() then
            RegisterIdleUpdate()
        end
        ScanPlayerBuffs()
    end, 250)
end

function BuffAlert.Init()
    EnsureControl()
    if EZOMetter_CombatSummary then
        statsTracker = EZOMetter_CombatSummary.CreateUptimeTracker({
            toleranceMs = SUMMARY_TOLERANCE_MS,
            getItems = function()
                return EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}
            end,
            getItemKey = function(effect)
                return effect.key
            end,
            getItemName = GetEffectName,
            isItemRequired = function(effect)
                return EZOMetter.Effects and EZOMetter.Effects.ShouldRequire(effect)
            end,
            isItemActive = EffectIsActive,
        })
    end

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(BuffAlert.Refresh)
    end

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_PlayerBuffs",
        EVENT_EFFECT_CHANGED,
        OnEffectChanged
    )
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_PlayerBuffs", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ActionSlotsAll", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, ScanPlayerBuffs)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ActionSlotUpdated", EVENT_ACTION_SLOT_UPDATED, ScanPlayerBuffs)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BuffAlertActivated", EVENT_PLAYER_ACTIVATED, OnPlayerStateRefresh)
    if EVENT_PLAYER_ALIVE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BuffAlertAlive", EVENT_PLAYER_ALIVE, OnPlayerStateRefresh)
    end
    if EVENT_PLAYER_DEAD then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BuffAlertDead", EVENT_PLAYER_DEAD, OnPlayerStateRefresh)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BuffAlertWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ScanPlayerBuffs)
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BuffAlertCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)

    zo_callLater(function()
        ScanPlayerBuffs()
        OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
        if not isCombat and IsEnabled() then
            RegisterIdleUpdate()
        end
    end, 2000)
end

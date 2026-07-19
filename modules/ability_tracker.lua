-- Trackers visuales para habilidades concretas.
EZOMetter_AbilityTracker = EZOMetter_AbilityTracker or {}

local Tracker = EZOMetter_AbilityTracker
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterAbilityTracker"
local UPDATE_INTERVAL_MS = 33
local WIDTH = 260
local HEIGHT = 38
local PADDING = 4
local BAR_HEIGHT = 30
local BAR_INSET = 2
local BAR_INNER_WIDTH = WIDTH - (PADDING * 2) - (BAR_INSET * 2)
local PRE_WARNING_MS = 350
local ICON_SIZE = 42
local TEXT_GAP = 10
local DEFAULT_BACKGROUND_OPACITY = 22
local CHANNEL_EFFECT_GRACE_MS = 250
local INACTIVE_BACKGROUND_ALPHA = 0.03
local INACTIVE_MOVE_BACKGROUND_ALPHA = 0.10
local BAR_IDLE_ALPHA = 0.06
local BAR_ACTIVE_ALPHA = 0.24
local BAR_WARNING_ALPHA = 0.30
local BAR_READY_ALPHA = 0.24

local FATECARVER_IDS = {
    [185805] = true,
    [193331] = true,
    [183122] = true,
    [193397] = true,
    [186366] = true,
    [193398] = true,
}

local FATECARVER_NAMES = {
    "Fatecarver",
    "Exhausting Fatecarver",
    "Pragmatic Fatecarver",
}

local RESULT_BEGIN = ACTION_RESULT_BEGIN or 2200
local RESULT_EFFECT_FADED = ACTION_RESULT_EFFECT_FADED or 2250
local RESULT_INTERRUPT = ACTION_RESULT_INTERRUPT or 2230
local RESULT_BEGIN_CHANNEL = ACTION_RESULT_BEGIN_CHANNEL or -10001
local RESULT_KNOCKBACK = ACTION_RESULT_KNOCKBACK or -10002
local RESULT_PACIFIED = ACTION_RESULT_PACIFIED or -10003
local RESULT_STAGGERED = ACTION_RESULT_STAGGERED or -10004
local RESULT_STUNNED = ACTION_RESULT_STUNNED or -10005
local RESULT_FEARED = ACTION_RESULT_FEARED or -10006
local RESULT_LEVITATED = ACTION_RESULT_LEVITATED or -10007
local localizedFatecarverNames

local control
local backdrop
local icon
local titleLabel
local timerLabel
local stateLabel
local barBack
local barFill
local updateRegistered = false
local activeWatcherRegistered = false
local activeWatcherEventNames = {}
local active = false
local activeEffectSeen = false
local activeAbilityId = 0
local activeName = ""
local startMs = 0
local durationMs = 0
local remainingMs = 0
local hasFatecarverSlotted = false
local slottedFatecarverIcon = "esoui/art/icons/ability_arcanist_002.dds"
local isCombat = false
local currentCombatStats
local lastCombatSummary
local IsHudUnlocked
local UpdateVisuals
local FinishActiveChannel
local OnActiveCombatEvent
local OnPlayerEffectChanged
local lastProgressWidth = -1
local lastTimerText
local lastTitleText
local lastStateText
local lastVisualMode

local ACTIVE_TARGET_CANCEL_RESULTS = {
    [RESULT_INTERRUPT] = true,
    [RESULT_KNOCKBACK] = true,
    [RESULT_PACIFIED] = true,
    [RESULT_STAGGERED] = true,
    [RESULT_STUNNED] = true,
    [RESULT_FEARED] = true,
    [RESULT_LEVITATED] = true,
}

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.abilities = EZOMetter.sv.abilities or {}
    return EZOMetter.sv.abilities
end

local function GetNowMs()
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetGameTimeSeconds) == "function" then
        return GetGameTimeSeconds() * 1000
    end
    return 0
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function NormalizeName(name)
    name = tostring(name or "")
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function IsPlayerCombatName(name)
    local normalized = NormalizeName(name)
    if normalized == "" then return false end

    if type(GetRawUnitName) == "function" and normalized == NormalizeName(GetRawUnitName("player")) then
        return true
    end
    if type(GetUnitName) == "function" and normalized == NormalizeName(GetUnitName("player")) then
        return true
    end
    if type(GetUnitDisplayName) == "function" and normalized == NormalizeName(GetUnitDisplayName("player")) then
        return true
    end

    return false
end

local function IsPlayerCombatTarget(targetName, targetType)
    if COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER then
        return true
    end
    return IsPlayerCombatName(targetName)
end

local function IsPlayerCombatSource(sourceName, sourceType)
    if COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return true
    end
    return IsPlayerCombatName(sourceName)
end

local function IsFatecarverName(name)
    local normalized = NormalizeName(name)
    if normalized == "" then return false end

    for _, fatecarverName in ipairs(FATECARVER_NAMES) do
        if string.find(normalized, NormalizeName(fatecarverName), 1, true) then
            return true
        end
    end

    if not localizedFatecarverNames then
        localizedFatecarverNames = {}
        if type(GetAbilityName) == "function" then
            for abilityId in pairs(FATECARVER_IDS) do
                local abilityName = GetAbilityName(abilityId)
                local normalizedAbilityName = NormalizeName(abilityName)
                if normalizedAbilityName ~= "" then
                    localizedFatecarverNames[normalizedAbilityName] = true
                end
            end
        end
    end

    if localizedFatecarverNames[normalized] == true then
        return true
    end

    for localizedName in pairs(localizedFatecarverNames) do
        if string.find(normalized, localizedName, 1, true) or string.find(localizedName, normalized, 1, true) then
            return true
        end
    end

    return false
end

local function IsFatecarverAbility(abilityId, abilityName)
    abilityId = tonumber(abilityId) or 0
    if FATECARVER_IDS[abilityId] == true then
        return true
    end
    if IsFatecarverName(abilityName) then
        return true
    end
    if abilityId > 0 and type(GetAbilityName) == "function" then
        return IsFatecarverName(GetAbilityName(abilityId))
    end
    return false
end

local function ScanActiveFatecarverEffect(nowMs)
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return false, 0
    end

    local buffCount = GetNumBuffs("player") or 0
    for index = 1, buffCount do
        local buffName, _, endTime, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)
        if IsFatecarverAbility(abilityId, buffName) then
            local endMs = (tonumber(endTime) or 0) * 1000
            if endMs <= 0 or endMs > (nowMs or GetNowMs()) then
                if iconFilename and iconFilename ~= "" then
                    slottedFatecarverIcon = iconFilename
                    if icon then icon:SetTexture(iconFilename) end
                end
                return true, endMs
            end
        end
    end

    return false, 0
end

local function RefreshActiveEffectFromBuffs(nowMs)
    local found, endMs = ScanActiveFatecarverEffect(nowMs)
    if found then
        activeEffectSeen = true
        if active and endMs and endMs > 0 and startMs > 0 then
            durationMs = math.max(durationMs or 0, endMs - startMs)
            remainingMs = math.max(0, endMs - (nowMs or GetNowMs()))
        end
    end
    return found
end

local function GetSlotAbilityId(slotIndex, hotbarCategory)
    if type(GetSlotBoundId) ~= "function" or type(GetSlotType) ~= "function" then
        return nil
    end

    local actionType = GetSlotType(slotIndex, hotbarCategory)
    local boundId = GetSlotBoundId(slotIndex, hotbarCategory)
    if not boundId or boundId == 0 then
        return nil
    end
    if ACTION_TYPE_CRAFTED_ABILITY ~= nil
        and actionType == ACTION_TYPE_CRAFTED_ABILITY
        and type(GetAbilityIdForCraftedAbilityId) == "function"
    then
        return GetAbilityIdForCraftedAbilityId(boundId), boundId
    end
    return boundId, nil
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.fatecarverEnabled == true
end

local function GetWarningMs()
    local settings = GetSettings() or {}
    local warningMs = tonumber(settings.fatecarverWarningMs) or 800
    if warningMs < 0 then warningMs = 0 end
    if warningMs > 3000 then warningMs = 3000 end
    return warningMs
end

local function FormatSeconds(ms)
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.FormatSeconds then
        return EZOMetter_CombatSummary.FormatSeconds(ms)
    end
    return string.format("%.1f", math.max(0, tonumber(ms) or 0) / 1000)
end

local function FormatPercent(value)
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.FormatPercent then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

local function SetLabelText(label, text, cacheName)
    text = tostring(text or "")
    if cacheName == "title" then
        if text == lastTitleText then return end
        lastTitleText = text
    elseif cacheName == "state" then
        if text == lastStateText then return end
        lastStateText = text
    else
        if text == lastTimerText then return end
        lastTimerText = text
    end
    label:SetText(text)
end

local function NewCombatStats(nowMs)
    return {
        startMs = nowMs,
        durationMs = 0,
        total = 0,
        completed = 0,
        safeCancelled = 0,
        earlyStopped = 0,
        earlyMsTotal = 0,
        worstEarlyMs = 0,
    }
end

local function EnsureCombatStats(nowMs)
    if not isCombat and type(IsUnitInCombat) == "function" then
        isCombat = IsUnitInCombat("player") == true
    end
    if not isCombat then return nil end

    if not currentCombatStats then
        currentCombatStats = NewCombatStats(nowMs or GetNowMs())
    end
    return currentCombatStats
end

local function BuildCombatSummary(stats, nowMs)
    if not stats then return nil end

    local durationMs = math.max(0, (nowMs or GetNowMs()) - (stats.startMs or 0))
    local successful = (stats.completed or 0) + (stats.safeCancelled or 0)
    local total = stats.total or 0
    local successRate = total > 0 and (successful / total) * 100 or 0
    local earlyAverageMs = stats.earlyStopped > 0 and stats.earlyMsTotal / stats.earlyStopped or 0

    return {
        durationMs = durationMs,
        hasData = total > 0,
        total = total,
        completed = stats.completed or 0,
        safeCancelled = stats.safeCancelled or 0,
        earlyStopped = stats.earlyStopped or 0,
        successful = successful,
        successRate = successRate,
        earlyAverageMs = earlyAverageMs,
        worstEarlyMs = stats.worstEarlyMs or 0,
    }
end

local function BuildTooltipText()
    local summary = isCombat and currentCombatStats and BuildCombatSummary(currentCombatStats, GetNowMs()) or lastCombatSummary
    if not summary or not summary.hasData then
        return GetString(EZOM_ABILITY_FATECARVER_SUMMARY_TITLE) .. "\n" .. GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(summary.durationMs) .. "s",
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_CASTS) .. ": " .. tostring(summary.total),
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_OK) .. ": " .. FormatPercent(summary.successRate),
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_COMPLETED) .. ": " .. tostring(summary.completed),
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_SAFE) .. ": " .. tostring(summary.safeCancelled),
        GetString(EZOM_ABILITY_FATECARVER_SUMMARY_EARLY) .. ": " .. tostring(summary.earlyStopped),
    }

    if summary.earlyStopped > 0 then
        table.insert(lines, GetString(EZOM_ABILITY_FATECARVER_SUMMARY_EARLY_AVG) .. ": " .. tostring(math.floor(summary.earlyAverageMs + 0.5)) .. " ms")
        table.insert(lines, GetString(EZOM_ABILITY_FATECARVER_SUMMARY_EARLY_WORST) .. ": " .. tostring(math.floor(summary.worstEarlyMs + 0.5)) .. " ms")
    end

    return table.concat(lines, "\n")
end

function Tracker.GetReportSection()
    if not lastCombatSummary or not lastCombatSummary.hasData then return nil end
    return BuildTooltipText()
end

local function ShowTooltip()
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.ShowTooltip then
        EZOMetter_CombatSummary.ShowTooltip(control, BuildTooltipText())
    end
end

local function HideTooltip()
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.HideTooltip then
        EZOMetter_CombatSummary.HideTooltip()
    end
end

local function SavePosition()
    local settings = GetSettings()
    if not settings or not control then return end

    settings.x = control:GetLeft() - GuiRoot:GetWidth() / 2 + control:GetWidth() / 2
    settings.y = control:GetTop() - GuiRoot:GetHeight() / 2 + control:GetHeight() / 2
end

local function ApplyPosition()
    if not control then return end

    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 445)
end

local function SetMoveMode(enabled)
    if not control then return end
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
end

local function ApplyStyle(activeStyle)
    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control)
    end
    if not backdrop then return end

    local settings = GetSettings() or {}
    local opacity = tonumber(settings.backgroundOpacity) or DEFAULT_BACKGROUND_OPACITY
    if opacity < 0 then opacity = 0 end
    if opacity > 100 then opacity = 100 end

    if activeStyle ~= true then
        local idleAlpha = IsHudUnlocked() and INACTIVE_MOVE_BACKGROUND_ALPHA or INACTIVE_BACKGROUND_ALPHA
        if EZOMetter_WindowStyle and EZOMetter_WindowStyle.ApplyBackdropStyle then
            EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop, {
                opacityMultiplier = idleAlpha,
                hideBorder = true,
            })
        else
            backdrop:SetCenterColor(0.03, 0.03, 0.03, idleAlpha)
            backdrop:SetEdgeColor(0, 0, 0, 0)
        end
        return
    end

    if EZOMetter_WindowStyle and EZOMetter_WindowStyle.ApplyBackdropStyle then
        EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
        return
    end

    backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.2, 0.9, 0.75, 0.95)
    end
end

local function SetVisualMode(mode)
    if lastVisualMode == mode then return end
    lastVisualMode = mode

    if mode == "idle" then
        ApplyStyle(false)
        timerLabel:SetColor(0.7, 0.75, 0.82, 0.78)
        stateLabel:SetColor(0.7, 0.75, 0.82, 1)
        barBack:SetCenterColor(0, 0, 0, BAR_IDLE_ALPHA)
        barBack:SetEdgeColor(0, 0, 0, 0)
        barFill:SetColor(0.35, 0.35, 0.35, IsHudUnlocked() and 0.35 or 0.12)
    elseif mode == "ready" then
        ApplyStyle(true)
        stateLabel:SetColor(0.25, 1, 0.35, 1)
        timerLabel:SetColor(0.25, 1, 0.35, 1)
        barBack:SetCenterColor(0.02, 0.18, 0.04, BAR_READY_ALPHA)
        barBack:SetEdgeColor(0, 0, 0, 0)
        barFill:SetColor(0.15, 1, 0.2, 1)
    elseif mode == "warning" then
        ApplyStyle(true)
        stateLabel:SetColor(1, 0.78, 0.25, 1)
        timerLabel:SetColor(1, 0.78, 0.25, 1)
        barBack:SetCenterColor(0.18, 0.12, 0.02, BAR_WARNING_ALPHA)
        barBack:SetEdgeColor(0, 0, 0, 0)
        barFill:SetColor(1, 0.55, 0.05, 1)
    else
        ApplyStyle(true)
        stateLabel:SetColor(1, 0.78, 0.25, 1)
        timerLabel:SetColor(1, 0.78, 0.25, 1)
        barBack:SetCenterColor(0, 0, 0, BAR_ACTIVE_ALPHA)
        barBack:SetEdgeColor(0, 0, 0, 0)
        barFill:SetColor(0, 0.85, 1, 1)
    end
end

local function EnsureControl()
    if control then return control end

    local wm = WINDOW_MANAGER
    control = wm:CreateTopLevelWindow(CONTROL_NAME)
    control:SetDimensions(WIDTH, HEIGHT)
    control:SetClampedToScreen(true)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    EZOMetter_VisualContext.BindPrimaryDrag(control, function()
        return control.ezomMoveEnabled == true
    end, SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("", 1, 1, 1)
    backdrop:SetDrawLevel(0)
    ApplyStyle()

    icon = wm:CreateControl(CONTROL_NAME .. "Icon", control, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 12)
    icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(slottedFatecarverIcon)
    icon:SetHidden(true)

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, TEXT_GAP, 9)
    titleLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -58, 9)
    titleLabel:SetHeight(24)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    titleLabel:SetMaxLineCount(1)
    titleLabel:SetHidden(true)

    stateLabel = wm:CreateControl(CONTROL_NAME .. "State", control, CT_LABEL)
    stateLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, TEXT_GAP, 34)
    stateLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 34)
    stateLabel:SetHeight(18)
    stateLabel:SetFont("ZoFontGameSmall")
    stateLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    stateLabel:SetMaxLineCount(1)
    stateLabel:SetHidden(true)

    barBack = wm:CreateControl(CONTROL_NAME .. "BarBack", control, CT_BACKDROP)
    barBack:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, PADDING, -PADDING)
    barBack:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -PADDING, -PADDING)
    barBack:SetHeight(BAR_HEIGHT)
    barBack:SetCenterColor(0, 0, 0, BAR_IDLE_ALPHA)
    barBack:SetEdgeColor(0, 0, 0, 0)
    barBack:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    barBack:SetDrawLevel(1)

    barFill = wm:CreateControl(CONTROL_NAME .. "BarFill", barBack, CT_TEXTURE)
    barFill:SetAnchor(CENTER, barBack, CENTER, 0, 0)
    barFill:SetDimensions(BAR_INNER_WIDTH, BAR_HEIGHT - (BAR_INSET * 2))
    barFill:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericfill_tall.dds")
    barFill:SetColor(0, 0.85, 1, 1)
    barFill:SetDrawLevel(2)

    timerLabel = wm:CreateControl(CONTROL_NAME .. "Timer", barBack, CT_LABEL)
    timerLabel:SetAnchor(RIGHT, barBack, RIGHT, -8, 0)
    timerLabel:SetDimensions(58, BAR_HEIGHT)
    timerLabel:SetFont("ZoFontGameLargeBold")
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetDrawLevel(3)

    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function UpdateVisibility()
    EnsureControl()

    local hidden = false
    if not CanShowHud() then
        hidden = true
    elseif IsHudUnlocked() then
        hidden = false
    elseif not IsEnabled() then
        hidden = true
    elseif not hasFatecarverSlotted then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function StopUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_AbilityTrackerUpdate")
    updateRegistered = false
end

local function AddPlayerSourceFilter(eventName)
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
    end
end

local function RegisterActiveCombatResult(suffix, result, filterTarget)
    if filterTarget ~= true and not (REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER) then
        return
    end

    local eventName = ADDON_NAME .. "_AbilityTrackerActive" .. suffix
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnActiveCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, result)
    if filterTarget ~= true then
        AddPlayerSourceFilter(eventName)
    end
    table.insert(activeWatcherEventNames, eventName)
end

local function StartActiveWatcher()
    if activeWatcherRegistered then return end
    activeWatcherEventNames = {}
    RegisterActiveCombatResult("Begin", RESULT_BEGIN, false)
    if ACTION_RESULT_BEGIN_CHANNEL then
        RegisterActiveCombatResult("BeginChannel", RESULT_BEGIN_CHANNEL, false)
    end
    for result in pairs(ACTIVE_TARGET_CANCEL_RESULTS) do
        RegisterActiveCombatResult("Cancel" .. tostring(result), result, true)
    end
    activeWatcherRegistered = true
end

local function StopActiveWatcher()
    if not activeWatcherRegistered then return end
    for _, eventName in ipairs(activeWatcherEventNames) do
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_COMBAT_EVENT)
    end
    activeWatcherEventNames = {}
    activeWatcherRegistered = false
end

local function StopChannel()
    active = false
    activeEffectSeen = false
    activeAbilityId = 0
    activeName = ""
    startMs = 0
    durationMs = 0
    remainingMs = 0
    StopActiveWatcher()
    StopUpdate()
    UpdateVisuals()
    UpdateVisibility()
end

local function RecordChannelEnd(reason, endMs)
    if not active or durationMs <= 0 then return end

    local stats = currentCombatStats or EnsureCombatStats(endMs)
    if not stats then return end

    local elapsedMs = math.max(0, (endMs or GetNowMs()) - startMs)
    local rawRemainingMs = math.max(0, durationMs - elapsedMs)
    local safeWindowMs = GetWarningMs()
    local toleranceMs = 100

    stats.total = stats.total + 1

    if reason == "completed" or rawRemainingMs <= toleranceMs then
        stats.completed = stats.completed + 1
    elseif rawRemainingMs <= safeWindowMs + toleranceMs then
        stats.safeCancelled = stats.safeCancelled + 1
    else
        local earlyMs = math.max(0, rawRemainingMs - safeWindowMs)
        stats.earlyStopped = stats.earlyStopped + 1
        stats.earlyMsTotal = stats.earlyMsTotal + earlyMs
        stats.worstEarlyMs = math.max(stats.worstEarlyMs or 0, earlyMs)
    end
end

function FinishActiveChannel(reason, endMs)
    if not active then return end
    RecordChannelEnd(reason, endMs or GetNowMs())
    StopChannel()
end

local function FormatRemaining(ms)
    ms = math.max(0, tonumber(ms) or 0)
    if ms >= 1000 then
        return string.format("%.1f", ms / 1000)
    end
    return string.format("%.1f", ms / 1000)
end

local function SetBarProgress(progress)
    if not barFill then return end

    progress = tonumber(progress) or 0
    if progress < 0 then progress = 0 end
    if progress > 1 then progress = 1 end

    if progress <= 0 then
        if lastProgressWidth ~= 0 then
            barFill:SetHidden(true)
            lastProgressWidth = 0
        end
        return
    end

    local width = math.max(1, math.floor((BAR_INNER_WIDTH * progress) + 0.5))
    if width == lastProgressWidth then return end
    lastProgressWidth = width

    barFill:SetHidden(false)
    barFill:ClearAnchors()
    barFill:SetAnchor(CENTER, barBack, CENTER, 0, 0)
    barFill:SetDimensions(width, BAR_HEIGHT - (BAR_INSET * 2))
end

function UpdateVisuals()
    EnsureControl()

    SetLabelText(titleLabel, activeName ~= "" and activeName or GetString(EZOM_ABILITY_FATECARVER_NAME), "title")

    if not active then
        SetLabelText(timerLabel, "", "timer")
        SetLabelText(stateLabel, GetString(EZOM_ABILITY_FATECARVER_READY), "state")
        SetBarProgress(0)
        SetVisualMode("idle")
        return
    end

    local nowMs = GetNowMs()
    if activeEffectSeen and nowMs - startMs > CHANNEL_EFFECT_GRACE_MS and not RefreshActiveEffectFromBuffs(nowMs) then
        FinishActiveChannel("faded", nowMs)
        return
    end

    remainingMs = math.max(0, (startMs + durationMs) - nowMs)
    local warningMs = GetWarningMs()
    local ready = remainingMs <= warningMs
    local approaching = not ready and remainingMs <= warningMs + PRE_WARNING_MS
    SetLabelText(timerLabel, FormatRemaining(remainingMs), "timer")

    SetBarProgress(durationMs > 0 and (remainingMs / durationMs) or 0)

    if ready then
        SetLabelText(stateLabel, GetString(EZOM_ABILITY_FATECARVER_CAN_CANCEL), "state")
        SetVisualMode("ready")
    elseif approaching then
        SetLabelText(stateLabel, GetString(EZOM_ABILITY_FATECARVER_CHANNELING), "state")
        SetVisualMode("warning")
    else
        SetLabelText(stateLabel, GetString(EZOM_ABILITY_FATECARVER_CHANNELING), "state")
        SetVisualMode("active")
    end

    if remainingMs <= 0 then
        FinishActiveChannel("completed", nowMs)
    end
end

local function StartUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_AbilityTrackerUpdate", UPDATE_INTERVAL_MS, UpdateVisuals)
    updateRegistered = true
end

local function StartChannel(abilityId, abilityName, actualDurationMs)
    if not IsEnabled() then return end

    local nowMs = GetNowMs()
    if active then
        FinishActiveChannel("replaced", nowMs)
    end

    abilityId = tonumber(abilityId) or 0
    durationMs = tonumber(actualDurationMs) or 0
    if durationMs <= 0 and abilityId > 0 and type(GetAbilityCastInfo) == "function" then
        local _, castTime = GetAbilityCastInfo(abilityId)
        durationMs = tonumber(castTime) or 0
    end
    if durationMs <= 0 then
        durationMs = 4000
    end

    active = true
    activeEffectSeen = false
    activeAbilityId = abilityId
    activeName = tostring(abilityName or "")
    if activeName == "" and type(GetAbilityName) == "function" and activeAbilityId > 0 then
        activeName = GetAbilityName(activeAbilityId)
    end
    if activeName == "" then
        activeName = GetString(EZOM_ABILITY_FATECARVER_NAME)
    end

    startMs = nowMs
    remainingMs = durationMs
    RefreshActiveEffectFromBuffs(nowMs)
    EnsureCombatStats(nowMs)
    if type(GetAbilityIcon) == "function" and activeAbilityId > 0 then
        local abilityIcon = GetAbilityIcon(activeAbilityId)
        if abilityIcon and abilityIcon ~= "" then
            icon:SetTexture(abilityIcon)
        end
    end

    UpdateVisuals()
    UpdateVisibility()
    StartActiveWatcher()
    StartUpdate()
end

local function ScanFatecarverSlot()
    if type(GetSlotName) ~= "function" then return end

    local categories = {}
    if HOTBAR_CATEGORY_PRIMARY then table.insert(categories, HOTBAR_CATEGORY_PRIMARY) end
    if HOTBAR_CATEGORY_BACKUP then table.insert(categories, HOTBAR_CATEGORY_BACKUP) end
    if #categories == 0 and type(GetActiveHotbarCategory) == "function" then
        table.insert(categories, GetActiveHotbarCategory())
    end

    hasFatecarverSlotted = false

    for _, hotbarCategory in ipairs(categories) do
        for slot = 3, 8 do
            local slotName = GetSlotName(slot, hotbarCategory)
            local abilityId, boundId = GetSlotAbilityId(slot, hotbarCategory)
            if IsFatecarverAbility(abilityId, slotName) or IsFatecarverAbility(boundId, slotName) then
                hasFatecarverSlotted = true
                if type(GetSlotTexture) == "function" then
                    local texture = GetSlotTexture(slot, hotbarCategory)
                    if texture and texture ~= "" then
                        slottedFatecarverIcon = texture
                        if icon then icon:SetTexture(texture) end
                    end
                end
                UpdateVisuals()
                UpdateVisibility()
                return true
            end
        end
    end

    if active then
        StopChannel()
    else
        UpdateVisuals()
        UpdateVisibility()
    end
    return false
end

function Tracker.DebugScan()
    EnsureControl()

    if EZOMetter.Print then
        EZOMetter.Print(GetString(EZOM_ABILITY_FATECARVER_SCAN_START))
    end

    local found = ScanFatecarverSlot()
    if EZOMetter.Print then
        EZOMetter.Print(found and GetString(EZOM_ABILITY_FATECARVER_SCAN_FOUND) or GetString(EZOM_ABILITY_FATECARVER_SCAN_NOT_FOUND))
    end

    if not EZOMetter.DebugLog then return end

    local categories = {}
    if HOTBAR_CATEGORY_PRIMARY then table.insert(categories, HOTBAR_CATEGORY_PRIMARY) end
    if HOTBAR_CATEGORY_BACKUP then table.insert(categories, HOTBAR_CATEGORY_BACKUP) end
    if #categories == 0 and type(GetActiveHotbarCategory) == "function" then
        table.insert(categories, GetActiveHotbarCategory())
    end

    for _, hotbarCategory in ipairs(categories) do
        for slot = 3, 8 do
            local slotName = type(GetSlotName) == "function" and GetSlotName(slot, hotbarCategory) or ""
            local abilityId, boundId = GetSlotAbilityId(slot, hotbarCategory)
            EZOMetter.DebugLog(string.format(
                "[AbilityTracker] bar=%s slot=%s name=%s abilityId=%s boundId=%s fatecarver=%s",
                tostring(hotbarCategory),
                tostring(slot),
                tostring(slotName),
                tostring(abilityId),
                tostring(boundId),
                tostring(IsFatecarverAbility(abilityId, slotName) or IsFatecarverAbility(boundId, slotName))
            ))
        end
    end
end

local function OnCombatEvent(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError or not IsEnabled() then return end
    if not IsFatecarverAbility(abilityId, abilityName) then return end

    if result == RESULT_BEGIN then
        if not IsPlayerCombatSource(sourceName, sourceType) then return end
        if tonumber(hitValue) and tonumber(hitValue) <= 75 then return end
        StartChannel(abilityId, abilityName, hitValue)
    elseif active and (result == RESULT_EFFECT_FADED or result == RESULT_INTERRUPT) then
        if result == RESULT_EFFECT_FADED and not IsPlayerCombatTarget(targetName, targetType) then return end
        FinishActiveChannel(result == RESULT_INTERRUPT and "interrupted" or "faded", GetNowMs())
    end
end

function OnActiveCombatEvent(_, result, isError, abilityName, _, _, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    if isError or not active or not IsEnabled() then return end

    if ACTIVE_TARGET_CANCEL_RESULTS[result] == true then
        if not IsPlayerCombatTarget(targetName, targetType) then return end
        FinishActiveChannel("interrupted", GetNowMs())
        return
    end

    if result ~= RESULT_BEGIN and result ~= RESULT_BEGIN_CHANNEL then return end
    if not IsPlayerCombatSource(sourceName, sourceType) then return end
    if IsFatecarverAbility(abilityId, abilityName) then return end

    FinishActiveChannel("cancelled", GetNowMs())
end

function OnPlayerEffectChanged(_, changeType, _, effectName, unitTag, _, endTime, _, iconName, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" or not IsEnabled() then return end
    if not IsFatecarverAbility(abilityId, effectName) then return end

    local nowMs = GetNowMs()
    if changeType == EFFECT_RESULT_GAINED
        or changeType == EFFECT_RESULT_UPDATED
        or changeType == EFFECT_RESULT_FULL_REFRESH
    then
        activeEffectSeen = true
        if iconName and iconName ~= "" then
            slottedFatecarverIcon = iconName
            if icon then icon:SetTexture(iconName) end
        end
        if active and endTime and startMs > 0 then
            local endMs = (tonumber(endTime) or 0) * 1000
            if endMs > nowMs then
                durationMs = math.max(durationMs or 0, endMs - startMs)
                remainingMs = math.max(0, endMs - nowMs)
            end
        end
    elseif changeType == EFFECT_RESULT_FADED and active then
        FinishActiveChannel("faded", nowMs)
    end
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    local wasCombat = isCombat
    local newCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if newCombat then
        isCombat = true
        currentCombatStats = NewCombatStats(nowMs)
        lastCombatSummary = nil
    elseif wasCombat then
        if active then
            FinishActiveChannel("combat_end", nowMs)
        end
        lastCombatSummary = BuildCombatSummary(currentCombatStats, nowMs)
        currentCombatStats = nil
        isCombat = false
    else
        isCombat = false
    end
end

local function OnWeaponPairChanged()
    if active then
        FinishActiveChannel("weapon_swap", GetNowMs())
    end
    ScanFatecarverSlot()
end

function Tracker.ApplySettings()
    EnsureControl()
    if not IsEnabled() and active then
        StopChannel()
    end
    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    ScanFatecarverSlot()
    UpdateVisibility()
end

function Tracker.Init()
    EnsureControl()
    ScanFatecarverSlot()
    UpdateVisuals()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    for abilityId in pairs(FATECARVER_IDS) do
        local beginEventName = ADDON_NAME .. "_AbilityTrackerCombatBegin" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(beginEventName, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(beginEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        EVENT_MANAGER:AddFilterForEvent(beginEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, RESULT_BEGIN)
        if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
            EVENT_MANAGER:AddFilterForEvent(beginEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end

        local fadedEventName = ADDON_NAME .. "_AbilityTrackerCombatFaded" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(fadedEventName, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(fadedEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        EVENT_MANAGER:AddFilterForEvent(fadedEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, RESULT_EFFECT_FADED)

        local interruptEventName = ADDON_NAME .. "_AbilityTrackerCombatInterrupt" .. tostring(abilityId)
        EVENT_MANAGER:RegisterForEvent(interruptEventName, EVENT_COMBAT_EVENT, OnCombatEvent)
        EVENT_MANAGER:AddFilterForEvent(interruptEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
        EVENT_MANAGER:AddFilterForEvent(interruptEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, RESULT_INTERRUPT)
        if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
            EVENT_MANAGER:AddFilterForEvent(interruptEventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
        end
    end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerCombatState", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerSlots", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, ScanFatecarverSlot)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerSlotUpdated", EVENT_ACTION_SLOT_UPDATED, ScanFatecarverSlot)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerActivated", EVENT_PLAYER_ACTIVATED, ScanFatecarverSlot)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerPlayerEffects", EVENT_EFFECT_CHANGED, OnPlayerEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_AbilityTrackerPlayerEffects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AbilityTrackerWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPairChanged)
    end

    UpdateVisibility()
end

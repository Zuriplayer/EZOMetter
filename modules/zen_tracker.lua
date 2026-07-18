-- Z'en's Redress tracker.
EZOMetter_Zen = EZOMetter_Zen or {}

local Tracker = EZOMetter_Zen
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterZenTracker"
local LIBCOMBAT_CALLBACK_NAME = ADDON_NAME .. "_ZenLibCombat"
local UPDATE_INTERVAL_MS = 250
local EQUIPMENT_SCAN_INTERVAL_MS = 1000
local WEAPON_SWAP_SCAN_DELAY_MS = 500
local WIDTH = 260
local HEIGHT = 96
local PADDING = 10
local ROW_HEIGHT = 18

local MODE_OFF = "off"
local MODE_AUTO = "auto"
local MODE_ON = "on"

local ZEN_TOUCH_ID = 126597
local ZEN_TOUCH_FALLBACK_DURATION_MS = 20000
local MAX_STACKS = 5

local ZEN_SET_IDS = {
    [455] = true,
}

local ZEN_ALIASES = {
    "Z'en's Redress",
    "Zens Redress",
    "Redressement de Z'en",
    "Z'ens Wiedergutmachung",
    "Reparacion de Z'en",
    "Reparación de Z'en",
    "Rectificación de Z'en",
    "Recompensa de Z'en",
}

local control
local backdrop
local titleLabel
local piecesLabel
local potentialLabel
local effectiveLabel
local leftLabel
local targetLabel
local bar
local updateRegistered = false
local libCombatRegistered = false
local isCombat = false
local forceShow = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local targets = {}
local activeTargetKey = nil
local combatStartMs = 0
local lastSampleMs = 0
local requiredMs = 0
local touchActiveMs = 0
local potentialWeightedMs = 0
local effectiveWeightedMs = 0
local potentialCapMs = 0
local effectiveCapMs = 0
local lastCombatSummary = nil
local IsHudUnlocked
local RefreshState
local RefreshUpdateRegistration

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.zen = EZOMetter.sv.zen or {}
    return EZOMetter.sv.zen
end

local function GetNowMs()
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.GetNowMs then
        return EZOMetter_CombatSummary.GetNowMs()
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetGameTimeSeconds) == "function" then
        return GetGameTimeSeconds() * 1000
    end
    return 0
end

local function FormatSeconds(ms)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatSeconds(ms) .. "s"
    end
    return string.format("%.1fs", math.max(0, tonumber(ms) or 0) / 1000)
end

local function FormatPercent(value)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

local function FormatNumber(value)
    return string.format("%.1f", tonumber(value) or 0)
end

local function CleanName(name)
    name = tostring(name or "")
    name = string.gsub(name, "%^.*", "")
    if type(zo_strformat) == "function" and SI_UNIT_NAME then
        name = zo_strformat(SI_UNIT_NAME, name)
    end
    return name
end

local function DebugLog(message)
    local settings = GetSettings()
    if settings
        and settings.debugEvents == true
        and EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.debugMode == true
        and EZOMetter.DebugLog then
        EZOMetter.DebugLog("[Z'en] " .. tostring(message))
    end
end

local function GetMode()
    local settings = GetSettings()
    local mode = settings and settings.mode or MODE_AUTO
    if mode == MODE_ON or mode == MODE_OFF then return mode end
    return MODE_AUTO
end

local function IsZenSet(setName, setId)
    if ZEN_SET_IDS[tonumber(setId) or 0] then return true end
    return EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.NameMatches(setName, ZEN_ALIASES)
end

local function HasLibCombatZen()
    return LibCombat ~= nil
        and LIBCOMBAT_EVENT_EFFECTS_OUT ~= nil
        and type(LibCombat.RegisterCallbackType) == "function"
end

local function ScanEquipment()
    currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
    if EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.GetWornSetSnapshot then
        currentSnapshot = EZOMetter_EquipmentSets.GetWornSetSnapshot(IsZenSet)
    end
    lastEquipmentScanMs = GetNowMs()
end

local function QueueEquipmentScan(delayMs)
    delayMs = tonumber(delayMs) or 0
    lastEquipmentScanMs = GetNowMs()
    if delayMs > 0 and type(zo_callLater) == "function" then
        zo_callLater(function()
            ScanEquipment()
            RefreshUpdateRegistration()
            RefreshState()
        end, delayMs)
        return
    end

    ScanEquipment()
    RefreshUpdateRegistration()
    RefreshState()
end

local function GetPieces()
    return tonumber(currentSnapshot and currentSnapshot.numEquipped) or 0
end

local function HasFivePieces()
    return currentSnapshot and currentSnapshot.hasSet == true and GetPieces() >= 5
end

local function HasVisibleSet()
    return currentSnapshot and currentSnapshot.hasSet == true and GetPieces() >= 3
end

local function IsEnabled()
    local mode = GetMode()
    if mode == MODE_ON then return true end
    if mode == MODE_OFF then return false end
    return HasVisibleSet()
end

local function GetTargetKey(unitTag, unitName, unitId)
    unitId = tonumber(unitId) or 0
    if unitId > 0 then return "id:" .. tostring(unitId) end

    local cleanName = CleanName(unitName)
    if cleanName ~= "" then return "name:" .. cleanName end

    if unitTag and unitTag ~= "" then return "tag:" .. tostring(unitTag) end
    return nil
end

local function IsIgnoredUnitTag(unitTag)
    unitTag = tostring(unitTag or "")
    if unitTag == "player" or unitTag == "companion" then return true end
    if string.sub(unitTag, 1, 5) == "group" then return true end
    return false
end

local function GetTarget(key, unitTag, unitName, unitId)
    if not key then return nil end
    local target = targets[key]
    if not target then
        target = {
            key = key,
            name = "",
            unitId = tonumber(unitId) or 0,
            dots = {},
            touchUntilMs = 0,
            lastSeenMs = GetNowMs(),
        }
        targets[key] = target
    end

    local cleanName = CleanName(unitName)
    if cleanName == "" and unitTag and unitTag ~= "" and type(GetUnitName) == "function" then
        cleanName = CleanName(GetUnitName(unitTag))
    end
    if cleanName ~= "" then target.name = cleanName end
    target.unitId = tonumber(unitId) or target.unitId or 0
    target.lastSeenMs = GetNowMs()
    return target
end

local function GetTargetByUnitId(unitId)
    unitId = tonumber(unitId) or 0
    if unitId <= 0 then return nil end
    return GetTarget(GetTargetKey(nil, "", unitId), nil, "", unitId)
end

local function GetEffectKey(effectSlot, abilityId)
    effectSlot = tonumber(effectSlot) or 0
    abilityId = tonumber(abilityId) or 0
    if effectSlot > 0 then return "slot:" .. tostring(effectSlot) end
    return "ability:" .. tostring(abilityId)
end

local function GetTargetDotCount(target, nowMs)
    if not target then return 0 end
    nowMs = nowMs or GetNowMs()
    local count = 0
    for key, dot in pairs(target.dots or {}) do
        if (tonumber(dot.endMs) or 0) > nowMs then
            count = count + 1
        else
            target.dots[key] = nil
        end
    end
    return math.min(MAX_STACKS, count)
end

local function IsTouchActive(target, nowMs)
    return target and (tonumber(target.touchUntilMs) or 0) > (nowMs or GetNowMs())
end

local function GetTouchRemainingMs(target, nowMs)
    if not target then return 0 end
    return math.max(0, (tonumber(target.touchUntilMs) or 0) - (nowMs or GetNowMs()))
end

local function GetActiveTarget()
    local nowMs = GetNowMs()
    if activeTargetKey and targets[activeTargetKey] then return targets[activeTargetKey] end

    local best
    for _, target in pairs(targets) do
        if not best or (target.lastSeenMs or 0) > (best.lastSeenMs or 0) then
            best = target
        end
    end

    if best then
        activeTargetKey = best.key
        GetTargetDotCount(best, nowMs)
    end
    return best
end

local function GetCurrentStacks(nowMs)
    local target = GetActiveTarget()
    if target and libCombatRegistered and target.libCombatStacks ~= nil then
        nowMs = nowMs or GetNowMs()
        local updatedMs = tonumber(target.libCombatUpdatedMs) or 0
        if IsTouchActive(target, nowMs) or target.libCombatStacks == 0 or nowMs - updatedMs <= ZEN_TOUCH_FALLBACK_DURATION_MS + 2000 then
            return math.max(0, math.min(MAX_STACKS, tonumber(target.libCombatStacks) or 0)), target, "libcombat"
        end
    end

    return GetTargetDotCount(target, nowMs), target, "fallback"
end

local function GetCurrentValues(nowMs)
    nowMs = nowMs or GetNowMs()
    local stacks, target, stackSource = GetCurrentStacks(nowMs)
    local potential = stacks
    local effective = (HasFivePieces() and IsTouchActive(target, nowMs)) and potential or 0
    return potential, effective, target, stackSource
end

local function GetAverage(weightedMs)
    if requiredMs <= 0 then return 0 end
    return (tonumber(weightedMs) or 0) / requiredMs
end

local function BuildSummary(nowMs)
    nowMs = nowMs or GetNowMs()
    local durationMs = combatStartMs > 0 and math.max(0, nowMs - combatStartMs) or requiredMs
    local potential, effective, target, stackSource = GetCurrentValues(nowMs)
    return {
        hasData = requiredMs > 0,
        durationMs = durationMs,
        requiredMs = requiredMs,
        pieces = GetPieces(),
        hasFivePieces = HasFivePieces(),
        potential = potential,
        effective = effective,
        potentialAverage = GetAverage(potentialWeightedMs),
        effectiveAverage = GetAverage(effectiveWeightedMs),
        touchUptime = requiredMs > 0 and (touchActiveMs / requiredMs) * 100 or 0,
        potentialCapTime = requiredMs > 0 and (potentialCapMs / requiredMs) * 100 or 0,
        effectiveCapTime = requiredMs > 0 and (effectiveCapMs / requiredMs) * 100 or 0,
        remainingMs = GetTouchRemainingMs(target, nowMs),
        target = target and target.name or "",
        stackSource = stackSource,
    }
end

local function SampleCombat(nowMs)
    if not isCombat then return end
    nowMs = nowMs or GetNowMs()
    local deltaMs = nowMs - (lastSampleMs or nowMs)
    if deltaMs <= 0 then
        lastSampleMs = nowMs
        return
    end

    local potential, effective, target = GetCurrentValues(nowMs)
    requiredMs = requiredMs + deltaMs
    potentialWeightedMs = potentialWeightedMs + (potential * deltaMs)
    effectiveWeightedMs = effectiveWeightedMs + (effective * deltaMs)
    if target and IsTouchActive(target, nowMs) then
        touchActiveMs = touchActiveMs + deltaMs
    end
    if potential >= MAX_STACKS then potentialCapMs = potentialCapMs + deltaMs end
    if effective >= MAX_STACKS then effectiveCapMs = effectiveCapMs + deltaMs end

    lastSampleMs = nowMs
end

local function BuildTooltipText()
    local summary = isCombat and BuildSummary(GetNowMs()) or lastCombatSummary
    if not summary or not summary.hasData then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        GetString(EZOM_ZEN_SUMMARY_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(summary.durationMs),
        GetString(EZOM_ZEN_PIECES) .. ": " .. tostring(summary.pieces) .. "/5",
        GetString(EZOM_ZEN_TOUCH_UPTIME) .. ": " .. FormatPercent(summary.touchUptime),
        GetString(EZOM_ZEN_POTENTIAL_AVERAGE) .. ": " .. FormatNumber(summary.potentialAverage) .. "/5",
        GetString(EZOM_ZEN_EFFECTIVE_AVERAGE) .. ": " .. FormatNumber(summary.effectiveAverage) .. "/5",
        GetString(EZOM_ZEN_POTENTIAL_CAP_TIME) .. ": " .. FormatPercent(summary.potentialCapTime),
        GetString(EZOM_ZEN_EFFECTIVE_CAP_TIME) .. ": " .. FormatPercent(summary.effectiveCapTime),
        GetString(EZOM_ZEN_STACK_SOURCE) .. ": " .. GetString(summary.stackSource == "libcombat" and EZOM_ZEN_STACK_SOURCE_LIBCOMBAT or EZOM_ZEN_STACK_SOURCE_FALLBACK),
        GetString(EZOM_ZEN_REMAINING) .. ": " .. FormatSeconds(summary.remainingMs),
        GetString(EZOM_ZEN_TARGET) .. ": " .. ((summary.target and summary.target ~= "") and summary.target or GetString(EZOM_SUMMARY_NOT_APPLICABLE)),
    }

    return table.concat(lines, "\n")
end

function Tracker.GetReportSection()
    if GetMode() == MODE_OFF or not lastCombatSummary or not lastCombatSummary.hasData then return nil end
    return BuildTooltipText()
end

local function ShowTooltip()
    if control and EZOMetter_CombatSummary and EZOMetter_CombatSummary.ShowTooltip then
        EZOMetter_CombatSummary.ShowTooltip(control, BuildTooltipText())
    end
end

local function HideTooltip()
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.HideTooltip then
        EZOMetter_CombatSummary.HideTooltip()
    end
end

local function SetMoveMode(enabled)
    if not control then return end
    control:SetMouseEnabled(true)
    control:SetMovable(enabled == true)
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 260, tonumber(settings.y) or -40)
end

local function ApplyBackdrop()
    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control)
    end
    if not backdrop then return end
    local settings = GetSettings() or {}
    local alpha = math.max(0, math.min(100, tonumber(settings.backgroundOpacity) or 86)) / 100
    backdrop:SetCenterColor(0, 0, 0, alpha)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.95, 0.78, 0.15, 1)
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
    control:SetMouseEnabled(true)
    control:SetMovable(false)

    EZOMetter_VisualContext.BindPrimaryDrag(control, function()
        return IsHudUnlocked()
    end, SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetCenterColor(0, 0, 0, 0.86)
    backdrop:SetEdgeColor(0.95, 0.78, 0.15, 1)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, PADDING - 2)
    titleLabel:SetDimensions(132, ROW_HEIGHT)
    titleLabel:SetFont("ZoFontGameLargeBold")
    titleLabel:SetText("Z'en")

    piecesLabel = wm:CreateControl(CONTROL_NAME .. "Pieces", control, CT_LABEL)
    piecesLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, PADDING)
    piecesLabel:SetDimensions(76, ROW_HEIGHT)
    piecesLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    piecesLabel:SetFont("ZoFontGame")

    potentialLabel = wm:CreateControl(CONTROL_NAME .. "Potential", control, CT_LABEL)
    potentialLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 3)
    potentialLabel:SetDimensions(82, ROW_HEIGHT)
    potentialLabel:SetFont("ZoFontGame")

    effectiveLabel = wm:CreateControl(CONTROL_NAME .. "Effective", control, CT_LABEL)
    effectiveLabel:SetAnchor(TOPLEFT, potentialLabel, TOPRIGHT, 6, 0)
    effectiveLabel:SetDimensions(82, ROW_HEIGHT)
    effectiveLabel:SetFont("ZoFontGame")

    leftLabel = wm:CreateControl(CONTROL_NAME .. "Left", control, CT_LABEL)
    leftLabel:SetAnchor(TOPRIGHT, piecesLabel, BOTTOMRIGHT, 0, 3)
    leftLabel:SetDimensions(76, ROW_HEIGHT)
    leftLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    leftLabel:SetFont("ZoFontGame")

    targetLabel = wm:CreateControl(CONTROL_NAME .. "Target", control, CT_LABEL)
    targetLabel:SetAnchor(TOPLEFT, potentialLabel, BOTTOMLEFT, 0, 3)
    targetLabel:SetDimensions(WIDTH - (PADDING * 2), ROW_HEIGHT)
    targetLabel:SetFont("ZoFontGame")

    bar = wm:CreateControl(CONTROL_NAME .. "Bar", control, CT_STATUSBAR)
    bar:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, PADDING, -PADDING)
    bar:SetDimensions(WIDTH - (PADDING * 2), 10)
    bar:SetMinMax(0, MAX_STACKS)
    bar:SetValue(0)

    ApplyPosition()
    ApplyBackdrop()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function GetStatusColor(potential, effective, hasFive, touchActive)
    if hasFive and touchActive and effective >= MAX_STACKS then return 0.15, 1, 0.35 end
    if potential >= MAX_STACKS then return 0.15, 1, 0.35 end
    if potential >= 3 then return 1, 0.86, 0.25 end
    if potential >= 1 then return 1, 0.55, 0.15 end
    return 1, 0.25, 0.2
end

local function UpdateVisuals()
    EnsureControl()
    local nowMs = GetNowMs()
    local potential, effective, target = GetCurrentValues(nowMs)
    local hasFive = HasFivePieces()
    local touchActive = IsTouchActive(target, nowMs)
    local remainingMs = touchActive and GetTouchRemainingMs(target, nowMs) or 0
    local r, g, b = GetStatusColor(potential, effective, hasFive, touchActive)
    local value = hasFive and effective or potential

    titleLabel:SetColor(r, g, b, 1)
    piecesLabel:SetColor(hasFive and 0.15 or 1, hasFive and 1 or 0.86, hasFive and 0.35 or 0.25, 1)
    potentialLabel:SetColor(r, g, b, 1)
    effectiveLabel:SetColor(hasFive and r or 0.7, hasFive and g or 0.7, hasFive and b or 0.7, 1)
    leftLabel:SetColor(touchActive and 0.15 or 0.7, touchActive and 1 or 0.7, touchActive and 0.35 or 0.7, 1)
    targetLabel:SetColor(0.78, 0.9, 1, 1)
    bar:SetColor(r, g, b, 0.9)
    bar:SetValue(value)

    piecesLabel:SetText(GetString(EZOM_ZEN_PIECES_SHORT) .. ": " .. tostring(GetPieces()) .. "/5")
    potentialLabel:SetText(GetString(EZOM_ZEN_POTENTIAL_SHORT) .. ": " .. tostring(potential) .. "/5")
    effectiveLabel:SetText(GetString(EZOM_ZEN_EFFECTIVE_SHORT) .. ": " .. tostring(effective) .. "%")
    leftLabel:SetText(GetString(EZOM_ZEN_REMAINING_SHORT) .. ": " .. FormatSeconds(remainingMs))
    targetLabel:SetText((target and target.name and target.name ~= "") and target.name or GetString(EZOM_SUMMARY_NOT_APPLICABLE))
end

local function UpdateVisibility()
    EnsureControl()
    local hidden = false
    if not CanShowHud() then
        hidden = true
    elseif forceShow then
        hidden = false
    elseif IsHudUnlocked() then
        hidden = false
    elseif not IsEnabled() then
        hidden = true
    end
    control:SetHidden(hidden)
end

function RefreshState()
    local nowMs = GetNowMs()
    if nowMs - lastEquipmentScanMs >= EQUIPMENT_SCAN_INTERVAL_MS then
        ScanEquipment()
    end
    SampleCombat(nowMs)
    UpdateVisuals()
    UpdateVisibility()
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_ZenUpdate", UPDATE_INTERVAL_MS, RefreshState)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_ZenUpdate")
    updateRegistered = false
end

function RefreshUpdateRegistration()
    if IsHudUnlocked() or forceShow or IsEnabled() then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function ResetCombatData(nowMs)
    combatStartMs = nowMs or 0
    lastSampleMs = nowMs or 0
    requiredMs = 0
    touchActiveMs = 0
    potentialWeightedMs = 0
    effectiveWeightedMs = 0
    potentialCapMs = 0
    effectiveCapMs = 0
end

local function IsEffectGain(changeType)
    return changeType == EFFECT_RESULT_GAINED
        or changeType == EFFECT_RESULT_UPDATED
        or changeType == EFFECT_RESULT_FULL_REFRESH
end

local function IsEffectFade(changeType)
    return changeType == EFFECT_RESULT_FADED
end

local function OnLibCombatEffectsOut(_, _timeMs, unitId, abilityId, changeType, _effectType, stacks, sourceType, _effectSlot)
    abilityId = tonumber(abilityId) or 0
    if abilityId ~= ZEN_TOUCH_ID then return end
    if sourceType and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local nowMs = GetNowMs()
    local target = GetTargetByUnitId(unitId)
    if not target then return end

    activeTargetKey = target.key
    target.libCombatStacks = math.max(0, math.min(MAX_STACKS, tonumber(stacks) or 0))
    target.libCombatUpdatedMs = nowMs

    if IsEffectGain(changeType) and (tonumber(target.touchUntilMs) or 0) <= nowMs then
        target.touchUntilMs = nowMs + ZEN_TOUCH_FALLBACK_DURATION_MS
    elseif IsEffectFade(changeType) then
        target.touchUntilMs = 0
    end

    DebugLog(string.format(
        "libcombat zen target=%s unitId=%s stacks=%s change=%s",
        tostring(target.name),
        tostring(unitId),
        tostring(target.libCombatStacks),
        tostring(changeType)
    ))
end

local function RegisterLibCombat()
    if libCombatRegistered or not HasLibCombatZen() then return end
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_EFFECTS_OUT, OnLibCombatEffectsOut, LIBCOMBAT_CALLBACK_NAME)
    libCombatRegistered = true
    DebugLog("LibCombat Z'en stack callback registered")
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if nowCombat then
        isCombat = true
        ResetCombatData(nowMs)
        lastCombatSummary = nil
    else
        if isCombat then
            SampleCombat(nowMs)
            lastCombatSummary = BuildSummary(nowMs)
        end
        isCombat = false
        ResetCombatData(0)
    end

    ScanEquipment()
    RefreshState()
    RefreshUpdateRegistration()
end

local function OnEffectChanged(_, changeType, effectSlot, _effectName, unitTag, _beginTime, endTime, _stackCount, _iconName, _buffType, effectType, abilityType, _statusEffectType, unitName, unitId, abilityId, sourceType)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if IsIgnoredUnitTag(unitTag) then return end

    abilityId = tonumber(abilityId) or 0
    local nowMs = GetNowMs()
    local key = GetTargetKey(unitTag, unitName, unitId)
    local target = GetTarget(key, unitTag, unitName, unitId)
    if not target then return end
    activeTargetKey = key

    local isGain = changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FULL_REFRESH
    local isFade = changeType == EFFECT_RESULT_FADED
    local endMs = (tonumber(endTime) or 0) * 1000

    if abilityId == ZEN_TOUCH_ID then
        if isGain then
            if endMs <= nowMs then endMs = nowMs + ZEN_TOUCH_FALLBACK_DURATION_MS end
            target.touchUntilMs = endMs
            DebugLog(string.format("touch gained target=%s end=%s", tostring(target.name), tostring(target.touchUntilMs)))
        elseif isFade then
            target.touchUntilMs = 0
            DebugLog(string.format("touch faded target=%s", tostring(target.name)))
        end
        return
    end

    if effectType and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
    if abilityType ~= ABILITY_TYPE_DAMAGE then return end

    local dotKey = GetEffectKey(effectSlot, abilityId)
    if isGain then
        if endMs <= nowMs then return end
        target.dots[dotKey] = {
            abilityId = abilityId,
            endMs = endMs,
        }
        DebugLog(string.format("dot gained target=%s ability=%s end=%s", tostring(target.name), tostring(abilityId), tostring(endMs)))
    elseif isFade then
        target.dots[dotKey] = nil
        DebugLog(string.format("dot faded target=%s ability=%s", tostring(target.name), tostring(abilityId)))
    end
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyBackdrop()
    SetMoveMode(IsHudUnlocked())
    RegisterLibCombat()
    ScanEquipment()
    RefreshUpdateRegistration()
    RefreshState()
end

function Tracker.SetForceShow(enabled)
    forceShow = enabled == true
    if forceShow then
        currentSnapshot = { hasSet = true, numEquipped = math.max(GetPieces(), 3), maxEquipped = 5 }
    else
        ScanEquipment()
    end
    RefreshUpdateRegistration()
    RefreshState()
end

function Tracker.Init()
    EnsureControl()
    ScanEquipment()
    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenEffects", EVENT_EFFECT_CHANGED, OnEffectChanged)

    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            QueueEquipmentScan(0)
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            QueueEquipmentScan(WEAPON_SWAP_SCAN_DELAY_MS)
        end)
    end

    RegisterLibCombat()
    RefreshUpdateRegistration()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

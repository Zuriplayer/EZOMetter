-- Z'en's Redress tracker.
EZOMetter_Zen = EZOMetter_Zen or {}

local Tracker = EZOMetter_Zen
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterZenTracker"
local MARKER_RENDER_NAME = "EZOMetterZenMarkerRenderControl"
local MARKER_WINDOW_NAME = "EZOMetterZenMarkerWindow"
local MARKER_CONTROL_NAME = "EZOMetterZenTargetMarker"
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
local MARKER_UPDATE_MS = 100
local MARKER_ICON_SIZE = 96
local MARKER_OFFSET_M = 2.8
local DEBUG_COMBAT_EVENT_NAME = ADDON_NAME .. "_ZenDebugAttacks"
local ATTACK_CORRELATION_BEFORE_MS = 250
local ATTACK_CORRELATION_AFTER_MS = 250

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
local markerRenderControl
local markerWindow
local marker
local markerUpdateRegistered = false
local markerDebugState = ""
local markerCamera = {}
local markerVisible = false
local markerX
local markerY
local markerScale
local weaponPairScanSequence = 0
local updateRegistered = false
local libCombatRegistered = false
local debugCombatRegistered = false
local effectEventsRegistered = false
local isCombat = false
local forceShow = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local targets = {}
local recentAttacks = {}
local pendingTouchApplications = {}
local pendingTouchSequence = 0
local combatStartMs = 0
local lastSampleMs = 0
local requiredMs = 0
local touchActiveMs = 0
local potentialWeightedMs = 0
local effectiveWeightedMs = 0
local potentialCapMs = 0
local effectiveCapMs = 0
local lastCombatSummary = nil
local combatRelevant = false
local combatMaxPieces = 0
local combatTouchPieces = 0
local combatTouchPair = ""
local combatTargetName = ""
local combatUsedLibCombat = false
local IsHudUnlocked
local RefreshState
local RefreshUpdateRegistration
local RefreshDebugCombatRegistration
local RefreshEffectRegistration
local GetActiveWeaponPairName

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

local function IsOfflinePlaceholder(value)
    return string.lower(tostring(value or "")) == "offline"
end

local function IsDebugEnabled()
    local settings = GetSettings()
    return settings
        and settings.debugEvents == true
        and EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.debugMode == true
end

local function DebugLog(message)
    if IsDebugEnabled() and EZOMetter.DebugLog then
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

local function QueueEquipmentScan(delayMs, debugWeaponSwap)
    delayMs = tonumber(delayMs) or 0
    lastEquipmentScanMs = GetNowMs()
    local scanSequence
    if debugWeaponSwap then
        weaponPairScanSequence = weaponPairScanSequence + 1
        scanSequence = weaponPairScanSequence
    end

    if delayMs > 0 and type(zo_callLater) == "function" then
        zo_callLater(function()
            if scanSequence and scanSequence ~= weaponPairScanSequence then return end
            ScanEquipment()
            if debugWeaponSwap then
                DebugLog(string.format(
                    "weapon swap pair=%s pieces=%s hasFive=%s",
                    tostring(GetActiveWeaponPairName()),
                    tostring(currentSnapshot.numEquipped or 0),
                    tostring(currentSnapshot.hasSet == true and (currentSnapshot.numEquipped or 0) >= 5)
                ))
            end
            RefreshEffectRegistration()
            RefreshUpdateRegistration()
            RefreshState()
        end, delayMs)
        return
    end

    ScanEquipment()
    RefreshEffectRegistration()
    RefreshUpdateRegistration()
    RefreshState()
end

local function GetPieces()
    return tonumber(currentSnapshot and currentSnapshot.numEquipped) or 0
end

local function HasFivePieces()
    return currentSnapshot and currentSnapshot.hasSet == true and GetPieces() >= 5
end

local function GetWeaponPairName(pair)
    pair = tonumber(pair) or 0
    if ACTIVE_WEAPON_PAIR_MAIN ~= nil and pair == ACTIVE_WEAPON_PAIR_MAIN then return "main" end
    if ACTIVE_WEAPON_PAIR_BACKUP ~= nil and pair == ACTIVE_WEAPON_PAIR_BACKUP then return "backup" end
    if ACTIVE_WEAPON_PAIR_NONE ~= nil and pair == ACTIVE_WEAPON_PAIR_NONE then return "none" end
    return tostring(pair)
end

GetActiveWeaponPairName = function()
    if type(GetActiveWeaponPairInfo) ~= "function" then return "unknown" end
    return GetWeaponPairName(GetActiveWeaponPairInfo())
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
    if cleanName ~= "" and not IsOfflinePlaceholder(cleanName) then return "name:" .. cleanName end

    if unitTag and unitTag ~= "" and not IsOfflinePlaceholder(unitTag) then
        return "tag:" .. tostring(unitTag)
    end
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
    if IsOfflinePlaceholder(cleanName) then cleanName = "" end
    if cleanName == ""
        and unitTag
        and unitTag ~= ""
        and not IsOfflinePlaceholder(unitTag)
        and type(GetUnitName) == "function" then
        cleanName = CleanName(GetUnitName(unitTag))
        if IsOfflinePlaceholder(cleanName) then cleanName = "" end
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
    local touchTarget
    local dotTarget
    local best
    for _, target in pairs(targets) do
        local dotCount = GetTargetDotCount(target, nowMs)
        if IsTouchActive(target, nowMs)
            and (not touchTarget or (target.lastSeenMs or 0) > (touchTarget.lastSeenMs or 0)) then
            touchTarget = target
        end
        if dotCount > 0
            and (not dotTarget or (target.lastSeenMs or 0) > (dotTarget.lastSeenMs or 0)) then
            dotTarget = target
        end
        if not best or (target.lastSeenMs or 0) > (best.lastSeenMs or 0) then
            best = target
        end
    end

    local selected = touchTarget or dotTarget or best
    return selected
end

local function GetCurrentStacks(nowMs)
    local target = GetActiveTarget()
    nowMs = nowMs or GetNowMs()
    if target
        and libCombatRegistered
        and target.libCombatStacks ~= nil
        and IsTouchActive(target, nowMs) then
        return math.max(0, math.min(MAX_STACKS, tonumber(target.libCombatStacks) or 0)), target, "libcombat"
    end

    return GetTargetDotCount(target, nowMs), target, "fallback"
end

local function GetCurrentValues(nowMs)
    nowMs = nowMs or GetNowMs()
    local stacks, target, stackSource = GetCurrentStacks(nowMs)
    local potential = stacks
    local effective = IsTouchActive(target, nowMs) and potential or 0
    return potential, effective, target, stackSource
end

local function StoreRecentAttack(attack)
    local unitId = tonumber(attack and attack.targetUnitId) or 0
    local targetName = CleanName(attack and attack.targetName)
    if unitId > 0 then recentAttacks["id:" .. tostring(unitId)] = attack end
    if targetName ~= "" then recentAttacks["name:" .. targetName] = attack end
end

local function GetCorrelationKey(targetName, unitId)
    unitId = tonumber(unitId) or 0
    if unitId > 0 then return "id:" .. tostring(unitId) end

    local cleanName = CleanName(targetName)
    if cleanName ~= "" then return "name:" .. cleanName end
    return nil
end

local function GetRecentLightAttack(targetName, unitId, nowMs)
    nowMs = nowMs or GetNowMs()
    unitId = tonumber(unitId) or 0
    local cleanName = CleanName(targetName)
    local attack
    if unitId > 0 then attack = recentAttacks["id:" .. tostring(unitId)] end
    if not attack and cleanName ~= "" then attack = recentAttacks["name:" .. cleanName] end
    local ageMs = nowMs - (tonumber(attack and attack.timeMs) or 0)
    if not attack
        or attack.attackType ~= "light"
        or ageMs < 0
        or ageMs > ATTACK_CORRELATION_BEFORE_MS then
        return nil
    end
    return attack
end

local function RecordTouchApplication(target, pieces, pair)
    pieces = tonumber(pieces) or 0
    combatMaxPieces = math.max(combatMaxPieces, pieces)
    combatTouchPieces = math.max(combatTouchPieces, pieces)
    if pair and pair ~= "" then combatTouchPair = pair end
    if target and target.name and target.name ~= "" then combatTargetName = target.name end
    if pieces >= MAX_STACKS then combatRelevant = true end
end

local function ClearPendingTouch(targetName, unitId)
    local key = GetCorrelationKey(targetName, unitId)
    if key then pendingTouchApplications[key] = nil end
end

local function ResolvePendingTouchWithAttack(attack)
    if not attack or attack.attackType ~= "light" then return false end

    local key = GetCorrelationKey(attack.targetName, attack.targetUnitId)
    local pending = key and pendingTouchApplications[key]
    if not pending then return false end

    local delayMs = (tonumber(attack.timeMs) or 0) - (tonumber(pending.timeMs) or 0)
    if delayMs < 0 then return false end
    if delayMs > ATTACK_CORRELATION_AFTER_MS then
        pendingTouchApplications[key] = nil
        return false
    end

    pendingTouchApplications[key] = nil
    DebugLog(string.format(
        "touch correlation resolved direction=after attack=light target=%s unitId=%s attackDelayMs=%s attackPair=%s attackPieces=%s attackHasFive=%s validApplication=%s",
        tostring(attack.targetName),
        tostring(attack.targetUnitId),
        tostring(delayMs),
        tostring(attack.pair),
        tostring(attack.pieces),
        tostring(attack.hasFive),
        tostring(attack.hasFive == true)
    ))
    return true
end

local function QueuePendingTouch(target, nowMs)
    local key = GetCorrelationKey(target and target.name, target and target.unitId)
    if not key then return false end

    pendingTouchSequence = pendingTouchSequence + 1
    local sequence = pendingTouchSequence
    pendingTouchApplications[key] = {
        sequence = sequence,
        timeMs = nowMs,
        targetName = target.name,
        targetUnitId = target.unitId,
    }

    if type(zo_callLater) == "function" then
        zo_callLater(function()
            local pending = pendingTouchApplications[key]
            if not pending or pending.sequence ~= sequence then return end
            pendingTouchApplications[key] = nil
            DebugLog(string.format(
                "touch correlation unresolved target=%s unitId=%s waitMs=%s reason=no-light-impact",
                tostring(pending.targetName),
                tostring(pending.targetUnitId),
                tostring(ATTACK_CORRELATION_AFTER_MS)
            ))
        end, ATTACK_CORRELATION_AFTER_MS)
    end
    return true
end

local function IsAttackImpactResult(result)
    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DAMAGE_SHIELDED
end

local function GetAttackType(actionSlotType)
    if actionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK then return "light" end
    if actionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then return "heavy" end
    return nil
end

local function OnDebugCombatEvent(
    _,
    result,
    isError,
    abilityName,
    _,
    actionSlotType,
    _,
    sourceType,
    targetName,
    _,
    hitValue,
    _,
    _,
    _,
    _,
    targetUnitId,
    abilityId
)
    if isError or not IsAttackImpactResult(result) then return end
    if COMBAT_UNIT_TYPE_PLAYER ~= nil and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local attackType = GetAttackType(actionSlotType)
    if not attackType then return end

    ScanEquipment()
    local nowMs = GetNowMs()
    local key = GetTargetKey(nil, targetName, targetUnitId)
    local target = GetTarget(key, nil, targetName, targetUnitId)
    local touchActive = IsTouchActive(target, nowMs)
    local attack = {
        timeMs = nowMs,
        attackType = attackType,
        targetName = CleanName(targetName),
        targetUnitId = tonumber(targetUnitId) or 0,
        abilityId = tonumber(abilityId) or 0,
        abilityName = CleanName(abilityName),
        pair = GetActiveWeaponPairName(),
        pieces = GetPieces(),
        hasFive = HasFivePieces(),
    }
    StoreRecentAttack(attack)
    local resolvedPendingTouch = ResolvePendingTouchWithAttack(attack)

    DebugLog(string.format(
        "attack type=%s target=%s unitId=%s ability=%s(%s) result=%s hit=%s pair=%s pieces=%s hasFive=%s touchObservedAtImpact=%s touchAbsentAtImpact=%s remainingMs=%s touchCandidate=%s resolvedPendingTouch=%s",
        tostring(attack.attackType),
        tostring(attack.targetName),
        tostring(attack.targetUnitId),
        tostring(attack.abilityName),
        tostring(attack.abilityId),
        tostring(result),
        tostring(hitValue),
        tostring(attack.pair),
        tostring(attack.pieces),
        tostring(attack.hasFive),
        tostring(touchActive),
        tostring(not touchActive),
        tostring(GetTouchRemainingMs(target, nowMs)),
        tostring(attack.attackType == "light"),
        tostring(resolvedPendingTouch)
    ))
end

local function GetAverage(weightedMs)
    if requiredMs <= 0 then return 0 end
    return (tonumber(weightedMs) or 0) / requiredMs
end

local function BuildSummary(nowMs)
    nowMs = nowMs or GetNowMs()
    local durationMs = combatStartMs > 0 and math.max(0, nowMs - combatStartMs) or requiredMs
    local potential, effective, target = GetCurrentValues(nowMs)
    local summaryPieces = combatTouchPieces > 0 and combatTouchPieces or combatMaxPieces
    if summaryPieces <= 0 then summaryPieces = GetPieces() end
    local summaryTarget = combatTargetName
    if summaryTarget == "" and target then summaryTarget = target.name or "" end
    return {
        hasData = requiredMs > 0,
        durationMs = durationMs,
        requiredMs = requiredMs,
        pieces = summaryPieces,
        hasFivePieces = summaryPieces >= MAX_STACKS,
        relevant = combatRelevant,
        potential = potential,
        effective = effective,
        potentialAverage = GetAverage(potentialWeightedMs),
        effectiveAverage = GetAverage(effectiveWeightedMs),
        touchUptime = requiredMs > 0 and (touchActiveMs / requiredMs) * 100 or 0,
        potentialCapTime = requiredMs > 0 and (potentialCapMs / requiredMs) * 100 or 0,
        effectiveCapTime = requiredMs > 0 and (effectiveCapMs / requiredMs) * 100 or 0,
        remainingMs = GetTouchRemainingMs(target, nowMs),
        target = summaryTarget,
        stackSource = combatUsedLibCombat and "libcombat" or "fallback",
        touchPair = combatTouchPair,
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

    local potential, effective, target, stackSource = GetCurrentValues(nowMs)
    local pieces = GetPieces()
    requiredMs = requiredMs + deltaMs
    potentialWeightedMs = potentialWeightedMs + (potential * deltaMs)
    effectiveWeightedMs = effectiveWeightedMs + (effective * deltaMs)
    if target and IsTouchActive(target, nowMs) then
        touchActiveMs = touchActiveMs + deltaMs
    end
    if potential >= MAX_STACKS then potentialCapMs = potentialCapMs + deltaMs end
    if effective >= MAX_STACKS then effectiveCapMs = effectiveCapMs + deltaMs end
    combatMaxPieces = math.max(combatMaxPieces, pieces)
    if target and target.name and target.name ~= "" then combatTargetName = target.name end
    if stackSource == "libcombat" then combatUsedLibCombat = true end

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
    if GetMode() == MODE_OFF
        or not lastCombatSummary
        or not lastCombatSummary.hasData
        or not lastCombatSummary.relevant then
        return nil
    end
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
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
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
        if EZOMetter_WindowStyle.ApplyBackdropStyle then
            EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
            return
        end
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
        return control.ezomMoveEnabled == true
    end, SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetCenterColor(0, 0, 0, 0.86)
    backdrop:SetEdgeColor(0.95, 0.78, 0.15, 1)
    backdrop:SetEdgeTexture("", 1, 1, 1)

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

local function SetMarkerHidden(reason)
    if marker and markerVisible then
        marker:SetHidden(true)
        markerVisible = false
    end

    local state = "hidden:" .. tostring(reason or "unknown")
    if markerDebugState ~= state then
        markerDebugState = state
        DebugLog("target marker hidden reason=" .. tostring(reason or "unknown"))
    end
end

local function EnsureMarker()
    if marker then return marker end

    local wm = WINDOW_MANAGER
    markerRenderControl = wm:CreateControl(MARKER_RENDER_NAME, GuiRoot, CT_CONTROL)
    markerRenderControl:SetAnchorFill(GuiRoot)
    markerRenderControl:Create3DRenderSpace()
    markerRenderControl:SetHidden(true)

    markerWindow = wm:CreateTopLevelWindow(MARKER_WINDOW_NAME)
    markerWindow:SetAnchorFill(GuiRoot)
    markerWindow:SetMouseEnabled(false)
    markerWindow:SetDrawLayer(DL_OVERLAY)
    markerWindow:SetHidden(false)

    local icon = type(GetAbilityIcon) == "function" and GetAbilityIcon(ZEN_TOUCH_ID) or ""
    if not icon or icon == "" then icon = "/esoui/art/icons/icon_missing.dds" end

    marker = wm:CreateControl(MARKER_CONTROL_NAME, markerWindow, CT_TEXTURE)
    marker:SetAnchor(BOTTOM, markerWindow, CENTER, 0, 0)
    marker:SetDimensions(MARKER_ICON_SIZE, MARKER_ICON_SIZE)
    marker:SetTexture(icon)
    marker:SetColor(0.35, 1, 0.45, 1)
    marker:SetAlpha(0.95)
    marker:SetPixelRoundingEnabled(false)
    marker:SetHidden(true)

    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(markerWindow)
    end
    return marker
end

local function ReticleMatchesTarget(target)
    if not target
        or type(DoesUnitExist) ~= "function"
        or not DoesUnitExist("reticleover") then
        return false, "no-reticle-target"
    end

    local targetUnitId = tonumber(target.unitId) or 0
    local reticleUnitId = type(GetUnitId) == "function" and (tonumber(GetUnitId("reticleover")) or 0) or 0
    if targetUnitId > 0 and reticleUnitId > 0 then
        if targetUnitId == reticleUnitId then return true end
        return false, "different-unit-id"
    end

    local targetName = CleanName(target.name)
    local reticleName = type(GetUnitName) == "function" and CleanName(GetUnitName("reticleover")) or ""
    if targetName ~= "" and targetName == reticleName then return true end
    return false, "different-unit-name"
end

-- Camera projection follows the renderer used by EZOCustomSupportIcons.
local function GetMarkerCamera()
    if type(Set3DRenderSpaceToCurrentCamera) ~= "function"
        or type(GuiRender3DPositionToWorldPosition) ~= "function" then
        return nil
    end

    Set3DRenderSpaceToCurrentCamera(markerRenderControl:GetName())
    local cameraX, cameraY, cameraZ = GuiRender3DPositionToWorldPosition(markerRenderControl:Get3DRenderSpaceOrigin())
    local forwardX, forwardY, forwardZ = markerRenderControl:Get3DRenderSpaceForward()
    local rightX, rightY, rightZ = markerRenderControl:Get3DRenderSpaceRight()
    local upX, upY, upZ = markerRenderControl:Get3DRenderSpaceUp()
    local uiW, uiH = GuiRoot:GetDimensions()

    local camera = markerCamera
    camera.x, camera.y, camera.z = cameraX, cameraY, cameraZ
    camera.uiW, camera.uiH = uiW, uiH
    camera.i11 = -(upY * forwardZ - upZ * forwardY)
    camera.i12 = -(rightZ * forwardY - rightY * forwardZ)
    camera.i13 = -(rightY * upZ - rightZ * upY)
    camera.i21 = -(upZ * forwardX - upX * forwardZ)
    camera.i22 = -(rightX * forwardZ - rightZ * forwardX)
    camera.i23 = -(rightZ * upX - rightX * upZ)
    camera.i31 = -(upX * forwardY - upY * forwardX)
    camera.i32 = -(rightY * forwardX - rightX * forwardY)
    camera.i33 = -(rightX * upY - rightY * upX)
    camera.i41 = -(upZ * forwardY * cameraX + upY * forwardX * cameraZ + upX * forwardZ * cameraY - upX * forwardY * cameraZ - upY * forwardZ * cameraX - upZ * forwardX * cameraY)
    camera.i42 = -(rightX * forwardY * cameraZ + rightY * forwardZ * cameraX + rightZ * forwardX * cameraY - rightZ * forwardY * cameraX - rightY * forwardX * cameraZ - rightX * forwardZ * cameraY)
    camera.i43 = -(rightZ * upY * cameraX + rightY * upX * cameraZ + rightX * upZ * cameraY - rightX * upY * cameraZ - rightY * upZ * cameraX - rightZ * upX * cameraY)
    return camera
end

local function ProjectTargetMarker(target, camera)
    if type(GetUnitRawWorldPosition) ~= "function"
        or type(GetWorldDimensionsOfViewFrustumAtDepth) ~= "function" then
        return false, "projection-api-unavailable"
    end

    local _, worldX, worldY, worldZ = GetUnitRawWorldPosition("reticleover")
    worldX = tonumber(worldX) or 0
    worldY = tonumber(worldY) or 0
    worldZ = tonumber(worldZ) or 0
    if worldX == 0 and worldY == 0 and worldZ == 0 then
        return false, "world-position-unavailable"
    end
    worldY = worldY + MARKER_OFFSET_M * 100

    local screenX = worldX * camera.i11 + worldY * camera.i21 + worldZ * camera.i31 + camera.i41
    local screenY = worldX * camera.i12 + worldY * camera.i22 + worldZ * camera.i32 + camera.i42
    local screenZ = worldX * camera.i13 + worldY * camera.i23 + worldZ * camera.i33 + camera.i43
    if screenZ <= 0 then return false, "behind-camera" end

    local viewW, viewH = GetWorldDimensionsOfViewFrustumAtDepth(screenZ)
    if not viewW or not viewH or viewW == 0 or viewH == 0 then
        return false, "view-frustum-unavailable"
    end

    local uiX = screenX * camera.uiW / viewW
    local uiY = -screenY * camera.uiH / viewH
    local dx = worldX - camera.x
    local dy = worldY - camera.y
    local dz = worldZ - camera.z
    local distance = 1 + zo_sqrt(dx * dx + dy * dy + dz * dz)
    local scale = 1000 / distance
    if not markerVisible or not markerX or math.abs(markerX - uiX) > 0.5 or math.abs(markerY - uiY) > 0.5 then
        marker:ClearAnchors()
        marker:SetAnchor(BOTTOM, markerWindow, CENTER, uiX, uiY)
        markerX, markerY = uiX, uiY
    end
    if not markerVisible or not markerScale or math.abs(markerScale - scale) > 0.01 then
        marker:SetScale(scale)
        markerScale = scale
    end
    if not markerVisible then
        marker:SetHidden(false)
        markerVisible = true
    end

    local state = "visible:" .. tostring(target.unitId or target.name or "unknown")
    if markerDebugState ~= state then
        markerDebugState = state
        DebugLog(string.format(
            "target marker visible target=%s unitId=%s remainingMs=%s",
            tostring(target.name),
            tostring(target.unitId),
            tostring(GetTouchRemainingMs(target, GetNowMs()))
        ))
    end
    return true
end

local function UpdateTargetMarker()
    EnsureMarker()
    local nowMs = GetNowMs()
    local target = GetActiveTarget()
    if not CanShowHud() then
        SetMarkerHidden("hud-scene-hidden")
        return
    end
    if GetMode() == MODE_OFF then
        SetMarkerHidden("zen-off")
        return
    end
    if not IsTouchActive(target, nowMs) then
        SetMarkerHidden("touch-inactive")
        return
    end

    local matches, reason = ReticleMatchesTarget(target)
    if not matches then
        SetMarkerHidden(reason)
        return
    end

    local camera = GetMarkerCamera()
    if not camera then
        SetMarkerHidden("camera-unavailable")
        return
    end

    local visible, projectionReason = ProjectTargetMarker(target, camera)
    if not visible then
        SetMarkerHidden(projectionReason)
    end
end

local function RegisterMarkerUpdate()
    if markerUpdateRegistered then return end
    EnsureMarker()
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_ZenMarkerUpdate", MARKER_UPDATE_MS, UpdateTargetMarker)
    markerUpdateRegistered = true
end

local function UnregisterMarkerUpdate(reason)
    if markerUpdateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_ZenMarkerUpdate")
        markerUpdateRegistered = false
    end
    SetMarkerHidden(reason)
end

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function GetStatusColor(potential, effective, touchActive)
    if touchActive and effective >= MAX_STACKS then return 0.15, 1, 0.35 end
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
    local r, g, b = GetStatusColor(potential, effective, touchActive)
    local value = touchActive and effective or potential

    titleLabel:SetColor(r, g, b, 1)
    piecesLabel:SetColor(hasFive and 0.15 or 1, hasFive and 1 or 0.86, hasFive and 0.35 or 0.25, 1)
    potentialLabel:SetColor(r, g, b, 1)
    effectiveLabel:SetColor(touchActive and r or 0.7, touchActive and g or 0.7, touchActive and b or 0.7, 1)
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
    if isCombat and HasFivePieces() then
        combatRelevant = true
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
    local target = GetActiveTarget()
    local nowMs = GetNowMs()
    local touchActive = IsTouchActive(target, nowMs)
    if GetMode() ~= MODE_OFF and touchActive then
        RegisterMarkerUpdate()
        UpdateTargetMarker()
    else
        UnregisterMarkerUpdate(GetMode() == MODE_OFF and "zen-off" or "touch-inactive")
    end

    if IsHudUnlocked() or forceShow or IsEnabled() or touchActive then
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
    combatMaxPieces = 0
    combatTouchPieces = 0
    combatTouchPair = ""
    combatTargetName = ""
    combatUsedLibCombat = false
    recentAttacks = {}
    pendingTouchApplications = {}
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

    target.libCombatStacks = math.max(0, math.min(MAX_STACKS, tonumber(stacks) or 0))
    target.libCombatUpdatedMs = nowMs
    if isCombat then
        combatUsedLibCombat = true
        if target.name and target.name ~= "" then combatTargetName = target.name end
    end

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
    RefreshUpdateRegistration()
end

local function RegisterLibCombat()
    if libCombatRegistered or not HasLibCombatZen() then return end
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_EFFECTS_OUT, OnLibCombatEffectsOut, LIBCOMBAT_CALLBACK_NAME)
    libCombatRegistered = true
    DebugLog("LibCombat Z'en stack callback registered")
end

function RefreshDebugCombatRegistration()
    if IsDebugEnabled() then
        if debugCombatRegistered or not EVENT_COMBAT_EVENT then return end
        EVENT_MANAGER:RegisterForEvent(DEBUG_COMBAT_EVENT_NAME, EVENT_COMBAT_EVENT, OnDebugCombatEvent)
        if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ~= nil and COMBAT_UNIT_TYPE_PLAYER ~= nil then
            EVENT_MANAGER:AddFilterForEvent(
                DEBUG_COMBAT_EVENT_NAME,
                EVENT_COMBAT_EVENT,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
                COMBAT_UNIT_TYPE_PLAYER
            )
        end
        debugCombatRegistered = true
        DebugLog(string.format(
            "debug capture started touchAbilityId=%s correlationBeforeMs=%s correlationAfterMs=%s applicationAttack=light pair=%s pieces=%s hasFive=%s",
            tostring(ZEN_TOUCH_ID),
            tostring(ATTACK_CORRELATION_BEFORE_MS),
            tostring(ATTACK_CORRELATION_AFTER_MS),
            tostring(GetActiveWeaponPairName()),
            tostring(GetPieces()),
            tostring(HasFivePieces())
        ))
        return
    end

    if debugCombatRegistered then
        EVENT_MANAGER:UnregisterForEvent(DEBUG_COMBAT_EVENT_NAME, EVENT_COMBAT_EVENT)
        debugCombatRegistered = false
        recentAttacks = {}
        pendingTouchApplications = {}
    end
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if nowCombat then
        isCombat = true
        combatRelevant = false
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

local function OnEffectChanged(_, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, _iconName, _buffType, effectType, abilityType, _statusEffectType, unitName, unitId, abilityId, sourceType)
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if IsIgnoredUnitTag(unitTag) then return end

    abilityId = tonumber(abilityId) or 0
    if abilityId ~= ZEN_TOUCH_ID then
        if effectType and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
        if abilityType ~= ABILITY_TYPE_DAMAGE then return end
    end

    local nowMs = GetNowMs()
    local key = GetTargetKey(unitTag, unitName, unitId)
    local target = GetTarget(key, unitTag, unitName, unitId)
    if not target then return end

    local isGain = changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FULL_REFRESH
    local isFade = changeType == EFFECT_RESULT_FADED
    local endMs = (tonumber(endTime) or 0) * 1000

    if abilityId == ZEN_TOUCH_ID then
        local previousRemainingMs = GetTouchRemainingMs(target, nowMs)
        local isInitialApplication = isGain and previousRemainingMs <= 0
        if isGain then
            if endMs <= nowMs then endMs = nowMs + ZEN_TOUCH_FALLBACK_DURATION_MS end
            target.touchUntilMs = endMs
        elseif isFade then
            target.touchUntilMs = 0
            ClearPendingTouch(unitName, unitId)
        end

        if isInitialApplication then ScanEquipment() end
        local currentPair = GetActiveWeaponPairName()
        local currentPieces = GetPieces()
        if isInitialApplication then
            RecordTouchApplication(target, currentPieces, currentPair)
        end

        if IsDebugEnabled() then
            local attack = isInitialApplication and GetRecentLightAttack(unitName, unitId, nowMs) or nil
            local correlation = "not-applicable"
            if isInitialApplication and attack then
                correlation = "resolved-before"
                DebugLog(string.format(
                    "touch correlation resolved direction=before attack=light target=%s unitId=%s attackAgeMs=%s attackPair=%s attackPieces=%s attackHasFive=%s validApplication=%s",
                    tostring(target.name),
                    tostring(unitId),
                    tostring(nowMs - attack.timeMs),
                    tostring(attack.pair),
                    tostring(attack.pieces),
                    tostring(attack.hasFive),
                    tostring(attack.hasFive == true)
                ))
            elseif isInitialApplication and QueuePendingTouch(target, nowMs) then
                correlation = "pending-after"
            end
            DebugLog(string.format(
                "touch change=%s target=%s unitId=%s effect=%s(%s) stackCount=%s slot=%s sourceType=%s begin=%.3f end=%.3f durationMs=%s previousRemainingMs=%s initialApplication=%s currentPair=%s currentPieces=%s currentHasFive=%s correlation=%s correlatedLightAgeMs=%s",
                tostring(changeType),
                tostring(target.name),
                tostring(unitId),
                tostring(CleanName(effectName)),
                tostring(abilityId),
                tostring(stackCount),
                tostring(effectSlot),
                tostring(sourceType),
                tonumber(beginTime) or 0,
                tonumber(endTime) or 0,
                tostring(math.max(0, endMs - nowMs)),
                tostring(previousRemainingMs),
                tostring(isInitialApplication),
                tostring(currentPair),
                tostring(currentPieces),
                tostring(currentPieces >= MAX_STACKS),
                tostring(correlation),
                tostring(attack and (nowMs - attack.timeMs) or -1)
            ))
        end
        RefreshUpdateRegistration()
        return
    end

    local dotKey = GetEffectKey(effectSlot, abilityId)
    if isGain then
        if endMs <= nowMs then return end
        target.dots[dotKey] = {
            abilityId = abilityId,
            endMs = endMs,
        }
        if IsDebugEnabled() then
            DebugLog(string.format("dot gained target=%s ability=%s end=%s", tostring(target.name), tostring(abilityId), tostring(endMs)))
        end
    elseif isFade then
        target.dots[dotKey] = nil
        if IsDebugEnabled() then
            DebugLog(string.format("dot faded target=%s ability=%s", tostring(target.name), tostring(abilityId)))
        end
    end
end

RefreshEffectRegistration = function()
    local mode = GetMode()
    local shouldListen = mode ~= MODE_OFF and (mode == MODE_ON or currentSnapshot.hasSet == true)
    if shouldListen == effectEventsRegistered then return end

    local eventName = ADDON_NAME .. "_ZenEffects"
    if shouldListen then
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, OnEffectChanged)
        if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE ~= nil and COMBAT_UNIT_TYPE_PLAYER ~= nil then
            EVENT_MANAGER:AddFilterForEvent(
                eventName,
                EVENT_EFFECT_CHANGED,
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
                COMBAT_UNIT_TYPE_PLAYER
            )
        end
    else
        EVENT_MANAGER:UnregisterForEvent(eventName, EVENT_EFFECT_CHANGED)
        targets = {}
        pendingTouchApplications = {}
    end
    effectEventsRegistered = shouldListen
end

function Tracker.DebugScanReticle()
    if not IsDebugEnabled() then
        if EZOMetter.Print then EZOMetter.Print(GetString(EZOM_ZEN_DEBUG_DISABLED)) end
        return
    end

    ScanEquipment()
    if type(DoesUnitExist) ~= "function" or not DoesUnitExist("reticleover") then
        DebugLog(string.format(
            "reticle scan no-target pair=%s pieces=%s hasFive=%s",
            tostring(GetActiveWeaponPairName()),
            tostring(GetPieces()),
            tostring(HasFivePieces())
        ))
        if EZOMetter.Print then EZOMetter.Print(GetString(EZOM_ZEN_DEBUG_SCAN_DONE)) end
        return
    end

    local unitName = type(GetUnitName) == "function" and CleanName(GetUnitName("reticleover")) or ""
    local unitId = type(GetUnitId) == "function" and GetUnitId("reticleover") or 0
    local total = type(GetNumBuffs) == "function" and GetNumBuffs("reticleover") or 0
    local relevant = 0
    DebugLog(string.format(
        "reticle scan start target=%s unitId=%s buffs=%s pair=%s pieces=%s hasFive=%s",
        tostring(unitName),
        tostring(unitId),
        tostring(total),
        tostring(GetActiveWeaponPairName()),
        tostring(GetPieces()),
        tostring(HasFivePieces())
    ))

    if type(GetUnitBuffInfo) == "function" then
        for index = 1, total do
            local buffName, beginTime, endTime, effectSlot, stacks, _, _, effectType, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo("reticleover", index)
            abilityId = tonumber(abilityId) or 0
            if abilityId == ZEN_TOUCH_ID or (castByPlayer == true and abilityType == ABILITY_TYPE_DAMAGE) then
                relevant = relevant + 1
                DebugLog(string.format(
                    "reticle effect index=%s name=%s abilityId=%s touch=%s castByPlayer=%s stacks=%s slot=%s effectType=%s abilityType=%s begin=%.3f end=%.3f remainingMs=%s",
                    tostring(index),
                    tostring(CleanName(buffName)),
                    tostring(abilityId),
                    tostring(abilityId == ZEN_TOUCH_ID),
                    tostring(castByPlayer),
                    tostring(stacks),
                    tostring(effectSlot),
                    tostring(effectType),
                    tostring(abilityType),
                    tonumber(beginTime) or 0,
                    tonumber(endTime) or 0,
                    tostring(math.max(0, ((tonumber(endTime) or 0) * 1000) - GetNowMs()))
                ))
            end
        end
    end

    DebugLog(string.format("reticle scan end target=%s relevant=%s", tostring(unitName), tostring(relevant)))
    if EZOMetter.Print then EZOMetter.Print(GetString(EZOM_ZEN_DEBUG_SCAN_DONE)) end
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyBackdrop()
    SetMoveMode(IsHudUnlocked())
    RegisterLibCombat()
    ScanEquipment()
    RefreshEffectRegistration()
    RefreshDebugCombatRegistration()
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
    RefreshEffectRegistration()
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

    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            QueueEquipmentScan(0)
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZenWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            QueueEquipmentScan(WEAPON_SWAP_SCAN_DELAY_MS, true)
        end)
    end

    RegisterLibCombat()
    RefreshEffectRegistration()
    RefreshDebugCombatRegistration()
    RefreshUpdateRegistration()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

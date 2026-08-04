-- Roar of Alkosh tracker.
EZOMetter_Alkosh = EZOMetter_Alkosh or {}

local Tracker = EZOMetter_Alkosh
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterAlkoshTracker"
local ALERT_CONTROL_NAME = "EZOMetterAlkoshActivationAlert"
local UPDATE_INTERVAL_MS = 250
local EQUIPMENT_SCAN_INTERVAL_MS = 1000
local WIDTH = 300
local HEIGHT = 94
local ALERT_WIDTH = 240
local ALERT_HEIGHT = 58
local PADDING = 10
local ROW_HEIGHT = 18
local OFFER_CLOSE_GRACE_MS = 500
local ACTIVATION_MATCH_MS = 2200
local DIRECT_TIME_TOLERANCE_MS = 750
local PROC_DELAY_MS = 1000

local MODE_OFF = "off"
local MODE_WARN = "warn"
local MODE_CYCLE = "cycle"

local TARGET_TAGS = { "reticleover", "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }
local ALKOSH_ITEM_LINK = "|H1:item:73058:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local ALKOSH_DURATION_MS = 10000
local TIMING_DEBUFF_IDS = { [75753] = true, [120018] = true }
local OBSERVED_DEBUFF_IDS = { [75753] = true, [76667] = true, [120018] = true }

local ALKOSH_ALIASES = {
    "Roar of Alkosh",
    "Rugido de Alkosh",
    "Brullen von Alkosh",
    "Brüllen von Alkosh",
}

local control
local backdrop
local titleLabel
local equippedLabel
local bar
local barLabel
local stateLabel
local synergyLabel
local uptimeLabel
local efficiencyLabel
local alertControl
local alertBackdrop
local alertTitleLabel
local alertDetailLabel
local updateRegistered = false
local isCombat = false
local forceShow = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local activeFromMs = 0
local activeUntilMs = 0
local activeTarget = ""
local activeTimingEffects = {}
local lastDirectEffectEndMs = 0
local lastProcMs = nil
local lastProcTarget = ""
local combatStartMs = 0
local activeMs = 0
local requiredMs = 0
local lastSampleMs = 0
local possibleActiveFromMs = 0
local possibleActiveUntilMs = 0
local possibleLastProcMs = nil
local possibleActiveMs = 0
local lastRecordedProcMs = nil
local activeOffers = {}
local pendingClosedOffers = {}
local currentPrimaryKey = nil
local cycleHadWindowOffer = false
local combatStats = nil
local lastCombatSummary = nil
local combatRelevant = false
local IsHudUnlocked

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.alkosh = EZOMetter.sv.alkosh or {}
    return EZOMetter.sv.alkosh
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

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function GetWindowStartMs()
    local settings = GetSettings()
    return Clamp(settings and settings.windowStartSeconds, 4, 9) * 1000
end

local function GetWindowEndMs()
    local settings = GetSettings()
    local startMs = GetWindowStartMs()
    return math.max(startMs + 500, Clamp(settings and settings.windowEndSeconds, 5, 10) * 1000)
end

local function IsActive(nowMs)
    return (tonumber(activeUntilMs) or 0) > (nowMs or GetNowMs())
end

local function GetRemainingMs(nowMs)
    return math.max(0, (tonumber(activeUntilMs) or 0) - (nowMs or GetNowMs()))
end

local function GetMode()
    local settings = GetSettings()
    local mode = settings and settings.mode or MODE_OFF
    if mode == "block" then
        mode = MODE_CYCLE
    end
    if mode ~= MODE_WARN and mode ~= MODE_CYCLE then
        return MODE_OFF
    end
    return mode
end

local function IsEnabled()
    return GetMode() ~= MODE_OFF
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
        EZOMetter.DebugLog("[Alkosh] " .. tostring(message))
    end
end

local function EnsureDebuffIds()
    if EZOMetter_DDEffectiveStats and EZOMetter_DDEffectiveStats.GetModifierAbilityIds then
        for _, abilityId in ipairs(EZOMetter_DDEffectiveStats.GetModifierAbilityIds("alkosh") or {}) do
            OBSERVED_DEBUFF_IDS[tonumber(abilityId) or 0] = true
        end
    end
end

local function IsAlkoshSet(setName, _setId)
    return EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.NameMatches(setName, ALKOSH_ALIASES)
end

local function ScanEquipment()
    currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
    if not EZOMetter_EquipmentSets then
        lastEquipmentScanMs = GetNowMs()
        return
    end

    if EZOMetter_EquipmentSets.GetSetSnapshotFromItemLink then
        local itemLinkSnapshot = EZOMetter_EquipmentSets.GetSetSnapshotFromItemLink(ALKOSH_ITEM_LINK)
        if itemLinkSnapshot and itemLinkSnapshot.hasSet then
            currentSnapshot = itemLinkSnapshot
            lastEquipmentScanMs = GetNowMs()
            return
        end
    end

    if EZOMetter_EquipmentSets.GetWornSetSnapshot then
        currentSnapshot = EZOMetter_EquipmentSets.GetWornSetSnapshot(IsAlkoshSet)
    end
    lastEquipmentScanMs = GetNowMs()
end

local function IsEquipped()
    return currentSnapshot and currentSnapshot.hasSet == true and (tonumber(currentSnapshot.numEquipped) or 0) >= 5
end

local function HasMinimumPieces()
    return currentSnapshot and currentSnapshot.hasSet == true and (tonumber(currentSnapshot.numEquipped) or 0) >= 3
end

local function CleanName(name)
    name = tostring(name or "")
    name = string.gsub(name, "%^.*", "")
    if type(zo_strformat) == "function" and SI_UNIT_NAME then
        name = zo_strformat(SI_UNIT_NAME, name)
    end
    return name
end

local function CanReadTarget(unitTag)
    if type(DoesUnitExist) ~= "function" or not DoesUnitExist(unitTag) then return false end
    if unitTag == "reticleover" and type(IsUnitAttackable) == "function" then
        return IsUnitAttackable(unitTag)
    end
    return string.sub(unitTag, 1, 4) == "boss"
end

local function ReadTargetName(unitTag)
    if type(GetUnitName) ~= "function" or not unitTag then return "" end
    if type(DoesUnitExist) == "function" and not DoesUnitExist(unitTag) then return "" end
    return CleanName(GetUnitName(unitTag))
end

local function BuildOfferKey(abilityId, name, icon)
    abilityId = tonumber(abilityId) or 0
    if abilityId > 0 then
        return "id:" .. tostring(abilityId)
    end
    return "name:" .. string.lower(tostring(name or "")) .. "|" .. tostring(icon or "")
end

local function ReadAvailableSynergies()
    local offers = {}
    if type(GetNumberOfAvailableSynergies) == "function" and type(GetSynergyInfoAtIndex) == "function" then
        local count = tonumber(GetNumberOfAvailableSynergies()) or 0
        for index = 1, count do
            local name, icon, prompt, priority, abilityId, canBeUsed = GetSynergyInfoAtIndex(index)
            if canBeUsed == true and name and name ~= "" then
                local key = BuildOfferKey(abilityId, name, icon)
                offers[key] = {
                    key = key,
                    abilityId = tonumber(abilityId) or 0,
                    name = tostring(name),
                    icon = icon,
                    prompt = prompt,
                    priority = tonumber(priority) or 0,
                }
            end
        end
    elseif type(GetCurrentSynergyInfo) == "function" then
        local hasSynergy, name, icon, prompt, priority = GetCurrentSynergyInfo()
        if hasSynergy and name and name ~= "" then
            local key = BuildOfferKey(0, name, icon)
            offers[key] = {
                key = key,
                abilityId = 0,
                name = tostring(name),
                icon = icon,
                prompt = prompt,
                priority = tonumber(priority) or 0,
            }
        end
    elseif type(GetSynergyInfo) == "function" then
        local name, icon, priority, prompt = GetSynergyInfo()
        if name and name ~= "" then
            local key = BuildOfferKey(0, name, icon)
            offers[key] = {
                key = key,
                abilityId = 0,
                name = tostring(name),
                icon = icon,
                prompt = prompt,
                priority = tonumber(priority) or 0,
            }
        end
    end
    return offers
end

local function ReadPrimarySynergyKey(offers)
    local name
    local icon
    if type(GetCurrentSynergyInfo) == "function" then
        local hasSynergy
        hasSynergy, name, icon = GetCurrentSynergyInfo()
        if not hasSynergy then return nil end
    elseif type(GetSynergyInfo) == "function" then
        name, icon = GetSynergyInfo()
    end
    if not name or name == "" then return nil end

    local cleanName = tostring(name)
    for key, offer in pairs(offers) do
        if offer.name == cleanName and (not icon or icon == "" or offer.icon == icon) then
            return key
        end
    end
    return BuildOfferKey(0, cleanName, icon)
end

local function HasUsableSynergy()
    return forceShow or next(activeOffers) ~= nil
end

local function CreateCombatStats()
    return {
        offered = 0,
        availableInWindow = 0,
        used = 0,
        usedInWindow = 0,
        usedOutsideWindow = 0,
        missedInWindow = 0,
        types = {},
    }
end

local function GetTypeStats(offer)
    if not combatStats then return nil end
    local key = offer and offer.key or "unknown"
    local stats = combatStats.types[key]
    if not stats then
        stats = {
            abilityId = offer and offer.abilityId or 0,
            name = offer and offer.name or GetString(EZOM_ALKOSH_UNKNOWN_SYNERGY),
            offered = 0,
            availableInWindow = 0,
            used = 0,
            usedInWindow = 0,
            usedOutsideWindow = 0,
            missedInWindow = 0,
        }
        combatStats.types[key] = stats
    end
    return stats
end

local function AddStat(offer, field)
    if not combatStats then return end
    combatStats[field] = (combatStats[field] or 0) + 1
    local typeStats = GetTypeStats(offer)
    typeStats[field] = (typeStats[field] or 0) + 1
end

local function IsInWindowForProc(procMs, nowMs)
    if not procMs then return false end
    local elapsedMs = (nowMs or GetNowMs()) - procMs
    return elapsedMs >= GetWindowStartMs() and elapsedMs <= GetWindowEndMs()
end

local function ClampKnownEndTime(nowMs, untilMs)
    nowMs = nowMs or GetNowMs()
    untilMs = tonumber(untilMs) or 0
    if untilMs <= nowMs then return 0 end
    return math.min(untilMs, nowMs + ALKOSH_DURATION_MS)
end

local RecordActivation

local function BuildTimingEffectKey(unitTag, unitId, abilityId)
    unitId = tonumber(unitId) or 0
    if unitId > 0 then
        return string.format("id:%s:%s", tostring(unitId), tostring(abilityId))
    end
    return string.format("tag:%s:%s", tostring(unitTag or ""), tostring(abilityId))
end

local function NormalizeEffectStartMs(nowMs, startMs, endMs)
    startMs = tonumber(startMs) or 0
    if startMs <= 0
        or startMs >= endMs
        or startMs > nowMs + DIRECT_TIME_TOLERANCE_MS
        or endMs - startMs > ALKOSH_DURATION_MS + DIRECT_TIME_TOLERANCE_MS then
        return math.max(0, endMs - ALKOSH_DURATION_MS)
    end
    return startMs
end

local function ReconcileTimingEffects(nowMs)
    nowMs = nowMs or GetNowMs()
    local bestEndMs = 0
    local bestStartMs = 0
    local bestTarget = ""

    for key, effect in pairs(activeTimingEffects) do
        if effect.endMs <= nowMs then
            activeTimingEffects[key] = nil
        elseif effect.endMs > bestEndMs then
            bestEndMs = effect.endMs
            bestStartMs = effect.startMs
            bestTarget = effect.target
        end
    end

    if bestEndMs > 0 then
        if activeUntilMs <= nowMs then
            activeFromMs = math.max(combatStartMs, bestStartMs)
        end
        activeUntilMs = bestEndMs
        if bestTarget ~= "" then activeTarget = bestTarget end
    else
        activeFromMs = 0
        activeUntilMs = 0
    end
end

local function ObserveTimingEffect(nowMs, key, targetName, startMs, endMs, source)
    nowMs = nowMs or GetNowMs()
    endMs = ClampKnownEndTime(nowMs, endMs)
    if endMs <= 0 then return false end

    startMs = NormalizeEffectStartMs(nowMs, startMs, endMs)
    targetName = CleanName(targetName)
    activeTimingEffects[key] = {
        startMs = startMs,
        endMs = endMs,
        target = targetName,
    }

    local isNewProc = not lastRecordedProcMs
        or endMs > lastDirectEffectEndMs + DIRECT_TIME_TOLERANCE_MS
    lastDirectEffectEndMs = math.max(lastDirectEffectEndMs, endMs)

    if isNewProc then
        if isCombat and startMs >= combatStartMs then
            RecordActivation(startMs, nowMs, source)
        else
            lastRecordedProcMs = startMs
            cycleHadWindowOffer = false
        end
        lastProcMs = startMs
    end
    lastProcTarget = targetName
    if targetName ~= "" then activeTarget = targetName end
    if activeUntilMs <= nowMs then
        activeFromMs = math.max(combatStartMs, startMs)
    end
    activeUntilMs = math.max(activeUntilMs, endMs)

    DebugLog(string.format(
        "direct timing source=%s start=%s end=%s target=%s newProc=%s",
        tostring(source),
        tostring(startMs),
        tostring(endMs),
        tostring(targetName),
        tostring(isNewProc)
    ))
    return isNewProc
end

local function ScanTargetEffects()
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return end

    local nowMs = GetNowMs()
    for _, unitTag in ipairs(TARGET_TAGS) do
        if CanReadTarget(unitTag) then
            for index = 1, GetNumBuffs(unitTag) do
                local _, startTime, endTime, _, _, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(unitTag, index)
                abilityId = tonumber(abilityId) or 0
                if TIMING_DEBUFF_IDS[abilityId] and castByPlayer == true then
                    local unitId = type(GetUnitId) == "function" and GetUnitId(unitTag) or 0
                    ObserveTimingEffect(
                        nowMs,
                        BuildTimingEffectKey(unitTag, unitId, abilityId),
                        ReadTargetName(unitTag),
                        (tonumber(startTime) or 0) * 1000,
                        (tonumber(endTime) or 0) * 1000,
                        "scan"
                    )
                end
            end
        end
    end
    ReconcileTimingEffects(nowMs)
end

local function MarkOfferAvailableInWindow(offer)
    if not offer then return end
    cycleHadWindowOffer = true
    if offer.availableInWindow then return end
    offer.availableInWindow = true
    AddStat(offer, "availableInWindow")
end

local function ResolvePendingOffers(nowMs)
    for index = #pendingClosedOffers, 1, -1 do
        local offer = pendingClosedOffers[index]
        if offer.resolved then
            table.remove(pendingClosedOffers, index)
        elseif nowMs - offer.closedMs >= ACTIVATION_MATCH_MS then
            if offer.availableInWindow then
                AddStat(offer, "missedInWindow")
            end
            table.remove(pendingClosedOffers, index)
        end
    end
end

local function ScanSynergyOffers(nowMs)
    nowMs = nowMs or GetNowMs()
    local snapshot = ReadAvailableSynergies()
    local previousPrimaryKey = currentPrimaryKey
    currentPrimaryKey = ReadPrimarySynergyKey(snapshot)
    local seen = {}

    for key, data in pairs(snapshot) do
        seen[key] = true
        local offer = activeOffers[key]
        if not offer then
            offer = {
                key = key,
                abilityId = data.abilityId,
                name = data.name,
                icon = data.icon,
                priority = data.priority,
                firstSeenMs = nowMs,
                lastSeenMs = nowMs,
                availableInWindow = false,
                potentialUsed = false,
            }
            activeOffers[key] = offer
            if isCombat then
                AddStat(offer, "offered")
            end
            DebugLog(string.format("synergy offered id=%s name=%s", tostring(offer.abilityId), tostring(offer.name)))
        else
            offer.lastSeenMs = nowMs
            offer.missingSinceMs = nil
            offer.name = data.name
            offer.icon = data.icon
            offer.priority = data.priority
        end
        offer.isPrimary = key == currentPrimaryKey
    end

    local toClose = {}
    for key, offer in pairs(activeOffers) do
        if not seen[key] then
            offer.missingSinceMs = offer.missingSinceMs or nowMs
            if nowMs - offer.missingSinceMs >= OFFER_CLOSE_GRACE_MS then
                table.insert(toClose, key)
            end
        end
    end

    for _, key in ipairs(toClose) do
        local offer = activeOffers[key]
        if offer then
            offer.closedMs = offer.missingSinceMs or nowMs
            offer.primaryAtClose = offer.isPrimary or key == previousPrimaryKey
            offer.isPrimary = false
            table.insert(pendingClosedOffers, offer)
            activeOffers[key] = nil
            DebugLog(string.format("synergy closed id=%s name=%s", tostring(offer.abilityId), tostring(offer.name)))
        end
    end

    if isCombat and lastRecordedProcMs and IsInWindowForProc(lastRecordedProcMs, nowMs) then
        for _, offer in pairs(activeOffers) do
            MarkOfferAvailableInWindow(offer)
        end
    end
    ResolvePendingOffers(nowMs)
end

local function FindPotentialOffer()
    local primary = currentPrimaryKey and activeOffers[currentPrimaryKey] or nil
    if primary and not primary.potentialUsed and not primary.missingSinceMs then
        return primary
    end
    for _, offer in pairs(activeOffers) do
        if not offer.potentialUsed and not offer.missingSinceMs then
            return offer
        end
    end
    return nil
end

local function SimulatePotentialActivation(nowMs)
    if not IsEquipped() then return end
    local shouldUse = possibleActiveUntilMs <= nowMs
    if not shouldUse and possibleLastProcMs then
        shouldUse = IsInWindowForProc(possibleLastProcMs, nowMs)
    end
    if not shouldUse then return end

    local offer = FindPotentialOffer()
    if not offer then return end
    offer.potentialUsed = true
    local procMs = nowMs + PROC_DELAY_MS
    if possibleActiveUntilMs <= procMs then
        possibleActiveFromMs = procMs
    end
    possibleActiveUntilMs = math.max(possibleActiveUntilMs, procMs + ALKOSH_DURATION_MS)
    possibleLastProcMs = procMs
end

local function FindActivationOffer(nowMs)
    local best
    local bestScore
    for _, offer in ipairs(pendingClosedOffers) do
        local ageMs = nowMs - offer.closedMs
        if not offer.resolved and ageMs >= 0 and ageMs <= ACTIVATION_MATCH_MS then
            local score = math.abs(ageMs - PROC_DELAY_MS)
            if offer.primaryAtClose then score = score - ACTIVATION_MATCH_MS end
            if not bestScore or score < bestScore then
                best = offer
                bestScore = score
            end
        end
    end
    if best then return best end
    if currentPrimaryKey and activeOffers[currentPrimaryKey] then
        return activeOffers[currentPrimaryKey]
    end
    return nil
end

RecordActivation = function(procMs, observedMs, source)
    if not isCombat then return end
    procMs = tonumber(procMs) or GetNowMs()
    observedMs = tonumber(observedMs) or procMs
    local previousProcMs = lastRecordedProcMs
    local activationMs = math.max(combatStartMs, procMs - PROC_DELAY_MS)
    local offer = FindActivationOffer(observedMs)
    AddStat(offer, "used")

    if previousProcMs then
        if IsInWindowForProc(previousProcMs, activationMs) then
            AddStat(offer, "usedInWindow")
        else
            AddStat(offer, "usedOutsideWindow")
        end
    end

    if offer then
        offer.resolved = true
        offer.potentialUsed = true
    end
    if possibleActiveUntilMs <= procMs then
        possibleActiveFromMs = procMs
    end
    possibleActiveUntilMs = math.max(possibleActiveUntilMs, procMs + ALKOSH_DURATION_MS)
    possibleLastProcMs = procMs
    lastRecordedProcMs = procMs
    cycleHadWindowOffer = false
    DebugLog(string.format(
        "synergy used source=%s id=%s name=%s inWindow=%s",
        tostring(source or "direct"),
        tostring(offer and offer.abilityId or 0),
        tostring(offer and offer.name or GetString(EZOM_ALKOSH_UNKNOWN_SYNERGY)),
        tostring(previousProcMs and IsInWindowForProc(previousProcMs, activationMs) or false)
    ))
end

local function SampleCombat(nowMs)
    if not isCombat then return end
    nowMs = nowMs or GetNowMs()
    local deltaMs = nowMs - (lastSampleMs or nowMs)
    if deltaMs <= 0 then
        lastSampleMs = nowMs
        return
    end

    requiredMs = requiredMs + deltaMs
    if activeUntilMs > lastSampleMs then
        local actualStartMs = math.max(lastSampleMs, activeFromMs)
        local actualEndMs = math.min(nowMs, activeUntilMs)
        activeMs = activeMs + math.max(0, actualEndMs - actualStartMs)
    end
    if possibleActiveUntilMs > lastSampleMs then
        local possibleStartMs = math.max(lastSampleMs, possibleActiveFromMs)
        local possibleEndMs = math.min(nowMs, possibleActiveUntilMs)
        possibleActiveMs = possibleActiveMs + math.max(0, possibleEndMs - possibleStartMs)
    end
    lastSampleMs = nowMs
    SimulatePotentialActivation(nowMs)
end

local function GetCurrentUptime()
    return requiredMs > 0 and (activeMs / requiredMs) * 100 or 0
end

local function GetCurrentPossibleUptime()
    return requiredMs > 0 and (possibleActiveMs / requiredMs) * 100 or 0
end

local function GetCurrentEfficiency()
    return possibleActiveMs > 0 and math.min(100, (activeMs / possibleActiveMs) * 100) or 0
end

local function GetDisplayUptime()
    if isCombat or forceShow then return GetCurrentUptime() end
    if lastCombatSummary and lastCombatSummary.hasData then
        return lastCombatSummary.uptime or 0
    end
    return GetCurrentUptime()
end

local function GetDisplayEfficiency()
    if isCombat or forceShow then return GetCurrentEfficiency() end
    if lastCombatSummary and lastCombatSummary.hasData then
        return lastCombatSummary.efficiency or 0
    end
    return GetCurrentEfficiency()
end

local function CopyCombatStats()
    local copy = CreateCombatStats()
    if not combatStats then return copy end
    for key, value in pairs(combatStats) do
        if key ~= "types" then
            copy[key] = value
        end
    end
    for key, typeStats in pairs(combatStats.types or {}) do
        copy.types[key] = {}
        for field, value in pairs(typeStats) do
            copy.types[key][field] = value
        end
    end
    return copy
end

local function BuildSummary(nowMs)
    nowMs = nowMs or GetNowMs()
    local durationMs = combatStartMs > 0 and math.max(0, nowMs - combatStartMs) or requiredMs
    return {
        hasData = requiredMs > 0 or lastProcMs ~= nil,
        durationMs = durationMs,
        requiredMs = requiredMs,
        activeMs = activeMs,
        possibleMs = possibleActiveMs,
        uptime = GetCurrentUptime(),
        possibleUptime = GetCurrentPossibleUptime(),
        efficiency = GetCurrentEfficiency(),
        equipped = IsEquipped(),
        relevant = combatRelevant,
        lastProcAgoMs = lastProcMs and math.max(0, nowMs - lastProcMs) or nil,
        lastTarget = activeTarget ~= "" and activeTarget or lastProcTarget,
        remainingMs = GetRemainingMs(nowMs),
        stats = CopyCombatStats(),
    }
end

local function BuildSynergyTypeLines(stats)
    local typeList = {}
    for _, typeStats in pairs(stats and stats.types or {}) do
        table.insert(typeList, typeStats)
    end
    table.sort(typeList, function(left, right)
        return string.lower(left.name or "") < string.lower(right.name or "")
    end)

    local lines = {}
    for _, typeStats in ipairs(typeList) do
        table.insert(lines, zo_strformat(
            GetString(EZOM_ALKOSH_SYNERGY_TYPE_LINE),
            typeStats.name or GetString(EZOM_ALKOSH_UNKNOWN_SYNERGY),
            typeStats.offered or 0,
            typeStats.availableInWindow or 0,
            typeStats.used or 0,
            typeStats.usedInWindow or 0,
            typeStats.usedOutsideWindow or 0,
            typeStats.missedInWindow or 0
        ))
    end
    return lines
end

local function BuildTooltipText()
    local summary = isCombat and BuildSummary(GetNowMs()) or lastCombatSummary
    if not summary or not summary.hasData then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        GetString(EZOM_ALKOSH_SUMMARY_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(summary.durationMs),
        GetString(EZOM_ALKOSH_EQUIPPED) .. ": " .. (summary.equipped and GetString(EZOM_YES) or GetString(EZOM_NO)),
        GetString(EZOM_ALKOSH_COMBAT_UPTIME) .. ": " .. FormatPercent(summary.uptime),
        GetString(EZOM_ALKOSH_EFFICIENCY) .. ": " .. FormatPercent(summary.efficiency),
        GetString(EZOM_ALKOSH_REMAINING) .. ": " .. FormatSeconds(summary.remainingMs),
        GetString(EZOM_ALKOSH_TARGET) .. ": " .. ((summary.lastTarget and summary.lastTarget ~= "") and summary.lastTarget or GetString(EZOM_SUMMARY_NOT_APPLICABLE)),
    }

    if summary.lastProcAgoMs then
        table.insert(lines, GetString(EZOM_ALKOSH_LAST_PROC) .. ": " .. FormatSeconds(summary.lastProcAgoMs) .. " " .. GetString(EZOM_ALKOSH_AGO))
    else
        table.insert(lines, GetString(EZOM_ALKOSH_LAST_PROC) .. ": " .. GetString(EZOM_SUMMARY_NOT_APPLICABLE))
    end

    local stats = summary.stats or CreateCombatStats()
    table.insert(lines, GetString(EZOM_ALKOSH_SYNERGY_TOTALS))
    table.insert(lines, zo_strformat(
        GetString(EZOM_ALKOSH_SYNERGY_TOTALS_LINE),
        stats.offered or 0,
        stats.availableInWindow or 0,
        stats.used or 0,
        stats.usedInWindow or 0,
        stats.usedOutsideWindow or 0,
        stats.missedInWindow or 0
    ))
    for _, line in ipairs(BuildSynergyTypeLines(stats)) do
        table.insert(lines, line)
    end

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
    settings.x = control:GetLeft() - GuiRoot:GetWidth() / 2 + control:GetWidth() / 2
    settings.y = control:GetTop() - GuiRoot:GetHeight() / 2 + control:GetHeight() / 2
end

local function SaveAlertPosition()
    local settings = GetSettings()
    if not settings or not alertControl then return end
    settings.alertX = alertControl:GetLeft() - GuiRoot:GetWidth() / 2 + alertControl:GetWidth() / 2
    settings.alertY = alertControl:GetTop() - GuiRoot:GetHeight() / 2 + alertControl:GetHeight() / 2
end

local function ApplyPosition()
    if not control then return end
    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 260, tonumber(settings.y) or -160)
end

local function ApplyAlertPosition()
    if not alertControl then return end
    local settings = GetSettings() or {}
    alertControl:ClearAnchors()
    alertControl:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.alertX) or 0, tonumber(settings.alertY) or -220)
end

local function SetMoveMode(enabled)
    if not control then return end
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
    if alertControl then
        alertControl.ezomMoveEnabled = enabled == true
        alertControl:SetMouseEnabled(enabled == true)
        if alertControl.ezomPrimaryDragRefresh then alertControl.ezomPrimaryDragRefresh() end
    end
end

local function ApplyStyle()
    local panelStyleApplied = false
    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control)
        if EZOMetter_WindowStyle.ApplyBackdropStyle then
            EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
            panelStyleApplied = true
        end
    end
    local settings = GetSettings() or {}
    if backdrop and not panelStyleApplied then
        local opacity = Clamp(tonumber(settings.backgroundOpacity) or 86, 0, 100)
        backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
        if settings.showBorder == false then
            backdrop:SetEdgeColor(0, 0, 0, 0)
        else
            backdrop:SetEdgeColor(0.65, 0.25, 1, 0.95)
        end
    end

    if alertControl and alertControl.SetScale then
        alertControl:SetScale(Clamp(tonumber(settings.alertSize) or 100, 70, 180) / 100)
    end
    if alertBackdrop then
        local alertOpacity = Clamp(tonumber(settings.alertBackgroundOpacity) or 72, 0, 100)
        alertBackdrop:SetCenterColor(0.12, 0.01, 0.005, alertOpacity / 100)
        if settings.alertShowBorder == false then
            alertBackdrop:SetEdgeColor(0, 0, 0, 0)
        else
            alertBackdrop:SetEdgeColor(1, 0.18, 0.08, 1)
        end
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
    EZOMetter_VisualContext.BindPrimaryDrag(control, function()
        return control.ezomMoveEnabled == true
    end, SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("", 1, 1, 1)

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 8)
    titleLabel:SetDimensions(92, ROW_HEIGHT)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetText(GetString(EZOM_ALKOSH_TITLE))

    equippedLabel = wm:CreateControl(CONTROL_NAME .. "Equipped", control, CT_LABEL)
    equippedLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 8)
    equippedLabel:SetDimensions(140, ROW_HEIGHT)
    equippedLabel:SetFont("ZoFontGame")
    equippedLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    bar = wm:CreateControl(CONTROL_NAME .. "Bar", control, CT_STATUSBAR)
    bar:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 3)
    bar:SetDimensions(WIDTH - (PADDING * 2), 14)
    bar:SetMinMax(0, ALKOSH_DURATION_MS)
    bar:SetValue(0)

    barLabel = wm:CreateControl(CONTROL_NAME .. "BarLabel", control, CT_LABEL)
    barLabel:SetAnchorFill(bar)
    barLabel:SetFont("ZoFontGameSmall")
    barLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    barLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    stateLabel = wm:CreateControl(CONTROL_NAME .. "State", control, CT_LABEL)
    stateLabel:SetAnchor(TOPLEFT, bar, BOTTOMLEFT, 0, 3)
    stateLabel:SetDimensions(118, ROW_HEIGHT)
    stateLabel:SetFont("ZoFontGame")

    synergyLabel = wm:CreateControl(CONTROL_NAME .. "Synergy", control, CT_LABEL)
    synergyLabel:SetAnchor(TOPRIGHT, bar, BOTTOMRIGHT, 0, 3)
    synergyLabel:SetDimensions(156, ROW_HEIGHT)
    synergyLabel:SetFont("ZoFontGame")
    synergyLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    synergyLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    synergyLabel:SetMaxLineCount(1)

    uptimeLabel = wm:CreateControl(CONTROL_NAME .. "Uptime", control, CT_LABEL)
    uptimeLabel:SetAnchor(TOPLEFT, stateLabel, BOTTOMLEFT, 0, 2)
    uptimeLabel:SetDimensions(132, ROW_HEIGHT)
    uptimeLabel:SetFont("ZoFontGame")

    efficiencyLabel = wm:CreateControl(CONTROL_NAME .. "Efficiency", control, CT_LABEL)
    efficiencyLabel:SetAnchor(TOPRIGHT, synergyLabel, BOTTOMRIGHT, 0, 2)
    efficiencyLabel:SetDimensions(142, ROW_HEIGHT)
    efficiencyLabel:SetFont("ZoFontGame")
    efficiencyLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    alertControl = wm:CreateTopLevelWindow(ALERT_CONTROL_NAME)
    alertControl:SetDimensions(ALERT_WIDTH, ALERT_HEIGHT)
    alertControl:SetClampedToScreen(true)
    alertControl:SetDrawTier(DT_HIGH)
    alertControl:SetHidden(true)
    EZOMetter_VisualContext.BindPrimaryDrag(alertControl, function()
        return alertControl.ezomMoveEnabled == true
    end, SaveAlertPosition)

    alertBackdrop = wm:CreateControl(ALERT_CONTROL_NAME .. "Backdrop", alertControl, CT_BACKDROP)
    alertBackdrop:SetAnchorFill(alertControl)
    alertBackdrop:SetEdgeTexture("", 2, 2, 2)

    alertTitleLabel = wm:CreateControl(ALERT_CONTROL_NAME .. "Title", alertControl, CT_LABEL)
    alertTitleLabel:SetAnchor(TOPLEFT, alertControl, TOPLEFT, 8, 6)
    alertTitleLabel:SetAnchor(TOPRIGHT, alertControl, TOPRIGHT, -8, 6)
    alertTitleLabel:SetHeight(26)
    alertTitleLabel:SetFont("ZoFontWinH2")
    alertTitleLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertTitleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    alertTitleLabel:SetColor(1, 0.24, 0.08, 1)
    alertTitleLabel:SetText(GetString(EZOM_ALKOSH_ALERT_ACTIVATE))
    alertTitleLabel:SetMouseEnabled(false)

    alertDetailLabel = wm:CreateControl(ALERT_CONTROL_NAME .. "Detail", alertControl, CT_LABEL)
    alertDetailLabel:SetAnchor(TOPLEFT, alertTitleLabel, BOTTOMLEFT, 0, 0)
    alertDetailLabel:SetAnchor(TOPRIGHT, alertTitleLabel, BOTTOMRIGHT, 0, 0)
    alertDetailLabel:SetHeight(18)
    alertDetailLabel:SetFont("ZoFontGameSmall")
    alertDetailLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    alertDetailLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    alertDetailLabel:SetColor(1, 0.82, 0.3, 1)
    alertDetailLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    alertDetailLabel:SetMaxLineCount(1)
    alertDetailLabel:SetMouseEnabled(false)

    ApplyPosition()
    ApplyAlertPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
        EZOMetter_VisualContext.AddHudFragment(alertControl)
    end
    return control
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function GetPrimaryOffer()
    if currentPrimaryKey and activeOffers[currentPrimaryKey] then
        return activeOffers[currentPrimaryKey]
    end
    local _, offer = next(activeOffers)
    return offer
end

local function GetCycleVisualState(nowMs)
    if not isCombat and not forceShow then
        return GetString(EZOM_ALKOSH_STATE_OUT_OF_COMBAT), 0.55, 0.55, 0.55, 0
    end

    if GetMode() == MODE_WARN then
        local remainingMs = GetRemainingMs(nowMs)
        if IsActive(nowMs) then
            return GetString(EZOM_ALKOSH_STATE_ACTIVE), 0.15, 1, 0.35, remainingMs
        end
        return GetString(EZOM_ALKOSH_STATE_INACTIVE), 0.65, 0.65, 0.65, 0
    end

    if not lastRecordedProcMs then
        return GetString(EZOM_ALKOSH_STATE_INACTIVE), 0.65, 0.65, 0.65, 0
    end

    local elapsedMs = math.max(0, nowMs - lastRecordedProcMs)
    local remainingMs = GetRemainingMs(nowMs)
    if not IsActive(nowMs) then
        return GetString(EZOM_ALKOSH_STATE_EXPIRED), 1, 0.25, 0.2, 0
    elseif elapsedMs < GetWindowStartMs() then
        return GetString(EZOM_ALKOSH_STATE_ACTIVE), 0.15, 1, 0.35, remainingMs
    elseif elapsedMs <= GetWindowEndMs() then
        return GetString(EZOM_ALKOSH_STATE_WINDOW), 1, 0.86, 0.25, remainingMs
    end
    return GetString(EZOM_ALKOSH_STATE_ACTIVE), 0.15, 1, 0.35, remainingMs
end

function Tracker.GetCycleState()
    local nowMs = GetNowMs()
    local offer = GetPrimaryOffer()
    local elapsedMs = lastRecordedProcMs and math.max(0, nowMs - lastRecordedProcMs) or nil
    return {
        inCombat = isCombat,
        active = IsActive(nowMs),
        elapsedMs = elapsedMs,
        remainingMs = GetRemainingMs(nowMs),
        windowStartMs = GetWindowStartMs(),
        windowEndMs = GetWindowEndMs(),
        inWindow = IsActive(nowMs)
            and elapsedMs ~= nil
            and elapsedMs >= GetWindowStartMs()
            and elapsedMs <= GetWindowEndMs(),
        hasSynergy = offer ~= nil,
        synergyName = offer and offer.name or nil,
        synergyAbilityId = offer and offer.abilityId or nil,
    }
end

local function ShouldShowActivationAlert(nowMs)
    if GetMode() ~= MODE_CYCLE or not isCombat or not HasMinimumPieces() or not HasUsableSynergy() then
        return false
    end
    if not lastRecordedProcMs then return true end

    nowMs = nowMs or GetNowMs()
    if not IsActive(nowMs) then return true end

    local elapsedMs = math.max(0, nowMs - lastRecordedProcMs)
    if elapsedMs >= GetWindowStartMs() and elapsedMs <= GetWindowEndMs() then
        return true
    end
    return elapsedMs > GetWindowEndMs() and not cycleHadWindowOffer
end

local function UpdateVisuals()
    EnsureControl()
    local nowMs = GetNowMs()
    local equipped = IsEquipped()
    local stateText, r, g, b, barValue = GetCycleVisualState(nowMs)
    local offer = GetPrimaryOffer()
    local elapsedMs = lastRecordedProcMs and math.max(0, nowMs - lastRecordedProcMs) or nil
    local inWindow = IsActive(nowMs)
        and elapsedMs ~= nil
        and elapsedMs >= GetWindowStartMs()
        and elapsedMs <= GetWindowEndMs()
    local windowOfferCount = combatStats and combatStats.availableInWindow or 0

    titleLabel:SetColor(r, g, b, 1)
    equippedLabel:SetColor(equipped and 0.15 or 1, equipped and 1 or 0.25, equipped and 0.35 or 0.2, 1)
    bar:SetColor(r, g, b, 0.9)
    barLabel:SetColor(1, 1, 1, 1)
    stateLabel:SetColor(r, g, b, 1)
    synergyLabel:SetColor(offer and 0.65 or 0.7, offer and 0.9 or 0.7, offer and 1 or 0.7, 1)
    uptimeLabel:SetColor(0.15, 1, 0.35, 1)
    efficiencyLabel:SetColor(0.55, 0.8, 1, 1)

    equippedLabel:SetText(GetString(EZOM_ALKOSH_EQUIPPED_SHORT) .. ": " .. (equipped and GetString(EZOM_YES) or GetString(EZOM_NO)))
    bar:SetValue(barValue)
    barLabel:SetText(lastRecordedProcMs and FormatSeconds(barValue) .. " / " .. FormatSeconds(ALKOSH_DURATION_MS) or GetString(EZOM_SUMMARY_NOT_APPLICABLE))
    stateLabel:SetText(stateText)
    if inWindow then
        synergyLabel:SetText(zo_strformat(
            GetString(EZOM_ALKOSH_WINDOW_OFFER_SHORT),
            offer and GetString(EZOM_YES) or GetString(EZOM_NO),
            windowOfferCount
        ))
    else
        synergyLabel:SetText(offer and offer.name or GetString(EZOM_ALKOSH_NO_SYNERGY))
    end
    uptimeLabel:SetText(GetString(EZOM_ALKOSH_UPTIME_SHORT) .. ": " .. FormatPercent(GetDisplayUptime()))
    efficiencyLabel:SetText(GetString(EZOM_ALKOSH_EFFICIENCY_SHORT) .. ": " .. FormatPercent(GetDisplayEfficiency()))

    alertTitleLabel:SetText(GetString(EZOM_ALKOSH_ALERT_ACTIVATE))
    local offerName = offer and offer.name or GetString(EZOM_ALKOSH_TEST_SYNERGY)
    if not lastRecordedProcMs then
        alertDetailLabel:SetText(zo_strformat(GetString(EZOM_ALKOSH_ALERT_INITIAL_DETAIL), offerName))
    elseif IsActive(nowMs) then
        local alertElapsedMs = math.max(0, nowMs - lastRecordedProcMs)
        if alertElapsedMs <= GetWindowEndMs() then
            local alertRemainingMs = math.max(0, GetWindowEndMs() - alertElapsedMs)
            alertDetailLabel:SetText(zo_strformat(
                GetString(EZOM_ALKOSH_ALERT_DETAIL),
                offerName,
                FormatSeconds(alertRemainingMs)
            ))
        else
            alertDetailLabel:SetText(zo_strformat(GetString(EZOM_ALKOSH_ALERT_LATE_DETAIL), offerName))
        end
    else
        alertDetailLabel:SetText(zo_strformat(GetString(EZOM_ALKOSH_ALERT_LATE_DETAIL), offerName))
    end
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
    elseif not HasMinimumPieces() then
        hidden = true
    end
    control:SetHidden(hidden)

    local alertHidden = true
    if CanShowHud() then
        if forceShow or IsHudUnlocked() then
            alertHidden = false
        elseif ShouldShowActivationAlert(GetNowMs()) then
            alertHidden = false
        end
    end
    alertControl:SetHidden(alertHidden)
end

local function RefreshState()
    local nowMs = GetNowMs()
    if nowMs - lastEquipmentScanMs >= EQUIPMENT_SCAN_INTERVAL_MS then
        ScanEquipment()
    end
    if isCombat and IsEquipped() then
        combatRelevant = true
    end
    EnsureDebuffIds()
    ScanTargetEffects()
    ScanSynergyOffers(nowMs)
    SampleCombat(nowMs)
    UpdateVisuals()
    UpdateVisibility()
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_AlkoshUpdate", UPDATE_INTERVAL_MS, RefreshState)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_AlkoshUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    if IsHudUnlocked() or forceShow or (IsEnabled() and HasMinimumPieces()) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if nowCombat == isCombat then
        ScanEquipment()
        RefreshState()
        RefreshUpdateRegistration()
        return
    end

    if nowCombat then
        isCombat = true
        combatRelevant = false
        combatStartMs = nowMs
        activeUntilMs = 0
        activeFromMs = 0
        activeTarget = ""
        activeTimingEffects = {}
        lastDirectEffectEndMs = 0
        lastProcMs = nil
        lastProcTarget = ""
        activeMs = 0
        possibleActiveFromMs = 0
        possibleActiveUntilMs = 0
        possibleLastProcMs = nil
        possibleActiveMs = 0
        lastRecordedProcMs = nil
        requiredMs = 0
        lastSampleMs = nowMs
        activeOffers = {}
        pendingClosedOffers = {}
        currentPrimaryKey = nil
        cycleHadWindowOffer = false
        combatStats = CreateCombatStats()
        lastCombatSummary = nil
    else
        if isCombat then
            SampleCombat(nowMs)
            ResolvePendingOffers(nowMs + ACTIVATION_MATCH_MS)
            lastCombatSummary = BuildSummary(nowMs)
        end
        isCombat = false
        combatStartMs = 0
        activeMs = 0
        possibleActiveFromMs = 0
        possibleActiveUntilMs = 0
        possibleLastProcMs = nil
        possibleActiveMs = 0
        lastRecordedProcMs = nil
        requiredMs = 0
        lastSampleMs = 0
        activeOffers = {}
        pendingClosedOffers = {}
        currentPrimaryKey = nil
        cycleHadWindowOffer = false
        combatStats = nil
        activeTimingEffects = {}
        lastDirectEffectEndMs = 0
    end

    ScanEquipment()
    RefreshState()
    RefreshUpdateRegistration()
end

local function OnEffectChanged(_, changeType, _, _effectName, unitTag, beginTime, endTime, _, _, _, effectType, _, _, unitName, unitId, abilityId, sourceType)
    EnsureDebuffIds()
    abilityId = tonumber(abilityId) or 0
    if not OBSERVED_DEBUFF_IDS[abilityId] then return end
    if effectType and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end
    if sourceType and COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local nowMs = GetNowMs()
    local cleanName = CleanName(unitName)
    if cleanName == "" then cleanName = ReadTargetName(unitTag) end
    local key = BuildTimingEffectKey(unitTag, unitId, abilityId)

    if TIMING_DEBUFF_IDS[abilityId]
        and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FULL_REFRESH) then
        ObserveTimingEffect(
            nowMs,
            key,
            cleanName,
            (tonumber(beginTime) or 0) * 1000,
            (tonumber(endTime) or 0) * 1000,
            "EVENT_EFFECT_CHANGED"
        )
        DebugLog(string.format("effect ability=%s target=%s unitId=%s", tostring(abilityId), tostring(cleanName), tostring(unitId)))
    elseif changeType == EFFECT_RESULT_FADED then
        if TIMING_DEBUFF_IDS[abilityId] then
            activeTimingEffects[key] = nil
            ReconcileTimingEffects(nowMs)
        end
        DebugLog(string.format("faded ability=%s target=%s", tostring(abilityId), tostring(cleanName)))
    end

    RefreshState()
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
    ApplyAlertPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    ScanEquipment()
    RefreshState()
    RefreshUpdateRegistration()
end

function Tracker.ShowTest()
    if not CanShowHud() then return end
    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    currentSnapshot = { hasSet = true, numEquipped = 5, maxEquipped = 5 }
    local nowMs = GetNowMs()
    activeUntilMs = nowMs + 3000
    activeTarget = GetString(EZOM_OFF_BALANCE_TEST_TARGET)
    lastProcMs = nowMs - 7000
    lastRecordedProcMs = lastProcMs
    activeTimingEffects = {
        preview = {
            startMs = lastProcMs,
            endMs = activeUntilMs,
            target = activeTarget,
        },
    }
    lastDirectEffectEndMs = activeUntilMs
    activeMs = 6100
    possibleActiveMs = 6800
    requiredMs = 7000
    combatStats = CreateCombatStats()
    combatStats.offered = 5
    combatStats.availableInWindow = 3
    combatStats.used = 3
    combatStats.usedInWindow = 2
    combatStats.usedOutsideWindow = 1
    activeOffers = {
        preview = {
            key = "preview",
            abilityId = 0,
            name = GetString(EZOM_ALKOSH_TEST_SYNERGY),
            firstSeenMs = nowMs,
            lastSeenMs = nowMs,
            availableInWindow = true,
        },
    }
    currentPrimaryKey = "preview"
    UpdateVisuals()
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
    end, 5000)
end

function Tracker.Init()
    EnsureDebuffIds()
    EnsureControl()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AlkoshCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AlkoshEffects", EVENT_EFFECT_CHANGED, OnEffectChanged)
    if EVENT_SYNERGY_ABILITY_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AlkoshSynergy", EVENT_SYNERGY_ABILITY_CHANGED, RefreshState)
    end
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AlkoshInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            Tracker.ApplySettings()
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_AlkoshWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            Tracker.ApplySettings()
        end)
    end

    ScanEquipment()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

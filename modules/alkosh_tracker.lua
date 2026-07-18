-- Roar of Alkosh tracker.
EZOMetter_Alkosh = EZOMetter_Alkosh or {}

local Tracker = EZOMetter_Alkosh
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterAlkoshTracker"
local UPDATE_INTERVAL_MS = 250
local EQUIPMENT_SCAN_INTERVAL_MS = 1000
local WIDTH = 260
local HEIGHT = 94
local PADDING = 10
local ROW_HEIGHT = 18

local MODE_OFF = "off"
local MODE_WARN = "warn"
local MODE_BLOCK = "block"

local TARGET_TAGS = { "reticleover", "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }
local ALKOSH_ITEM_LINK = "|H1:item:73058:364:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local ALKOSH_DURATION_MS = 10000
local TIMING_DEBUFF_IDS = { [75753] = true, [120018] = true }
local OBSERVED_DEBUFF_IDS = { [75753] = true, [76667] = true, [120018] = true }
local PROC_IDS = { [75751] = true, [75752] = true, [75753] = true, [76667] = true, [78835] = true, [120018] = true }

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
local procLabel
local remainingLabel
local uptimeLabel
local targetLabel
local warningLabel
local updateRegistered = false
local isCombat = false
local forceShow = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local activeUntilMs = 0
local activeTarget = ""
local lastProcMs = nil
local lastProcTarget = ""
local combatStartMs = 0
local activeMs = 0
local possibleMs = 0
local possibleUntilMs = 0
local requiredMs = 0
local lastSampleMs = 0
local lastCombatSummary = nil
local combatEventFiltersRegistered = false
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

local function IsActive(nowMs)
    return (tonumber(activeUntilMs) or 0) > (nowMs or GetNowMs())
end

local function GetRemainingMs(nowMs)
    return math.max(0, (tonumber(activeUntilMs) or 0) - (nowMs or GetNowMs()))
end

local function GetMode()
    local settings = GetSettings()
    local mode = settings and settings.mode or MODE_OFF
    if mode ~= MODE_WARN and mode ~= MODE_BLOCK then
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
            PROC_IDS[tonumber(abilityId) or 0] = true
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

local function HasSynergyPrompt()
    if forceShow then return true end
    if type(GetSynergyInfo) ~= "function" then return false end
    local synergyName, textureName = GetSynergyInfo()
    return (synergyName ~= nil and synergyName ~= "") or (textureName ~= nil and textureName ~= "")
end

local function ClampKnownEndTime(nowMs, untilMs)
    nowMs = nowMs or GetNowMs()
    untilMs = tonumber(untilMs) or 0
    if untilMs <= nowMs then return 0 end
    return math.min(untilMs, nowMs + ALKOSH_DURATION_MS)
end

local function EstimateEndTime(nowMs, untilMs)
    local endMs = ClampKnownEndTime(nowMs, untilMs)
    if endMs > 0 then return endMs end
    return (nowMs or GetNowMs()) + ALKOSH_DURATION_MS
end

local function MarkProc(nowMs, targetName, untilMs, canSetActive)
    lastProcMs = nowMs or GetNowMs()
    lastProcTarget = CleanName(targetName)
    if lastProcTarget ~= "" then
        activeTarget = lastProcTarget
    end
    if canSetActive == true then
        untilMs = EstimateEndTime(lastProcMs, untilMs)
        if untilMs > activeUntilMs then
            activeUntilMs = untilMs
        end
    end
end

local function ScanTargetEffects()
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then return end

    local nowMs = GetNowMs()
    local bestEndMs = 0
    local bestTarget = ""
    for _, unitTag in ipairs(TARGET_TAGS) do
        if CanReadTarget(unitTag) then
            for index = 1, GetNumBuffs(unitTag) do
                local _, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, index)
                abilityId = tonumber(abilityId) or 0
                if TIMING_DEBUFF_IDS[abilityId] then
                    local endMs = ClampKnownEndTime(nowMs, (tonumber(endTime) or 0) * 1000)
                    if endMs > bestEndMs then
                        bestEndMs = endMs
                        bestTarget = ReadTargetName(unitTag)
                    end
                end
            end
        end
    end

    if bestEndMs > 0 then
        activeUntilMs = bestEndMs
        if bestTarget ~= "" then activeTarget = bestTarget end
    elseif activeUntilMs <= nowMs then
        activeUntilMs = 0
    end
end

local function SampleCombat(nowMs)
    if not isCombat then return end
    nowMs = nowMs or GetNowMs()
    local deltaMs = nowMs - (lastSampleMs or nowMs)
    if deltaMs <= 0 then
        lastSampleMs = nowMs
        return
    end

    if IsEquipped() then
        local active = IsActive(nowMs)
        requiredMs = requiredMs + deltaMs
        if active then
            activeMs = activeMs + deltaMs
            possibleMs = possibleMs + deltaMs
        else
            if HasSynergyPrompt() then
                possibleUntilMs = math.max(possibleUntilMs, nowMs + ALKOSH_DURATION_MS)
            end
            if possibleUntilMs > lastSampleMs then
                possibleMs = possibleMs + math.min(deltaMs, possibleUntilMs - lastSampleMs)
            end
        end
    end
    lastSampleMs = nowMs
end

local function GetCurrentEfficiency()
    return possibleMs > 0 and (activeMs / possibleMs) * 100 or 0
end

local function GetDisplayEfficiency()
    if isCombat then return GetCurrentEfficiency() end
    if lastCombatSummary and lastCombatSummary.hasData and (lastCombatSummary.possibleMs or 0) > 0 then
        return lastCombatSummary.uptime or 0
    end
    return GetCurrentEfficiency()
end

local function BuildSummary(nowMs)
    nowMs = nowMs or GetNowMs()
    local durationMs = combatStartMs > 0 and math.max(0, nowMs - combatStartMs) or requiredMs
    return {
        hasData = requiredMs > 0 or lastProcMs ~= nil,
        durationMs = durationMs,
        requiredMs = requiredMs,
        activeMs = activeMs,
        possibleMs = possibleMs,
        uptime = GetCurrentEfficiency(),
        equipped = IsEquipped(),
        lastProcAgoMs = lastProcMs and math.max(0, nowMs - lastProcMs) or nil,
        lastTarget = activeTarget ~= "" and activeTarget or lastProcTarget,
        remainingMs = GetRemainingMs(nowMs),
    }
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
        GetString(EZOM_ALKOSH_UPTIME) .. ": " .. FormatPercent(summary.uptime),
        GetString(EZOM_ALKOSH_POSSIBLE_TIME) .. ": " .. FormatSeconds(summary.possibleMs),
        GetString(EZOM_ALKOSH_REMAINING) .. ": " .. FormatSeconds(summary.remainingMs),
        GetString(EZOM_ALKOSH_TARGET) .. ": " .. ((summary.lastTarget and summary.lastTarget ~= "") and summary.lastTarget or GetString(EZOM_SUMMARY_NOT_APPLICABLE)),
    }

    if summary.lastProcAgoMs then
        table.insert(lines, GetString(EZOM_ALKOSH_LAST_PROC) .. ": " .. FormatSeconds(summary.lastProcAgoMs) .. " " .. GetString(EZOM_ALKOSH_AGO))
    else
        table.insert(lines, GetString(EZOM_ALKOSH_LAST_PROC) .. ": " .. GetString(EZOM_SUMMARY_NOT_APPLICABLE))
    end

    return table.concat(lines, "\n")
end

function Tracker.GetReportSection()
    if GetMode() == MODE_OFF or not lastCombatSummary or not lastCombatSummary.hasData then return nil end
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

local function ApplyPosition()
    if not control then return end
    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 260, tonumber(settings.y) or -160)
end

local function SetMoveMode(enabled)
    if not control then return end
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
end

local function ApplyStyle()
    if not backdrop then return end
    local settings = GetSettings() or {}
    local opacity = tonumber(settings.backgroundOpacity) or 86
    opacity = math.max(0, math.min(100, opacity))
    backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.65, 0.25, 1, 0.95)
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
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 8)
    titleLabel:SetDimensions(92, ROW_HEIGHT)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetText("Alkosh")

    equippedLabel = wm:CreateControl(CONTROL_NAME .. "Equipped", control, CT_LABEL)
    equippedLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 8)
    equippedLabel:SetDimensions(140, ROW_HEIGHT)
    equippedLabel:SetFont("ZoFontGame")
    equippedLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    procLabel = wm:CreateControl(CONTROL_NAME .. "Proc", control, CT_LABEL)
    procLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 2)
    procLabel:SetDimensions(112, ROW_HEIGHT)
    procLabel:SetFont("ZoFontGame")

    remainingLabel = wm:CreateControl(CONTROL_NAME .. "Remaining", control, CT_LABEL)
    remainingLabel:SetAnchor(TOPLEFT, procLabel, TOPRIGHT, 8, 0)
    remainingLabel:SetDimensions(120, ROW_HEIGHT)
    remainingLabel:SetFont("ZoFontGame")
    remainingLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    uptimeLabel = wm:CreateControl(CONTROL_NAME .. "Uptime", control, CT_LABEL)
    uptimeLabel:SetAnchor(TOPLEFT, procLabel, BOTTOMLEFT, 0, 2)
    uptimeLabel:SetDimensions(92, ROW_HEIGHT)
    uptimeLabel:SetFont("ZoFontGame")

    targetLabel = wm:CreateControl(CONTROL_NAME .. "Target", control, CT_LABEL)
    targetLabel:SetAnchor(TOPLEFT, uptimeLabel, TOPRIGHT, 8, 0)
    targetLabel:SetDimensions(140, ROW_HEIGHT)
    targetLabel:SetFont("ZoFontGame")
    targetLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    targetLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    targetLabel:SetMaxLineCount(1)

    warningLabel = wm:CreateControl(CONTROL_NAME .. "Warning", control, CT_LABEL)
    warningLabel:SetAnchor(TOPLEFT, uptimeLabel, BOTTOMLEFT, 0, 2)
    warningLabel:SetDimensions(WIDTH - (PADDING * 2), ROW_HEIGHT)
    warningLabel:SetFont("ZoFontGameSmall")
    warningLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
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

local function UpdateVisuals()
    EnsureControl()
    local nowMs = GetNowMs()
    local equipped = IsEquipped()
    local active = isCombat and IsActive(nowMs)
    local mode = GetMode()
    local hasSynergyPrompt = isCombat and HasSynergyPrompt()
    local uptime = GetDisplayEfficiency()
    local lastProcText = (isCombat and lastProcMs) and FormatSeconds(nowMs - lastProcMs) .. " " .. GetString(EZOM_ALKOSH_AGO) or GetString(EZOM_SUMMARY_NOT_APPLICABLE)
    local remainingText = isCombat and FormatSeconds(GetRemainingMs(nowMs)) or FormatSeconds(0)
    local targetText = activeTarget ~= "" and activeTarget or lastProcTarget

    local r, g, b = 0.7, 0.7, 0.7
    if active then
        r, g, b = 0.15, 1, 0.35
    elseif equipped then
        r, g, b = 1, 0.86, 0.25
    end

    titleLabel:SetColor(r, g, b, 1)
    equippedLabel:SetColor(equipped and 0.15 or 1, equipped and 1 or 0.25, equipped and 0.35 or 0.2, 1)
    procLabel:SetColor(r, g, b, 1)
    remainingLabel:SetColor(r, g, b, 1)
    uptimeLabel:SetColor(r, g, b, 1)
    targetLabel:SetColor(0.78, 0.9, 1, 1)

    equippedLabel:SetText(GetString(EZOM_ALKOSH_EQUIPPED_SHORT) .. ": " .. (equipped and GetString(EZOM_YES) or GetString(EZOM_NO)))
    procLabel:SetText(GetString(EZOM_ALKOSH_LAST_PROC_SHORT) .. ": " .. lastProcText)
    remainingLabel:SetText(GetString(EZOM_ALKOSH_REMAINING_SHORT) .. ": " .. remainingText)
    uptimeLabel:SetText(GetString(EZOM_ALKOSH_UPTIME_SHORT) .. ": " .. FormatPercent(uptime))
    targetLabel:SetText((targetText and targetText ~= "") and targetText or GetString(EZOM_SUMMARY_NOT_APPLICABLE))

    if mode == MODE_BLOCK and active and hasSynergyPrompt then
        warningLabel:SetText(GetString(EZOM_ALKOSH_BLOCK_WARNING))
        warningLabel:SetColor(1, 0.25, 0.2, 1)
    elseif active then
        warningLabel:SetText(GetString(EZOM_ALKOSH_ACTIVE_WARNING))
        warningLabel:SetColor(0.15, 1, 0.35, 1)
    else
        warningLabel:SetText("")
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
    end
    control:SetHidden(hidden)
end

local function RefreshState()
    local nowMs = GetNowMs()
    if nowMs - lastEquipmentScanMs >= EQUIPMENT_SCAN_INTERVAL_MS then
        ScanEquipment()
    end
    EnsureDebuffIds()
    ScanTargetEffects()
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
    if IsHudUnlocked() or forceShow or IsEnabled() then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if nowCombat then
        isCombat = true
        combatStartMs = nowMs
        activeMs = 0
        possibleMs = 0
        possibleUntilMs = 0
        requiredMs = 0
        lastSampleMs = nowMs
        lastCombatSummary = nil
    else
        if isCombat then
            SampleCombat(nowMs)
            lastCombatSummary = BuildSummary(nowMs)
        end
        isCombat = false
        combatStartMs = 0
        activeMs = 0
        possibleMs = 0
        possibleUntilMs = 0
        requiredMs = 0
        lastSampleMs = 0
    end

    ScanEquipment()
    RefreshState()
    RefreshUpdateRegistration()
end

local function OnEffectChanged(_, changeType, _, _effectName, unitTag, _, endTime, _, _, _, effectType, _, _, unitName, unitId, abilityId)
    EnsureDebuffIds()
    abilityId = tonumber(abilityId) or 0
    if not OBSERVED_DEBUFF_IDS[abilityId] then return end
    if effectType and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end

    local nowMs = GetNowMs()
    local cleanName = CleanName(unitName)
    if cleanName == "" then cleanName = ReadTargetName(unitTag) end
    local endMs = (tonumber(endTime) or 0) * 1000

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FULL_REFRESH then
        MarkProc(nowMs, cleanName, endMs, TIMING_DEBUFF_IDS[abilityId] == true)
        DebugLog(string.format("effect ability=%s target=%s unitId=%s end=%s", tostring(abilityId), tostring(cleanName), tostring(unitId), tostring(endMs)))
    elseif changeType == EFFECT_RESULT_FADED then
        if TIMING_DEBUFF_IDS[abilityId] and (cleanName == "" or cleanName == activeTarget) then
            activeUntilMs = 0
        end
        DebugLog(string.format("faded ability=%s target=%s", tostring(abilityId), tostring(cleanName)))
    end

    RefreshState()
end

local function OnCombatEvent(_, result, _, abilityName, _, _, sourceName, sourceType, targetName, targetType, _, _, _, _, sourceUnitId, targetUnitId, abilityId)
    EnsureDebuffIds()
    abilityId = tonumber(abilityId) or 0
    if not PROC_IDS[abilityId] then return end
    if sourceType and COMBAT_UNIT_TYPE_PLAYER and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local nowMs = GetNowMs()
    MarkProc(nowMs, targetName, nil, TIMING_DEBUFF_IDS[abilityId] == true)
    DebugLog(string.format(
        "combat result=%s ability=%s name=%s target=%s source=%s sourceUnitId=%s targetUnitId=%s targetType=%s",
        tostring(result),
        tostring(abilityId),
        tostring(abilityName),
        tostring(targetName),
        tostring(sourceName),
        tostring(sourceUnitId),
        tostring(targetUnitId),
        tostring(targetType)
    ))
    RefreshState()
end

local function RegisterCombatEventFilters()
    if combatEventFiltersRegistered then return end
    EnsureDebuffIds()
    if not REGISTER_FILTER_ABILITY_ID then return end
    for abilityId in pairs(PROC_IDS) do
        if abilityId and abilityId > 0 then
            local eventName = ADDON_NAME .. "_AlkoshCombatEvent" .. tostring(abilityId)
            EVENT_MANAGER:RegisterForEvent(eventName, EVENT_COMBAT_EVENT, OnCombatEvent)
            EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_ABILITY_ID, abilityId)
            if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
                EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
            end
        end
    end
    combatEventFiltersRegistered = true
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
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
    activeUntilMs = GetNowMs() + 6400
    activeTarget = GetString(EZOM_OFF_BALANCE_TEST_TARGET)
    lastProcMs = GetNowMs() - 1200
    activeMs = 3200
    possibleMs = 5000
    possibleUntilMs = GetNowMs() + 3000
    requiredMs = 7000
    UpdateVisuals()
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        Tracker.ApplySettings()
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
    RegisterCombatEventFilters()
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

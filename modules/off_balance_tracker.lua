-- Tracker separado para Off Balance en objetivo/boss.
EZOMetter_OffBalance = EZOMetter_OffBalance or {}

local Tracker = EZOMetter_OffBalance
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterOffBalanceTracker"
local UPDATE_INTERVAL_MS = 100
local OFF_BALANCE_ID = 62988
local OFF_BALANCE_IMMUNITY_ID = 134599
local OFF_BALANCE_IMMUNITY_MS = 15000
local WIDTH = 220
local HEIGHT = 58
local ICON_SIZE = 18
local PADDING = 8
local TEXT_GAP = 8
local TIMER_WIDTH = 66
local PULSE_DURATION_MS = 650
local PULSE_SCALE = 1.18
local DEBUG_THROTTLE_MS = 750
local COMBAT_SAMPLE_INTERVAL_MS = 250
local SUMMARY_TOLERANCE_MS = 250
local DAMAGE_CALLBACK_NAME = ADDON_NAME .. "OffBalanceDamage"

local STATE_FREE = 0
local STATE_ACTIVE = 1
local STATE_IMMUNE = 2

local SOURCE_NONE = 0
local SOURCE_DIRECT = 1
local SOURCE_EVENT = 2
local SOURCE_ESTIMATED = 3
local SOURCE_MEMORY = 4

local OFF_BALANCE_ALIASES = {
    [62988] = true,
    [39077] = true,
    [62968] = true,
    [130145] = true,
    [130129] = true,
    [130139] = true,
    [45902] = true,
    [25256] = true,
    [34733] = true,
    [34737] = true,
    [23808] = true,
    [20806] = true,
    [34117] = true,
    [125750] = true,
    [131562] = true,
    [45834] = true,
    [137257] = true,
    [137312] = true,
    [120014] = true,
}

local control
local backdrop
local icon
local stateLabel
local timerLabel
local targetLabel
local sourceLabel
local updateRegistered = false
local forceShow = false
local isCombat = false
local hasVisibleData = false
local isTrackingBoss = false
local namesByState
local lastVisualState = STATE_FREE
local currentState = STATE_FREE
local pulseUntilMs = 0
local lastDebugByKey = {}
local statsUpdateRegistered = false
local damageCallbackRegistered = false
local statsTracker
local damageTracker
local lastCombatSummary
local IsHudUnlocked

local bossTimers = {}
local knownBosses = {}
local memory = { state = STATE_FREE, endTime = 0, isBoss = false, targetName = "", source = SOURCE_NONE }
local bossTags = { "boss1", "boss2", "boss3", "boss4", "boss5", "boss6" }

local function GetNowMs()
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetGameTimeSeconds) == "function" then
        return GetGameTimeSeconds() * 1000
    end
    return 0
end

local function SummaryNowMs()
    if EZOMetter_CombatSummary and EZOMetter_CombatSummary.GetNowMs then
        return EZOMetter_CombatSummary.GetNowMs()
    end
    return GetNowMs()
end

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.offBalance = EZOMetter.sv.offBalance or {}
    return EZOMetter.sv.offBalance
end

local function IsDebugEnabled()
    local settings = GetSettings()
    return settings and settings.debugEvents == true and EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.debugMode == true
end

local function GetRole()
    return EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.role or "dd"
end

local function CleanUnitName(name)
    name = tostring(name or "")
    return string.gsub(name, "%^.*", "")
end

local function NormalizeName(name)
    name = CleanUnitName(name)
    if name == "" then return "" end
    if type(zo_strformat) == "function" and SI_ABILITY_NAME then
        name = zo_strformat(SI_ABILITY_NAME, name)
    end
    name = string.gsub(name, "%^.*", "")
    name = string.gsub(name, "%-", " ")
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function SameUnitName(left, right)
    local leftName = NormalizeName(left)
    local rightName = NormalizeName(right)
    return leftName ~= "" and leftName == rightName
end

local function AddName(names, state, name)
    local normalized = NormalizeName(name)
    if normalized ~= "" then
        names[normalized] = state
    end
end

local function GetNamesByState()
    if namesByState then return namesByState end

    namesByState = {}
    if type(GetAbilityName) == "function" then
        AddName(namesByState, STATE_ACTIVE, GetAbilityName(OFF_BALANCE_ID))
        AddName(namesByState, STATE_IMMUNE, GetAbilityName(OFF_BALANCE_IMMUNITY_ID))
    end

    AddName(namesByState, STATE_ACTIVE, "Off Balance")
    AddName(namesByState, STATE_ACTIVE, "Off-Balance")
    AddName(namesByState, STATE_IMMUNE, "Off Balance Immunity")
    AddName(namesByState, STATE_IMMUNE, "Off-Balance Immunity")

    return namesByState
end

local function MatchState(effectName, abilityId)
    if abilityId == OFF_BALANCE_IMMUNITY_ID then return STATE_IMMUNE end
    if OFF_BALANCE_ALIASES[abilityId] then return STATE_ACTIVE end

    local normalized = NormalizeName(effectName)
    if normalized == "" then return STATE_FREE end

    return GetNamesByState()[normalized] or STATE_FREE
end

local function GetStateColor(state)
    local settings = GetSettings() or {}
    local color
    if state == STATE_ACTIVE then
        color = settings.activeColor
    elseif state == STATE_IMMUNE then
        color = settings.cooldownColor
    else
        color = settings.readyColor
    end

    if color then
        return tonumber(color.r) or 0.9, tonumber(color.g) or 0.9, tonumber(color.b) or 0.9, tonumber(color.a) or 1
    end

    if state == STATE_ACTIVE then return 0.15, 1, 0.35, 1 end
    if state == STATE_IMMUNE then return 1, 0.25, 0.2, 1 end
    return 0.9, 0.9, 0.9, 1
end

local function GetSourceName(source)
    if source == SOURCE_DIRECT then return GetString(EZOM_OFF_BALANCE_SOURCE_DIRECT) end
    if source == SOURCE_EVENT then return GetString(EZOM_OFF_BALANCE_SOURCE_EVENT) end
    if source == SOURCE_ESTIMATED then return GetString(EZOM_OFF_BALANCE_SOURCE_ESTIMATED) end
    if source == SOURCE_MEMORY then return GetString(EZOM_OFF_BALANCE_SOURCE_MEMORY) end
    return ""
end

local function FormatNumber(value)
    value = tonumber(value) or 0
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(math.floor(value + 0.5))
    end
    return tostring(math.floor(value + 0.5))
end

local function FormatPercentValue(value)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

local function FormatExploiterStatus(exploiter)
    exploiter = exploiter or {}
    if exploiter.slotted == true then
        return string.format(
            "%s %d (%s)",
            GetString(EZOM_EXPLOITER_SLOTTED),
            tonumber(exploiter.points) or 0,
            FormatPercentValue(tonumber(exploiter.bonusPct) or 0)
        )
    end
    if exploiter.found == false then
        return GetString(EZOM_EXPLOITER_UNKNOWN)
    end
    return GetString(EZOM_EXPLOITER_NOT_SLOTTED)
end

local function BuildTooltipText()
    if not lastCombatSummary then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        GetString(EZOM_OFF_BALANCE_SUMMARY_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. EZOMetter_CombatSummary.FormatSeconds(lastCombatSummary.durationMs) .. "s",
    }

    local summaryByKey = lastCombatSummary.allByKey or lastCombatSummary.byKey or {}
    local active = summaryByKey.active
    local cycle = summaryByKey.cycle

    if active then
        table.insert(lines, string.format(
            "%s: %s | %ss",
            GetString(EZOM_OFF_BALANCE_SUMMARY_ACTIVE),
            EZOMetter_CombatSummary.FormatPercent(active.uptime),
            EZOMetter_CombatSummary.FormatSeconds(active.activeMs)
        ))
    else
        table.insert(lines, GetString(EZOM_OFF_BALANCE_SUMMARY_ACTIVE) .. ": " .. GetString(EZOM_SUMMARY_NOT_APPLICABLE))
    end

    if cycle then
        table.insert(lines, string.format(
            "%s: %s | %ss",
            GetString(EZOM_OFF_BALANCE_SUMMARY_CYCLE),
            EZOMetter_CombatSummary.FormatPercent(cycle.uptime),
            EZOMetter_CombatSummary.FormatSeconds(cycle.activeMs)
        ))
    else
        table.insert(lines, GetString(EZOM_OFF_BALANCE_SUMMARY_CYCLE) .. ": " .. GetString(EZOM_SUMMARY_NOT_APPLICABLE))
    end

    local exploiterSummary = lastCombatSummary.exploiter
    if exploiterSummary then
        local exploiter = exploiterSummary.exploiter or {}
        table.insert(lines, "")
        table.insert(lines, GetString(EZOM_EXPLOITER_LABEL) .. ": " .. FormatExploiterStatus(exploiter))
        table.insert(lines, string.format(
            "%s: %s | %s",
            GetString(EZOM_EXPLOITER_DAMAGE_DURING_OB),
            FormatPercentValue(exploiterSummary.damageSharePct),
            FormatNumber(exploiterSummary.offBalanceDamage)
        ))

        if exploiter.slotted == true then
            local timeValue = 0
            if active then
                timeValue = ((tonumber(active.uptime) or 0) / 100) * (tonumber(exploiter.bonusPct) or 0)
            end
            table.insert(lines, GetString(EZOM_EXPLOITER_TIME_VALUE) .. ": " .. FormatPercentValue(timeValue))
            table.insert(lines, GetString(EZOM_EXPLOITER_DAMAGE_VALUE) .. ": " .. FormatPercentValue(exploiterSummary.damageWeightedValuePct))
            table.insert(lines, GetString(EZOM_EXPLOITER_ESTIMATED_EXTRA) .. ": " .. FormatNumber(exploiterSummary.estimatedExtraDamage))
        else
            table.insert(lines, GetString(EZOM_EXPLOITER_POTENTIAL_MAX) .. ": " .. FormatPercentValue(exploiterSummary.potentialMaxValuePct))
        end
    end

    return table.concat(lines, "\n")
end

function Tracker.GetReportSection()
    if not lastCombatSummary then return nil end
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

local FormatSeconds

local function GetAbilityDisplay(abilityId)
    abilityId = tonumber(abilityId) or 0
    if abilityId <= 0 then return "" end

    local abilityName = ""
    if type(GetAbilityName) == "function" then
        abilityName = CleanUnitName(GetAbilityName(abilityId))
    end

    if abilityName ~= "" then
        return string.format("%s (%d)", abilityName, abilityId)
    end
    return tostring(abilityId)
end

local function DebugOffBalance(key, message)
    if not IsDebugEnabled() or not EZOMetter.DebugLog then return end

    local nowMs = GetNowMs()
    key = tostring(key or message or "")
    if lastDebugByKey[key] and nowMs - lastDebugByKey[key] < DEBUG_THROTTLE_MS then
        return
    end

    lastDebugByKey[key] = nowMs
    EZOMetter.DebugLog("[OffBalance] " .. tostring(message))
end

local function DebugEffect(source, unitTag, unitName, state, effectName, abilityId, endTimeMs, changeType)
    if not IsDebugEnabled() then return end

    local stateName = GetStateName(state)
    local remainingMs = math.max(0, (endTimeMs or 0) - GetNowMs())
    local key = table.concat({
        tostring(source or ""),
        tostring(unitTag or ""),
        tostring(unitName or ""),
        tostring(state or 0),
        tostring(abilityId or 0),
        tostring(changeType or ""),
    }, "|")

    DebugOffBalance(key, string.format(
        "%s unitTag=%s unitName=%s state=%s effect=%s ability=%s remaining=%s changeType=%s",
        tostring(source or ""),
        tostring(unitTag or ""),
        tostring(unitName or ""),
        tostring(stateName or ""),
        tostring(effectName or ""),
        GetAbilityDisplay(abilityId),
        FormatSeconds(remainingMs),
        tostring(changeType or "")
    ))
end

function FormatSeconds(ms)
    local seconds = math.max(0, ms or 0) / 1000
    if seconds >= 10 then
        return string.format("%.0f", seconds)
    end
    return string.format("%.1f", seconds)
end

local function FormatPercent(value)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

local function HasLibCombatDamage()
    return LibCombat ~= nil
        and LIBCOMBAT_EVENT_DAMAGE_OUT ~= nil
        and type(LibCombat.RegisterCallbackType) == "function"
end

local function CopyExploiterState()
    local data = EZOMetter_ChampionPoints and EZOMetter_ChampionPoints.Refresh and EZOMetter_ChampionPoints.Refresh() or nil
    if not data then
        return {
            found = false,
            slotted = false,
            points = 0,
            bonusPct = 0,
            maxBonusPct = 10,
            name = "Exploiter",
        }
    end

    return {
        id = data.id,
        name = data.name,
        found = data.found == true,
        slotted = data.slotted == true,
        points = tonumber(data.points) or 0,
        bonusPct = tonumber(data.bonusPct) or 0,
        maxBonusPct = tonumber(data.maxBonusPct) or 10,
    }
end

local function CreateDamageTracker()
    local tracker = {
        started = false,
        totalDamage = 0,
        offBalanceDamage = 0,
        exploiter = nil,
        lastSummary = nil,
    }

    function tracker:Start()
        self.started = true
        self.totalDamage = 0
        self.offBalanceDamage = 0
        self.exploiter = CopyExploiterState()
        self.lastSummary = nil
    end

    function tracker:AddDamage(hitValue, targetUnitId)
        if not self.started then return end

        local damage = tonumber(hitValue) or 0
        if damage <= 0 then return end

        self.totalDamage = self.totalDamage + damage
        if Tracker.IsUnitOffBalance(targetUnitId) then
            self.offBalanceDamage = self.offBalanceDamage + damage
        end
    end

    function tracker:Finish()
        if not self.started then return self.lastSummary end

        local totalDamage = self.totalDamage
        local offBalanceDamage = self.offBalanceDamage
        local damageSharePct = 0
        if totalDamage > 0 then
            damageSharePct = (offBalanceDamage / totalDamage) * 100
        end

        local exploiter = self.exploiter or CopyExploiterState()
        local bonusPct = tonumber(exploiter.bonusPct) or 0
        local maxBonusPct = tonumber(exploiter.maxBonusPct) or 10
        local damageWeightedValuePct = (damageSharePct / 100) * bonusPct
        local potentialMaxValuePct = (damageSharePct / 100) * maxBonusPct
        local estimatedExtraDamage = 0
        if bonusPct > 0 then
            estimatedExtraDamage = offBalanceDamage * (bonusPct / (100 + bonusPct))
        end

        self.lastSummary = {
            totalDamage = totalDamage,
            offBalanceDamage = offBalanceDamage,
            damageSharePct = damageSharePct,
            exploiter = exploiter,
            damageWeightedValuePct = damageWeightedValuePct,
            potentialMaxValuePct = potentialMaxValuePct,
            estimatedExtraDamage = estimatedExtraDamage,
        }
        self.started = false
        return self.lastSummary
    end

    return tracker
end

local function BuildRowFromStat(stat)
    if not stat or not stat.requiredMs or stat.requiredMs <= 0 then return nil end
    return {
        key = stat.key,
        activeMs = stat.activeMs or 0,
        requiredMs = stat.requiredMs,
        uptime = ((stat.activeMs or 0) / stat.requiredMs) * 100,
    }
end

local function BuildCurrentCombatSummary()
    if not statsTracker or not statsTracker.started then return nil end

    statsTracker:Sample(SummaryNowMs())
    return {
        durationMs = statsTracker.durationMs or 0,
        allByKey = {
            active = BuildRowFromStat(statsTracker.byKey and statsTracker.byKey.active),
            cycle = BuildRowFromStat(statsTracker.byKey and statsTracker.byKey.cycle),
        },
    }
end

local function FormatSummaryRowPercent(row)
    if not row then return "--" end
    return FormatPercent(row.uptime)
end

local function BuildPanelCounterText()
    local summary = isCombat and BuildCurrentCombatSummary() or lastCombatSummary
    if not summary then return nil end

    local summaryByKey = summary.allByKey or summary.byKey or {}
    local prefix = isCombat and GetString(EZOM_OFF_BALANCE_PANEL_CURRENT) or GetString(EZOM_OFF_BALANCE_PANEL_LAST)
    return string.format(
        "%s %s | %s %s",
        prefix,
        FormatSummaryRowPercent(summaryByKey.active),
        GetString(EZOM_OFF_BALANCE_PANEL_CYCLE),
        FormatSummaryRowPercent(summaryByKey.cycle)
    )
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or -80)
end

local function SetMoveMode(enabled)
    if not control then return end

    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
end

local function ApplyStyle()
    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control)
        if EZOMetter_WindowStyle.ApplyBackdropStyle then
            EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
            return
        end
    end
    if not backdrop then return end

    local settings = GetSettings() or {}
    local opacity = tonumber(settings.backgroundOpacity) or 86
    if opacity < 0 then opacity = 0 end
    if opacity > 100 then opacity = 100 end

    backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.95, 0.45, 0.1, 0.70)
    end
end

local function ApplyPulse(nowMs)
    if not icon then return end

    if nowMs >= pulseUntilMs then
        if icon.SetScale then icon:SetScale(1) end
        return
    end

    local remaining = pulseUntilMs - nowMs
    local progress = 1 - (remaining / PULSE_DURATION_MS)
    local wave = math.sin(progress * math.pi)
    local scale = 1 + ((PULSE_SCALE - 1) * wave)
    if icon.SetScale then icon:SetScale(scale) end
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
    ApplyStyle()

    icon = wm:CreateControl(CONTROL_NAME .. "Icon", control, CT_TEXTURE)
    icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    icon:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 11)
    icon:SetTexture("esoui/art/icons/ability_debuff_offbalance.dds")

    stateLabel = wm:CreateControl(CONTROL_NAME .. "State", control, CT_LABEL)
    stateLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, TEXT_GAP, -1)
    stateLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -(PADDING + TIMER_WIDTH + 8), -1)
    stateLabel:SetHeight(24)
    stateLabel:SetFont("ZoFontGameMedium")
    stateLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    stateLabel:SetMaxLineCount(1)

    timerLabel = wm:CreateControl(CONTROL_NAME .. "Timer", control, CT_LABEL)
    timerLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 4)
    timerLabel:SetDimensions(TIMER_WIDTH, 24)
    timerLabel:SetFont("ZoFontGameLargeBold")
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    targetLabel = wm:CreateControl(CONTROL_NAME .. "Target", control, CT_LABEL)
    targetLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 34)
    targetLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 34)
    targetLabel:SetHeight(18)
    targetLabel:SetFont("ZoFontGameSmall")
    targetLabel:SetColor(0.82, 0.82, 0.82, 1)
    targetLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    targetLabel:SetMaxLineCount(1)

    sourceLabel = wm:CreateControl(CONTROL_NAME .. "Source", control, CT_LABEL)
    sourceLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 50)
    sourceLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 50)
    sourceLabel:SetHeight(20)
    sourceLabel:SetFont("ZoFontGameSmall")
    sourceLabel:SetColor(0.62, 0.72, 0.88, 1)
    sourceLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    sourceLabel:SetMaxLineCount(1)
    sourceLabel:SetHidden(true)

    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function IsEnabled()
    local settings = GetSettings()
    if not settings or settings.enabled ~= true then return false end
    if settings.ddOnly ~= false and GetRole() ~= "dd" then return false end
    return true
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function UpdateVisibility()
    EnsureControl()

    local settings = GetSettings() or {}
    local allowIdle = settings.onlyCombat == false and settings.onlyBosses ~= true
    local hidden = false
    if not CanShowHud() then
        hidden = true
    elseif forceShow then
        hidden = false
    elseif IsHudUnlocked() then
        hidden = false
    elseif not IsEnabled() then
        hidden = true
    elseif settings.onlyCombat ~= false and not isCombat and not (lastCombatSummary and lastCombatSummary.durationMs and lastCombatSummary.durationMs > 0) then
        hidden = true
    elseif settings.onlyBosses == true and not isTrackingBoss and not (lastCombatSummary and lastCombatSummary.durationMs and lastCombatSummary.durationMs > 0) then
        hidden = true
    elseif not hasVisibleData and not allowIdle then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function UpdateVisuals(state, remainingMs, targetName, targetIsBoss, source)
    EnsureControl()

    local nowMs = GetNowMs()
    if state == STATE_ACTIVE and lastVisualState ~= STATE_ACTIVE and (GetSettings() or {}).pulseOnActive ~= false then
        pulseUntilMs = nowMs + PULSE_DURATION_MS
        DebugOffBalance("state-active-" .. tostring(targetName or ""), "state changed to Off Balance for " .. tostring(targetName or ""))
    end
    lastVisualState = state
    ApplyPulse(nowMs)

    local r, g, b, a = GetStateColor(state)
    icon:SetColor(r, g, b, a)
    stateLabel:SetText(GetString(EZOM_OFF_BALANCE_STATE_ACTIVE))
    stateLabel:SetColor(r, g, b, a)
    timerLabel:SetColor(r, g, b, a)

    if state == STATE_IMMUNE then
        timerLabel:SetText(string.format(GetString(EZOM_OFF_BALANCE_TIMER_COOLDOWN), FormatSeconds(remainingMs)))
    elseif state == STATE_ACTIVE then
        timerLabel:SetText(FormatSeconds(remainingMs))
    else
        timerLabel:SetText("--")
    end

    local panelCounterText = BuildPanelCounterText()
    if panelCounterText then
        targetLabel:SetText(panelCounterText)
    elseif not isCombat then
        targetLabel:SetText(GetString(EZOM_OFF_BALANCE_OUT_OF_COMBAT))
    elseif targetName and targetName ~= "" then
        targetLabel:SetText(targetName)
    else
        targetLabel:SetText(GetString(EZOM_OFF_BALANCE_NO_TARGET))
    end

    sourceLabel:SetText("")
end

local function IsTargetBossOrDummy(unitTag, unitName)
    if unitTag and string.sub(unitTag, 1, 4) == "boss" then return true end

    local checkTag = unitTag or "reticleover"
    if type(DoesUnitExist) == "function" and DoesUnitExist(checkTag) then
        for _, bossTag in ipairs(bossTags) do
            if DoesUnitExist(bossTag) and type(AreUnitsEqual) == "function" and AreUnitsEqual(checkTag, bossTag) then
                return true
            end
        end
    end

    if type(DoesUnitExist) == "function" and DoesUnitExist("reticleover") and type(IsUnitAttackable) == "function" and IsUnitAttackable("reticleover") then
        local reticleName = CleanUnitName(GetUnitName("reticleover"))
        local cleanEventName = CleanUnitName(unitName)
        local powerType = POWERTYPE_HEALTH or COMBAT_MECHANIC_FLAGS_HEALTH
        local maxHealth = powerType and select(2, GetUnitPower("reticleover", powerType)) or 0

        if (cleanEventName == "" or cleanEventName == reticleName) and maxHealth and maxHealth >= 20500000 and maxHealth <= 21500000 then
            return true
        end
    end

    return false
end

local function SetMemory(state, endTimeMs, targetName, isBoss, source)
    memory.state = state or STATE_FREE
    memory.endTime = endTimeMs or 0
    memory.targetName = targetName or ""
    memory.isBoss = isBoss == true
    memory.source = source or SOURCE_NONE
end

local function ScanUnit(unitTag)
    if type(DoesUnitExist) ~= "function" or not DoesUnitExist(unitTag) then
        return STATE_FREE, 0
    end
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        return STATE_FREE, 0
    end

    local immuneEnd = 0
    for index = 1, GetNumBuffs(unitTag) do
        local buffName, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo(unitTag, index)
        local state = MatchState(buffName, abilityId)
        if state == STATE_ACTIVE then
            DebugEffect("direct-scan", unitTag, CleanUnitName(GetUnitName(unitTag)), state, buffName, abilityId, (endTime or 0) * 1000)
            return STATE_ACTIVE, (endTime or 0) * 1000
        elseif state == STATE_IMMUNE then
            immuneEnd = math.max(immuneEnd, (endTime or 0) * 1000)
            DebugEffect("direct-scan", unitTag, CleanUnitName(GetUnitName(unitTag)), state, buffName, abilityId, (endTime or 0) * 1000)
        end
    end

    if immuneEnd > 0 then
        return STATE_IMMUNE, immuneEnd
    end
    return STATE_FREE, 0
end

local function AdvanceSyntheticState(data, nowMs)
    if data.state == STATE_ACTIVE and nowMs >= data.endTime then
        data.state = STATE_IMMUNE
        data.endTime = data.endTime + OFF_BALANCE_IMMUNITY_MS
        data.source = SOURCE_ESTIMATED
        DebugOffBalance("synthetic-immune-" .. tostring(data.targetName or data.unitName or ""), "synthetic cooldown started for " .. tostring(data.targetName or data.unitName or ""))
    elseif data.state == STATE_IMMUNE and nowMs >= data.endTime then
        data.state = STATE_FREE
        data.endTime = 0
        data.source = SOURCE_ESTIMATED
        DebugOffBalance("synthetic-free-" .. tostring(data.targetName or data.unitName or ""), "synthetic cooldown ended for " .. tostring(data.targetName or data.unitName or ""))
    end
end

local function GetBossFocusState(nowMs)
    local activeState = STATE_FREE
    local activeEndTime = 0
    local activeName = ""
    local activeSource = SOURCE_NONE

    for unitId, data in pairs(bossTimers) do
        AdvanceSyntheticState(data, nowMs)
        if data.state == STATE_FREE then
            bossTimers[unitId] = nil
        elseif data.state == STATE_ACTIVE then
            return data.state, data.endTime, data.unitName or "", true, data.source or SOURCE_EVENT
        elseif data.state == STATE_IMMUNE and activeState ~= STATE_ACTIVE then
            activeState = data.state
            activeEndTime = data.endTime
            activeName = data.unitName or ""
            activeSource = data.source or SOURCE_EVENT
        end
    end

    return activeState, activeEndTime, activeName, activeState ~= STATE_FREE, activeSource
end

function Tracker.IsUnitOffBalance(targetUnitId)
    if targetUnitId and bossTimers[targetUnitId] and bossTimers[targetUnitId].state == STATE_ACTIVE then
        return true
    end
    return currentState == STATE_ACTIVE
end

local function OnLibCombatDamageOut(_, _timems, _result, _sourceUnitId, targetUnitId, _abilityId, hitValue)
    if not isCombat or not damageTracker then return end
    damageTracker:AddDamage(hitValue, targetUnitId)
end

local function RegisterLibCombatDamage()
    if damageCallbackRegistered or not HasLibCombatDamage() then return end
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_DAMAGE_OUT, OnLibCombatDamageOut, DAMAGE_CALLBACK_NAME)
    damageCallbackRegistered = true
end

local function OnUpdate()
    local settings = GetSettings() or {}
    local nowMs = GetNowMs()
    local reticleActive = type(DoesUnitExist) == "function" and DoesUnitExist("reticleover")
        and type(IsUnitAttackable) == "function" and IsUnitAttackable("reticleover")

    local state = STATE_FREE
    local endTime = 0
    local targetName = ""
    local targetIsBoss = false
    local source = SOURCE_NONE

    if reticleActive then
        targetName = CleanUnitName(GetUnitName("reticleover"))
        targetIsBoss = IsTargetBossOrDummy("reticleover", targetName)
        state, endTime = ScanUnit("reticleover")
        source = SOURCE_DIRECT

        if state == STATE_FREE then
            AdvanceSyntheticState(memory, nowMs)
            if memory.state ~= STATE_FREE and SameUnitName(memory.targetName, targetName) then
                state = memory.state
                endTime = memory.endTime
                source = memory.source or SOURCE_MEMORY
            else
                SetMemory(STATE_FREE, 0, targetName, targetIsBoss, SOURCE_DIRECT)
            end
        else
            SetMemory(state, endTime, targetName, targetIsBoss, source)
        end
    else
        AdvanceSyntheticState(memory, nowMs)
        source = memory.source or SOURCE_NONE
    end

    if settings.bossFocus == true then
        if reticleActive and targetIsBoss then
            if state == STATE_FREE then
                local bossState, bossEndTime, bossName, hasBossState, bossSource = GetBossFocusState(nowMs)
                if hasBossState then
                    state = bossState
                    endTime = bossEndTime
                    targetName = bossName ~= "" and bossName or targetName
                    targetIsBoss = true
                    source = bossSource
                end
            end
        else
            local bossState, bossEndTime, bossName, hasBossState, bossSource = GetBossFocusState(nowMs)
            if hasBossState then
                state = bossState
                endTime = bossEndTime
                targetName = bossName
                targetIsBoss = true
                source = bossSource
            elseif memory.isBoss then
                state = memory.state
                endTime = memory.endTime
                targetName = memory.targetName
                targetIsBoss = true
                source = memory.source or SOURCE_MEMORY
            end
        end
    end

    if nowMs > endTime then
        state = STATE_FREE
        endTime = 0
    end

    isTrackingBoss = targetIsBoss
    hasVisibleData = reticleActive or targetIsBoss or state ~= STATE_FREE or (settings.onlyCombat == false and settings.onlyBosses ~= true)
    currentState = state
    UpdateVisuals(state, math.max(0, endTime - nowMs), targetName, targetIsBoss, source)
    UpdateVisibility()
end

local function RegisterStatsUpdate()
    if statsUpdateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_OffBalanceStats", COMBAT_SAMPLE_INTERVAL_MS, function()
        if statsTracker then
            statsTracker:Sample(SummaryNowMs())
        end
    end)
    statsUpdateRegistered = true
end

local function UnregisterStatsUpdate()
    if not statsUpdateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_OffBalanceStats")
    statsUpdateRegistered = false
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_OffBalanceUpdate", UPDATE_INTERVAL_MS, OnUpdate)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_OffBalanceUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    local settings = GetSettings() or {}
    if IsHudUnlocked() or forceShow or (IsEnabled() and (settings.onlyCombat == false or isCombat)) then
        RegisterUpdate()
        if forceShow then
            UpdateVisibility()
        else
            OnUpdate()
        end
    else
        UnregisterUpdate()
        UpdateVisibility()
    end
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)

    if isCombat then
        bossTimers = {}
        knownBosses = {}
        memory = { state = STATE_FREE, endTime = 0, isBoss = false, targetName = "", source = SOURCE_NONE }
        currentState = STATE_FREE
        lastCombatSummary = nil
        if statsTracker then
            statsTracker:Start(SummaryNowMs())
            RegisterStatsUpdate()
        end
        if damageTracker then
            damageTracker:Start()
        end
    else
        local exploiterSummary
        if damageTracker then
            exploiterSummary = damageTracker:Finish()
        end
        if statsTracker then
            lastCombatSummary = statsTracker:Finish(SummaryNowMs())
            if lastCombatSummary then
                lastCombatSummary.exploiter = exploiterSummary
            end
        end
        UnregisterStatsUpdate()
        bossTimers = {}
        knownBosses = {}
        memory = { state = STATE_FREE, endTime = 0, isBoss = false, targetName = "", source = SOURCE_NONE }
        isTrackingBoss = false
        hasVisibleData = lastCombatSummary and lastCombatSummary.durationMs and lastCombatSummary.durationMs > 0
        currentState = STATE_FREE
        UpdateVisuals(STATE_FREE, 0, hasVisibleData and GetString(EZOM_LAST_COMBAT_TITLE) or "", false, SOURCE_NONE)
    end

    RefreshUpdateRegistration()
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, endTime, _, _, _, effectType, _, _, unitName, unitId, abilityId)
    local state = MatchState(effectName, abilityId)
    if state == STATE_FREE then return end
    if effectType and effectType ~= BUFF_EFFECT_TYPE_DEBUFF then return end

    local isBossEvent = false
    if unitId and knownBosses[unitId] then
        isBossEvent = true
    elseif IsTargetBossOrDummy(unitTag, unitName) then
        isBossEvent = true
        if unitId then knownBosses[unitId] = true end
    end

    local endTimeMs = (endTime or 0) * 1000
    local cleanName = CleanUnitName(unitName)
    if cleanName == "" and unitTag and type(DoesUnitExist) == "function" and DoesUnitExist(unitTag) then
        cleanName = CleanUnitName(GetUnitName(unitTag))
    end
    DebugEffect("effect-event", unitTag, cleanName, state, effectName, abilityId, endTimeMs, changeType)

    if isBossEvent and unitId then
        bossTimers[unitId] = bossTimers[unitId] or {}
        bossTimers[unitId].unitName = cleanName
        bossTimers[unitId].isBoss = true

        if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED or changeType == EFFECT_RESULT_FULL_REFRESH then
            bossTimers[unitId].state = state
            bossTimers[unitId].endTime = endTimeMs
            bossTimers[unitId].source = SOURCE_EVENT
        elseif changeType == EFFECT_RESULT_FADED then
            if state == STATE_ACTIVE then
                bossTimers[unitId].state = STATE_IMMUNE
                bossTimers[unitId].endTime = GetNowMs() + OFF_BALANCE_IMMUNITY_MS
                bossTimers[unitId].source = SOURCE_ESTIMATED
            else
                bossTimers[unitId].state = STATE_FREE
                bossTimers[unitId].endTime = 0
                bossTimers[unitId].source = SOURCE_EVENT
            end
        end
    end

    if unitTag == "reticleover" then
        if changeType == EFFECT_RESULT_FADED and state == STATE_ACTIVE then
            SetMemory(STATE_IMMUNE, GetNowMs() + OFF_BALANCE_IMMUNITY_MS, cleanName, isBossEvent, SOURCE_ESTIMATED)
        elseif changeType == EFFECT_RESULT_FADED then
            SetMemory(STATE_FREE, 0, cleanName, isBossEvent, SOURCE_EVENT)
        else
            SetMemory(state, endTimeMs, cleanName, isBossEvent, SOURCE_EVENT)
        end
    end
end

function Tracker.ShowTest()
    if not CanShowHud() then return end

    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    hasVisibleData = true
    isTrackingBoss = false
    UpdateVisuals(STATE_ACTIVE, 7000, GetString(EZOM_OFF_BALANCE_TEST_TARGET), false, SOURCE_DIRECT)
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        Tracker.ApplySettings()
    end, 5000)
end

function Tracker.DebugScanReticle()
    EnsureControl()

    if not EZOMetter.DebugLog then return end
    if not IsDebugEnabled() then
        if EZOMetter.Print then
            EZOMetter.Print(GetString(EZOM_OFF_BALANCE_DEBUG_DISABLED))
        end
        return
    end

    if type(DoesUnitExist) ~= "function" or not DoesUnitExist("reticleover") then
        EZOMetter.DebugLog("[OffBalance] reticle scan: no target")
        if EZOMetter.Print then
            EZOMetter.Print(GetString(EZOM_OFF_BALANCE_DEBUG_SCAN_DONE))
        end
        return
    end

    local unitName = CleanUnitName(GetUnitName("reticleover"))
    local total = type(GetNumBuffs) == "function" and GetNumBuffs("reticleover") or 0
    EZOMetter.DebugLog(string.format("[OffBalance] reticle scan start target=%s buffs=%d", tostring(unitName), tonumber(total) or 0))

    if type(GetUnitBuffInfo) == "function" then
        for index = 1, total do
            local buffName, _, endTime, _, _, _, _, _, _, _, abilityId = GetUnitBuffInfo("reticleover", index)
            local state = MatchState(buffName, abilityId)
            EZOMetter.DebugLog(string.format(
                "[OffBalance] reticle buff #%d name=%s ability=%s state=%s remaining=%s",
                index,
                tostring(CleanUnitName(buffName)),
                GetAbilityDisplay(abilityId),
                tostring(GetStateName(state)),
                FormatSeconds(((endTime or 0) * 1000) - GetNowMs())
            ))
        end
    end

    if EZOMetter.Print then
        EZOMetter.Print(GetString(EZOM_OFF_BALANCE_DEBUG_SCAN_DONE))
    end
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    RegisterLibCombatDamage()
    RefreshUpdateRegistration()
end

function Tracker.Init()
    EnsureControl()
    RegisterLibCombatDamage()
    if EZOMetter_CombatSummary then
        statsTracker = EZOMetter_CombatSummary.CreateUptimeTracker({
            toleranceMs = SUMMARY_TOLERANCE_MS,
            getItems = function()
                return {
                    { key = "active", name = GetString(EZOM_OFF_BALANCE_SUMMARY_ACTIVE) },
                    { key = "cycle", name = GetString(EZOM_OFF_BALANCE_SUMMARY_CYCLE) },
                }
            end,
            getItemKey = function(item)
                return item.key
            end,
            getItemName = function(item)
                return item.name
            end,
            isItemRequired = function(item)
                if item and item.key == "active" and currentState == STATE_IMMUNE then return false end
                return true
            end,
            isItemActive = function(item)
                if item.key == "active" then
                    return currentState == STATE_ACTIVE
                end
                if item.key == "cycle" then
                    return currentState == STATE_ACTIVE or currentState == STATE_IMMUNE
                end
                return false
            end,
        })
    end
    damageTracker = CreateDamageTracker()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_OffBalanceCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_OffBalanceEffects", EVENT_EFFECT_CHANGED, OnEffectChanged)

    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

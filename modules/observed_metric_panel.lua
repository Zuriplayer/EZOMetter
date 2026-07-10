-- Factory for compact LibCombat panels such as observed damage and healing.
EZOMetter_ObservedMetricPanel = EZOMetter_ObservedMetricPanel or {}

local Factory = EZOMetter_ObservedMetricPanel
local ADDON_NAME = "EZOMetter"
local WIDTH = 250
local HEIGHT = 104
local PADDING = 10
local LABEL_WIDTH = 98
local VALUE_WIDTH = 122
local ROW_HEIGHT = 30
local WINDOW_MS = 3000

local ROW_DEFS = {
    { key = "instant", labelKey = "rowInstantString" },
    { key = "average", labelKey = "rowAverageString" },
    { key = "group", labelKey = "rowGroupString" },
}

local function Number(value)
    return tonumber(value) or 0
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

local function HasLibCombat()
    return LibCombat ~= nil
        and LIBCOMBAT_EVENT_FIGHTRECAP ~= nil
        and type(LibCombat.RegisterCallbackType) == "function"
end

local function CanShowHud()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.CanShowHud and EZOMetter_VisualContext.CanShowHud()
end

local function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function GetRole()
    return EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.role or "dd"
end

local function GetStringByName(name)
    local id = name and _G[name]
    if id then
        return GetString(id)
    end
    return tostring(name or "")
end

local function Pick(data, keys)
    if not data or not keys then return 0 end
    if type(keys) == "string" then
        return Number(data[keys])
    end
    for _, key in ipairs(keys) do
        if data[key] ~= nil then
            return Number(data[key])
        end
    end
    return 0
end

local function FormatNumber(value)
    value = Number(value)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(math.floor(value + 0.5))
    end
    return tostring(math.floor(value + 0.5))
end

local function FormatRate(value)
    value = Number(value)
    if value >= 1000000 then
        return string.format("%.2fm", value / 1000000)
    end
    if value >= 10000 then
        return string.format("%.1fk", value / 1000)
    end
    if value >= 1000 then
        return string.format("%.2fk", value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

local function FormatPercent(value)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, Number(value))))
end

local function FormatDurationMs(ms)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatSeconds(Number(ms))
    end
    return string.format("%.1f", Number(ms) / 1000)
end

local function Share(myValue, totalValue)
    myValue = Number(myValue)
    totalValue = Number(totalValue)
    if totalValue <= 0 then return nil end
    return (myValue / totalValue) * 100
end

local function CopyTable(data)
    if not data then return nil end
    local copy = {}
    for key, value in pairs(data) do
        copy[key] = value
    end
    return copy
end

function Factory.Create(config)
    config = config or {}

    local Tracker = {}
    local callbackName = config.callbackName or (ADDON_NAME .. "ObservedMetric")
    local controlName = config.controlName or (ADDON_NAME .. "ObservedMetricTracker")
    local settingsKey = config.settingsKey
    local roleOnlyKey = config.roleOnlyKey
    local roleOnlyValue = config.roleOnlyValue
    local defaultY = Number(config.defaultY)
    local control
    local backdrop
    local rows = {}
    local isCombat = false
    local currentData
    local lastCombatData
    local lastRawData
    local snapshots = {}
    local callbackRegistered = false
    local combatStartMs = 0
    local combatDurationMs = 0
    local lastCombatEndMs = 0
    local combatBaseline

    local function GetSettings()
        if not EZOMetter.sv or not settingsKey then return nil end
        EZOMetter.sv[settingsKey] = EZOMetter.sv[settingsKey] or {}
        return EZOMetter.sv[settingsKey]
    end

    local function IsEnabled()
        local settings = GetSettings()
        if not settings or settings.enabled ~= true then return false end
        if roleOnlyKey and settings[roleOnlyKey] ~= false and GetRole() ~= roleOnlyValue then
            return false
        end
        return true
    end

    local function GetActiveSeconds(data)
        if not data then return 0 end
        local activeTime = Number(data.activeTime)
        if activeTime > 0 then return activeTime end
        return Number(data.activeDurationMs) / 1000
    end

    local function GetBossSeconds(data)
        if not data then return 0 end
        local bossTime = Number(data.bossTime)
        if bossTime > 0 then return bossTime end
        return GetActiveSeconds(data)
    end

    local function IsGroupObserved(data)
        return data
            and data.group == true
            and (Number(data.groupTotal) > 0 or Number(data.groupRate) > 0)
    end

    local function CopyData(rawData)
        if not rawData then return nil end

        local activeTime = Pick(rawData, config.activeTimeKeys)
        local groupRate = Pick(rawData, config.groupRateKeys)
        local groupTotal = Pick(rawData, config.groupTotalKeys)
        if groupTotal <= 0 and groupRate > 0 and activeTime > 0 then
            groupTotal = groupRate * activeTime
        end

        return {
            rate = Pick(rawData, config.rateKeys),
            groupRate = groupRate,
            bossRate = Pick(rawData, config.bossRateKeys),
            bossGroupRate = Pick(rawData, config.bossGroupRateKeys),
            total = Pick(rawData, config.totalKeys),
            groupTotal = groupTotal,
            bossTotal = Pick(rawData, config.bossTotalKeys),
            bossGroupTotal = Pick(rawData, config.bossGroupTotalKeys),
            activeTime = activeTime,
            bossTime = Pick(rawData, config.bossTimeKeys),
            group = rawData.group == true,
            bossfight = rawData.bossfight == true or rawData.bossFight == true,
            receivedAtMs = GetNowMs(),
            combatDurationMs = Number(rawData.combatDurationMs),
            activeDurationMs = Number(rawData[config.durationMsKey or ""]),
        }
    end

    local function RecalculateRate(data)
        if not data then return end

        local activeSeconds = GetActiveSeconds(data)
        if activeSeconds > 0 then
            local seconds = math.max(1, activeSeconds)
            data.rate = math.floor(data.total / seconds + 0.5)
            data.groupRate = math.floor(data.groupTotal / seconds + 0.5)
            data.activeTime = seconds
            data.activeDurationMs = seconds * 1000
        end

        if config.bossTotalKeys then
            local bossSeconds = GetBossSeconds(data)
            if bossSeconds > 0 then
                local seconds = math.max(1, bossSeconds)
                data.bossRate = math.floor(data.bossTotal / seconds + 0.5)
                data.bossGroupRate = math.floor(data.bossGroupTotal / seconds + 0.5)
                data.bossTime = seconds
            end
        end
    end

    local function GetCombatWindowDurationMs(nowMs)
        nowMs = nowMs or GetNowMs()
        if isCombat and combatStartMs > 0 then
            return math.max(0, nowMs - combatStartMs)
        end
        return math.max(0, combatDurationMs)
    end

    local function ApplyCombatWindow(rawData)
        if not rawData then return nil end

        local data = rawData.total ~= nil and CopyTable(rawData) or CopyData(rawData)
        local durationMs = GetCombatWindowDurationMs(data.receivedAtMs)
        data.combatDurationMs = durationMs

        local baseline = combatBaseline
        if baseline
            and (
                Number(data.total) < Number(baseline.total)
                or Number(data.activeTime) < Number(baseline.activeTime)
            )
        then
            baseline = nil
            combatBaseline = nil
        end

        if baseline then
            data.total = math.max(0, data.total - Number(baseline.total))
            data.groupTotal = math.max(0, data.groupTotal - Number(baseline.groupTotal))
            data.bossTotal = math.max(0, data.bossTotal - Number(baseline.bossTotal))
            data.bossGroupTotal = math.max(0, data.bossGroupTotal - Number(baseline.bossGroupTotal))
            data.activeTime = math.max(0, data.activeTime - Number(baseline.activeTime))
            data.bossTime = math.max(0, data.bossTime - Number(baseline.bossTime))
        end

        data.activeDurationMs = GetActiveSeconds(data) * 1000
        RecalculateRate(data)

        data.group = data.group == true or data.groupTotal > 0
        data.bossfight = data.bossfight == true or data.bossTotal > 0
        return data
    end

    local function ResetSnapshots()
        snapshots = {}
    end

    local function AddSnapshot(data)
        if not data then return end

        local previous = snapshots[#snapshots]
        if previous and Number(data.total) < Number(previous.total) then
            ResetSnapshots()
        end

        table.insert(snapshots, {
            ms = GetNowMs(),
            total = Number(data.total),
            groupTotal = Number(data.groupTotal),
            bossTotal = Number(data.bossTotal),
            bossGroupTotal = Number(data.bossGroupTotal),
        })

        local cutoff = GetNowMs() - WINDOW_MS
        while #snapshots > 1 and snapshots[2].ms < cutoff do
            table.remove(snapshots, 1)
        end
    end

    local function GetWindowRate(totalKey)
        local newest = snapshots[#snapshots]
        local oldest = snapshots[1]
        if not newest or not oldest or newest.ms <= oldest.ms then return 0 end

        local delta = Number(newest[totalKey]) - Number(oldest[totalKey])
        if delta < 0 then return 0 end
        return delta / ((newest.ms - oldest.ms) / 1000)
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
        control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or defaultY)
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
            backdrop:SetEdgeColor(0.35, 0.55, 1, 0.95)
        end
    end

    local function BuildTooltipText()
        local data = isCombat and currentData or lastCombatData
        if not data then
            if not HasLibCombat() then
                return GetStringByName(config.libMissingString)
            end
            return GetString(EZOM_LAST_COMBAT_NO_DATA)
        end

        local title = isCombat and GetStringByName(config.summaryCurrentString) or GetStringByName(config.summaryLastString)
        local totalShare = Share(data.total, data.groupTotal)
        local bossShare = Share(data.bossTotal, data.bossGroupTotal)
        local lines = {
            title,
            GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatDurationMs(data.combatDurationMs or (data.activeTime * 1000)) .. "s",
            GetStringByName(config.summaryTimeString) .. ": " .. FormatDurationMs(data.activeDurationMs or (data.activeTime * 1000)) .. "s",
            GetStringByName(config.summaryTotalString) .. ": " .. FormatNumber(data.total),
            GetStringByName(config.summaryAverageString) .. ": " .. FormatRate(data.rate),
        }

        if IsGroupObserved(data) then
            table.insert(lines, GetStringByName(config.summaryGroupTotalString) .. ": " .. FormatNumber(data.groupTotal))
            table.insert(lines, GetStringByName(config.summaryGroupShareString) .. ": " .. FormatPercent(totalShare or 0))
        else
            table.insert(lines, GetStringByName(config.groupUnavailableString))
        end

        if config.bossTotalKeys and data.bossfight and data.bossTotal > 0 then
            table.insert(lines, GetStringByName(config.summaryBossTotalString) .. ": " .. FormatNumber(data.bossTotal))
            if data.bossGroupTotal > 0 then
                table.insert(lines, GetStringByName(config.summaryBossShareString) .. ": " .. FormatPercent(bossShare or 0))
            end
        end

        if IsGroupObserved(data) then
            table.insert(lines, GetStringByName(config.summaryObservedNoteString))
        end

        return table.concat(lines, "\n")
    end

    function Tracker.GetReportSection()
        if not lastCombatData then return nil end
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

    local function CreateRow(parent, key, top)
        local wm = WINDOW_MANAGER
        local row = {}

        row.name = wm:CreateControl(controlName .. key .. "Name", parent, CT_LABEL)
        row.name:SetAnchor(TOPLEFT, parent, TOPLEFT, PADDING, top)
        row.name:SetDimensions(LABEL_WIDTH, ROW_HEIGHT)
        row.name:SetFont("ZoFontWinH4")
        row.name:SetColor(0.78, 0.82, 0.9, 1)
        row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.name:SetMaxLineCount(1)
        row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        row.value = wm:CreateControl(controlName .. key .. "Value", parent, CT_LABEL)
        row.value:SetAnchor(TOPLEFT, row.name, TOPRIGHT, 6, 0)
        row.value:SetDimensions(VALUE_WIDTH, ROW_HEIGHT)
        row.value:SetFont("ZoFontWinH3")
        row.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        row.value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.value:SetMaxLineCount(1)

        rows[key] = row
    end

    local function EnsureControl()
        if control then return control end

        local wm = WINDOW_MANAGER
        control = wm:CreateTopLevelWindow(controlName)
        control:SetDimensions(WIDTH, HEIGHT)
        control:SetClampedToScreen(true)
        control:SetDrawTier(DT_HIGH)
        control:SetHidden(true)
        control:SetHandler("OnMoveStop", SavePosition)
        control:SetHandler("OnMouseEnter", ShowTooltip)
        control:SetHandler("OnMouseExit", HideTooltip)

        backdrop = wm:CreateControl(controlName .. "Backdrop", control, CT_BACKDROP)
        backdrop:SetAnchorFill(control)
        backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
        ApplyStyle()

        for index, def in ipairs(ROW_DEFS) do
            CreateRow(control, def.key, 7 + ((index - 1) * ROW_HEIGHT))
            rows[def.key].name:SetText(GetStringByName(config[def.labelKey]))
        end

        ApplyPosition()
        SetMoveMode(IsHudUnlocked())
        if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
            EZOMetter_VisualContext.AddHudFragment(control)
        end
        return control
    end

    local function UpdateVisuals()
        EnsureControl()

        for _, def in ipairs(ROW_DEFS) do
            rows[def.key].name:SetText(GetStringByName(config[def.labelKey]))
            rows[def.key].value:SetColor(0.9, 0.9, 0.9, 1)
        end
        rows.instant.value:SetColor(0.35, 1, 0.45, 1)
        rows.group.value:SetColor(0.55, 0.8, 1, 1)

        if not HasLibCombat() then
            rows.instant.value:SetText(GetStringByName(config.libShortString))
            rows.average.value:SetText("--")
            rows.group.value:SetText("--")
            return
        end

        local data = isCombat and currentData or lastCombatData
        if not data then
            rows.instant.value:SetText("--")
            rows.average.value:SetText("--")
            rows.group.value:SetText(GetStringByName(config.groupUnavailableShortString))
            return
        end

        local instantRate = isCombat and GetWindowRate("total") or Number(data.rate)
        rows.instant.value:SetText(FormatRate(instantRate))
        rows.average.value:SetText(FormatRate(data.rate))

        if IsGroupObserved(data) then
            local groupShare = Share(data.rate, data.groupRate)
            rows.group.value:SetText(FormatPercent(groupShare or 0) .. " | " .. FormatRate(data.groupRate))
        else
            rows.group.value:SetText(GetStringByName(config.groupUnavailableShortString))
        end
    end

    local function UpdateVisibility()
        EnsureControl()

        local settings = GetSettings() or {}
        local hidden = false
        if not CanShowHud() then
            hidden = true
        elseif IsHudUnlocked() then
            hidden = false
        elseif not IsEnabled() then
            hidden = true
        elseif settings.onlyCombat ~= false and not isCombat and not lastCombatData then
            hidden = true
        end

        control:SetHidden(hidden)
    end

    local function Refresh()
        UpdateVisuals()
        UpdateVisibility()
    end

    local function OnFightRecap(_, data)
        local rawData = CopyData(data)
        if not rawData then return end

        lastRawData = rawData
        currentData = ApplyCombatWindow(rawData)
        if currentData then
            AddSnapshot(currentData)
            local recentCombatEnd = lastCombatEndMs > 0 and (GetNowMs() - lastCombatEndMs) <= 3000
            if isCombat or recentCombatEnd then
                lastCombatData = currentData
            end
        end
        Refresh()
    end

    local function RegisterLibCombat()
        if callbackRegistered or not HasLibCombat() then return end
        LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTRECAP, OnFightRecap, callbackName)
        callbackRegistered = true
    end

    local function OnCombatState(_, inCombat)
        local nowMs = GetNowMs()
        isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
        if isCombat then
            combatStartMs = nowMs
            combatDurationMs = 0
            lastCombatEndMs = 0
            combatBaseline = CopyTable(lastRawData)
            currentData = nil
            ResetSnapshots()
        else
            if combatStartMs > 0 then
                combatDurationMs = math.max(0, nowMs - combatStartMs)
                lastCombatEndMs = nowMs
            end
            if currentData then
                currentData.combatDurationMs = combatDurationMs
                lastCombatData = currentData
            end
            ResetSnapshots()
        end
        Refresh()
    end

    function Tracker.ApplySettings()
        EnsureControl()
        ApplyPosition()
        SetMoveMode(IsHudUnlocked())
        ApplyStyle()
        RegisterLibCombat()
        Refresh()
    end

    function Tracker.Init()
        EnsureControl()
        RegisterLibCombat()

        if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
            EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
        end

        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_" .. callbackName .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
        OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
    end

    return Tracker
end

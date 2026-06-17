-- Panel de dano observado basado en LibCombat.
EZOMetter_ObservedDamage = EZOMetter_ObservedDamage or {}

local Tracker = EZOMetter_ObservedDamage
local ADDON_NAME = "EZOMetter"
local CALLBACK_NAME = "EZOMetterObservedDamage"
local CONTROL_NAME = "EZOMetterObservedDamageTracker"
local WIDTH = 250
local HEIGHT = 104
local PADDING = 10
local LABEL_WIDTH = 98
local VALUE_WIDTH = 122
local ROW_HEIGHT = 30
local WINDOW_MS = 3000

local control
local backdrop
local rows = {}
local isCombat = false
local currentData
local lastCombatData
local lastRawData
local snapshots = {}
local callbackRegistered = false
local IsHudUnlocked
local combatStartMs = 0
local combatDurationMs = 0
local lastCombatEndMs = 0
local combatBaseline

local ROW_DEFS = {
    { key = "instant", labelString = "EZOM_DAMAGE_ROW_INSTANT" },
    { key = "average", labelString = "EZOM_DAMAGE_ROW_AVERAGE" },
    { key = "group", labelString = "EZOM_DAMAGE_ROW_GROUP" },
}

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.observedDamage = EZOMetter.sv.observedDamage or {}
    return EZOMetter.sv.observedDamage
end

local function GetRole()
    return EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.role or "dd"
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

function IsHudUnlocked()
    return EZOMetter_VisualContext and EZOMetter_VisualContext.IsHudUnlocked and EZOMetter_VisualContext.IsHudUnlocked()
end

local function IsEnabled()
    local settings = GetSettings()
    if not settings or settings.enabled ~= true then return false end
    if settings.ddOnly ~= false and GetRole() ~= "dd" then return false end
    return true
end

local function Number(value)
    return tonumber(value) or 0
end

local function FormatNumber(value)
    value = Number(value)
    if ZO_CommaDelimitNumber then
        return ZO_CommaDelimitNumber(math.floor(value + 0.5))
    end
    return tostring(math.floor(value + 0.5))
end

local function FormatDps(value)
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

local function IsGroupObserved(data)
    return data and data.group == true and Number(data.damageOutTotalGroup) > 0
end

local function CopyData(data)
    if not data then return nil end
    return {
        DPSOut = Number(data.DPSOut),
        groupDPSOut = Number(data.groupDPSOut),
        bossDPSOut = Number(data.bossDPSOut),
        bossDPSOutGroup = Number(data.bossDPSOutGroup),
        damageOutTotal = Number(data.damageOutTotal),
        damageOutTotalGroup = Number(data.damageOutTotalGroup),
        bossDamageTotal = Number(data.bossDamageTotal),
        bossDamageTotalGroup = Number(data.bossDamageTotalGroup),
        dpstime = Number(data.dpstime),
        bossTime = Number(data.bossTime),
        group = data.group == true,
        bossfight = data.bossfight == true or data.bossFight == true,
        receivedAtMs = GetNowMs(),
        combatDurationMs = Number(data.combatDurationMs),
        dpsDurationMs = Number(data.dpsDurationMs),
    }
end

local function GetDpsSeconds(data)
    if not data then return 0 end
    local dpstime = Number(data.dpstime)
    if dpstime > 0 then return dpstime end
    return Number(data.dpsDurationMs) / 1000
end

local function GetBossSeconds(data)
    if not data then return 0 end
    local bossTime = Number(data.bossTime)
    if bossTime > 0 then return bossTime end
    return GetDpsSeconds(data)
end

local function RecalculateDps(data)
    if not data then return end

    local dpsSeconds = GetDpsSeconds(data)
    if dpsSeconds > 0 then
        local seconds = math.max(1, dpsSeconds)
        data.DPSOut = math.floor(data.damageOutTotal / seconds + 0.5)
        data.groupDPSOut = math.floor(data.damageOutTotalGroup / seconds + 0.5)
        data.dpstime = seconds
        data.dpsDurationMs = seconds * 1000
    end

    local bossSeconds = GetBossSeconds(data)
    if bossSeconds > 0 then
        local seconds = math.max(1, bossSeconds)
        data.bossDPSOut = math.floor(data.bossDamageTotal / seconds + 0.5)
        data.bossDPSOutGroup = math.floor(data.bossDamageTotalGroup / seconds + 0.5)
        data.bossTime = seconds
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

    local data = CopyData(rawData)
    local durationMs = GetCombatWindowDurationMs(data.receivedAtMs)
    data.combatDurationMs = durationMs

    local baseline = combatBaseline
    if baseline
        and (
            Number(data.damageOutTotal) < Number(baseline.damageOutTotal)
            or Number(data.dpstime) < Number(baseline.dpstime)
        )
    then
        baseline = nil
        combatBaseline = nil
    end

    if baseline then
        data.damageOutTotal = math.max(0, data.damageOutTotal - Number(baseline.damageOutTotal))
        data.damageOutTotalGroup = math.max(0, data.damageOutTotalGroup - Number(baseline.damageOutTotalGroup))
        data.bossDamageTotal = math.max(0, data.bossDamageTotal - Number(baseline.bossDamageTotal))
        data.bossDamageTotalGroup = math.max(0, data.bossDamageTotalGroup - Number(baseline.bossDamageTotalGroup))
        data.dpstime = math.max(0, data.dpstime - Number(baseline.dpstime))
        data.bossTime = math.max(0, data.bossTime - Number(baseline.bossTime))
    end

    data.dpsDurationMs = GetDpsSeconds(data) * 1000
    RecalculateDps(data)

    data.group = data.group == true or data.damageOutTotalGroup > 0
    data.bossfight = data.bossfight == true or data.bossDamageTotal > 0
    return data
end

local function ResetSnapshots()
    snapshots = {}
end

local function AddSnapshot(data)
    if not data then return end

    local previous = snapshots[#snapshots]
    if previous and Number(data.damageOutTotal) < Number(previous.damageOutTotal) then
        ResetSnapshots()
    end

    table.insert(snapshots, {
        ms = GetNowMs(),
        damageOutTotal = Number(data.damageOutTotal),
        damageOutTotalGroup = Number(data.damageOutTotalGroup),
        bossDamageTotal = Number(data.bossDamageTotal),
        bossDamageTotalGroup = Number(data.bossDamageTotalGroup),
    })

    local cutoff = GetNowMs() - WINDOW_MS
    while #snapshots > 1 and snapshots[2].ms < cutoff do
        table.remove(snapshots, 1)
    end
end

local function GetWindowDps(totalKey)
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 315)
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
            return GetString(EZOM_DAMAGE_LIBCOMBAT_MISSING)
        end
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local title = isCombat and GetString(EZOM_DAMAGE_SUMMARY_CURRENT) or GetString(EZOM_DAMAGE_SUMMARY_LAST)
    local totalShare = Share(data.damageOutTotal, data.damageOutTotalGroup)
    local bossShare = Share(data.bossDamageTotal, data.bossDamageTotalGroup)
    local lines = {
        title,
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatDurationMs(data.combatDurationMs or (data.dpstime * 1000)) .. "s",
        GetString(EZOM_DAMAGE_SUMMARY_DPS_TIME) .. ": " .. FormatDurationMs(data.dpsDurationMs or (data.dpstime * 1000)) .. "s",
        GetString(EZOM_DAMAGE_SUMMARY_DAMAGE) .. ": " .. FormatNumber(data.damageOutTotal),
        GetString(EZOM_DAMAGE_SUMMARY_DPS) .. ": " .. FormatDps(data.DPSOut),
    }

    if IsGroupObserved(data) then
        table.insert(lines, GetString(EZOM_DAMAGE_SUMMARY_GROUP_DAMAGE) .. ": " .. FormatNumber(data.damageOutTotalGroup))
        table.insert(lines, GetString(EZOM_DAMAGE_SUMMARY_GROUP_SHARE) .. ": " .. FormatPercent(totalShare or 0))
    else
        table.insert(lines, GetString(EZOM_DAMAGE_GROUP_UNAVAILABLE))
    end

    if data.bossfight and data.bossDamageTotal > 0 then
        table.insert(lines, GetString(EZOM_DAMAGE_SUMMARY_BOSS_DAMAGE) .. ": " .. FormatNumber(data.bossDamageTotal))
        if data.bossDamageTotalGroup > 0 then
            table.insert(lines, GetString(EZOM_DAMAGE_SUMMARY_BOSS_SHARE) .. ": " .. FormatPercent(bossShare or 0))
        end
    end

    if IsGroupObserved(data) then
        table.insert(lines, GetString(EZOM_DAMAGE_SUMMARY_OBSERVED_NOTE))
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

    row.name = wm:CreateControl(CONTROL_NAME .. key .. "Name", parent, CT_LABEL)
    row.name:SetAnchor(TOPLEFT, parent, TOPLEFT, PADDING, top)
    row.name:SetDimensions(LABEL_WIDTH, ROW_HEIGHT)
    row.name:SetFont("ZoFontWinH4")
    row.name:SetColor(0.78, 0.82, 0.9, 1)
    row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.name:SetMaxLineCount(1)
    row.name:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    row.value = wm:CreateControl(CONTROL_NAME .. key .. "Value", parent, CT_LABEL)
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
    control = wm:CreateTopLevelWindow(CONTROL_NAME)
    control:SetDimensions(WIDTH, HEIGHT)
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

    for index, def in ipairs(ROW_DEFS) do
        CreateRow(control, def.key, 7 + ((index - 1) * ROW_HEIGHT))
        rows[def.key].name:SetText(GetString(_G[def.labelString]))
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
        rows[def.key].name:SetText(GetString(_G[def.labelString]))
        rows[def.key].value:SetColor(0.9, 0.9, 0.9, 1)
    end
    rows.instant.value:SetColor(0.35, 1, 0.45, 1)
    rows.group.value:SetColor(0.55, 0.8, 1, 1)

    if not HasLibCombat() then
        rows.instant.value:SetText(GetString(EZOM_DAMAGE_LIBCOMBAT_SHORT))
        rows.average.value:SetText("--")
        rows.group.value:SetText("--")
        return
    end

    local data = isCombat and currentData or lastCombatData
    if not data then
        rows.instant.value:SetText("--")
        rows.average.value:SetText("--")
        rows.group.value:SetText(GetString(EZOM_DAMAGE_GROUP_UNAVAILABLE_SHORT))
        return
    end

    local instantDps = isCombat and GetWindowDps("damageOutTotal") or Number(data.DPSOut)
    rows.instant.value:SetText(FormatDps(instantDps))
    rows.average.value:SetText(FormatDps(data.DPSOut))

    if IsGroupObserved(data) then
        local groupShare = Share(data.DPSOut, data.groupDPSOut)
        rows.group.value:SetText(FormatPercent(groupShare or 0) .. " | " .. FormatDps(data.groupDPSOut))
    else
        rows.group.value:SetText(GetString(EZOM_DAMAGE_GROUP_UNAVAILABLE_SHORT))
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
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_FIGHTRECAP, OnFightRecap, CALLBACK_NAME)
    callbackRegistered = true
end

local function OnCombatState(_, inCombat)
    local nowMs = GetNowMs()
    isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    if isCombat then
        combatStartMs = nowMs
        combatDurationMs = 0
        lastCombatEndMs = 0
        combatBaseline = lastRawData and CopyData(lastRawData) or nil
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

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ObservedDamageCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

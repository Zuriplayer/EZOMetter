-- Tracker separado para stats ofensivos utiles de DD.
EZOMetter_DDStats = EZOMetter_DDStats or {}

local Tracker = EZOMetter_DDStats
local ADDON_NAME = "EZOMetter"
local CALLBACK_NAME = "EZOMetterDDStats"
local CONTROL_NAME = "EZOMetterDDStatsTracker"
local UPDATE_INTERVAL_MS = 250
local WIDTH = 320
local HEIGHT = 126
local PADDING = 12
local ROW_HEIGHT = 22
local NAME_WIDTH = 92
local VALUE_WIDTH = 86
local EFFECTIVE_WIDTH = 70
local EFFECTIVE_COLOR = { r = 0.78, g = 0.9, b = 1, a = 1 }
local EFFECTIVE_OVERCAP_COLOR = { r = 1, g = 0.35, b = 0.25, a = 1 }

local BAND_LOW = "low"
local BAND_OK = "ok"
local BAND_HIGH = "high"
local BAND_UNKNOWN = "unknown"

local CRIT_RATING_PER_100_PERCENT = 21918
local CRIT_DAMAGE_BASE_PERCENT = 50

local control
local backdrop
local titleLabel
local rows = {}
local updateRegistered = false
local forceShow = false
local isCombat = false
local currentValues = {}
local statsTracker
local effectiveStatsTracker
local overcapStatsTracker
local lastCombatSummary
local lastEffectiveCombatSummary
local lastOvercapCombatSummary
local damageWeightedTracker
local lastDamageWeightedSummary
local libCombatRegistered = false
local IsHudUnlocked

local STAT_DEFS = {
    {
        key = "damage",
        nameString = "EZOM_DD_STATS_DAMAGE",
        targetKey = "damageTarget",
        highKey = nil,
        format = "number",
        positiveHigh = true,
    },
    {
        key = "crit",
        nameString = "EZOM_DD_STATS_CRIT",
        targetKey = "critTarget",
        highKey = "critHigh",
        format = "percent",
        positiveHigh = true,
    },
    {
        key = "penetration",
        nameString = "EZOM_DD_STATS_PENETRATION",
        targetKey = "penetrationTarget",
        highKey = "penetrationHigh",
        format = "number",
        positiveHigh = false,
    },
    {
        key = "critDamage",
        nameString = "EZOM_DD_STATS_CRIT_DAMAGE",
        targetKey = "critDamageTarget",
        highKey = "critDamageHigh",
        format = "percent",
        positiveHigh = false,
    },
}

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.ddStats = EZOMetter.sv.ddStats or {}
    return EZOMetter.sv.ddStats
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

local function GetStatConstant(name)
    return _G and _G[name] or nil
end

local function GetLocalizedString(name, fallback)
    local stringId = _G and _G[name] or nil
    if stringId ~= nil and type(GetString) == "function" then
        return GetString(stringId)
    end
    return fallback or tostring(name or "")
end

local function ReadPlayerStatByName(name)
    local statType = GetStatConstant(name)
    if statType == nil or type(GetPlayerStat) ~= "function" then
        return nil
    end
    return tonumber(GetPlayerStat(statType))
end

local function ReadBestPlayerStat(names)
    local best = nil
    for _, name in ipairs(names) do
        local value = ReadPlayerStatByName(name)
        if value and (not best or value > best) then
            best = value
        end
    end
    return best
end

local function NormalizeCritChance(raw)
    raw = tonumber(raw)
    if not raw then return nil end
    if raw <= 1 then return raw * 100 end
    if raw <= 100 then return raw end
    return (raw / CRIT_RATING_PER_100_PERCENT) * 100
end

local function NormalizeCritDamage(raw)
    raw = tonumber(raw)
    if not raw then return nil end
    if raw <= 1 then raw = raw * 100 end

    -- ESO often exposes critical damage as bonus over the base 50%.
    if raw <= 75 then
        return CRIT_DAMAGE_BASE_PERCENT + raw
    end
    return raw
end

local function ReadAdvancedCritDamage()
    if type(GetAdvancedStatValue) ~= "function" or ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE == nil then
        return nil
    end

    local _, _, percentValue = GetAdvancedStatValue(ADVANCED_STAT_DISPLAY_TYPE_CRITICAL_DAMAGE)
    percentValue = tonumber(percentValue)
    if not percentValue then return nil end
    return CRIT_DAMAGE_BASE_PERCENT + percentValue
end

local function ReadCritDamage()
    local advancedValue = ReadAdvancedCritDamage()
    if advancedValue then
        return advancedValue
    end

    local raw = ReadBestPlayerStat({
        "STAT_CRITICAL_DAMAGE",
        "STAT_CRITICAL_DAMAGE_DONE",
        "STAT_CRITICAL_DAMAGE_BONUS",
        "STAT_WEAPON_CRITICAL_DAMAGE",
        "STAT_SPELL_CRITICAL_DAMAGE",
    })
    return NormalizeCritDamage(raw)
end

local function ReadStatValue(key)
    if key == "damage" then
        return ReadBestPlayerStat({ "STAT_WEAPON_POWER", "STAT_SPELL_POWER" })
    end
    if key == "crit" then
        return NormalizeCritChance(ReadBestPlayerStat({ "STAT_CRITICAL_STRIKE", "STAT_SPELL_CRITICAL" }))
    end
    if key == "penetration" then
        return ReadBestPlayerStat({ "STAT_PHYSICAL_PENETRATION", "STAT_SPELL_PENETRATION" })
    end
    if key == "critDamage" then
        return ReadCritDamage()
    end
    return nil
end

local function GetTarget(def)
    local settings = GetSettings() or {}
    return tonumber(settings[def.targetKey]) or 0
end

local function GetHighTarget(def)
    if not def.highKey then return nil end
    local settings = GetSettings() or {}
    local value = tonumber(settings[def.highKey])
    if not value or value <= 0 then return nil end
    return value
end

local function GetBand(def, value)
    value = tonumber(value)
    if not value then return BAND_UNKNOWN end

    local target = GetTarget(def)
    local high = GetHighTarget(def)
    if target > 0 and value < target then
        return BAND_LOW
    end
    if high and value > high then
        return BAND_HIGH
    end
    return BAND_OK
end

local function GetEffectiveBand(def, ownValue, effectiveValue)
    effectiveValue = tonumber(effectiveValue)
    if not effectiveValue then return BAND_UNKNOWN end

    if def.key == "penetration" then
        local cap = EZOMetter_DDEffectiveStats and EZOMetter_DDEffectiveStats.GetTargetResistance(GetSettings()) or 18200
        if effectiveValue < cap then
            return BAND_LOW
        end
        if effectiveValue > cap then
            return BAND_HIGH
        end
        return BAND_OK
    end

    return GetBand(def, effectiveValue)
end

local function GetEffectiveCap(def)
    if def.key == "penetration" and EZOMetter_DDEffectiveStats and EZOMetter_DDEffectiveStats.GetTargetResistance then
        return EZOMetter_DDEffectiveStats.GetTargetResistance(GetSettings())
    end
    if def.key == "critDamage" and EZOMetter_DDEffectiveStats and EZOMetter_DDEffectiveStats.GetCritDamageCap then
        return EZOMetter_DDEffectiveStats.GetCritDamageCap(GetSettings())
    end
    return nil
end

local function GetBandColor(band, positiveHigh)
    if band == BAND_LOW then return 1, 0.35, 0.2, 1 end
    if band == BAND_HIGH and positiveHigh then return 0.25, 0.8, 1, 1 end
    if band == BAND_HIGH then return 1, 0.62, 0.2, 1 end
    if band == BAND_OK then return 0.35, 1, 0.4, 1 end
    return 0.72, 0.72, 0.72, 1
end

local function FormatValue(def, value)
    value = tonumber(value)
    if not value then return "--" end
    if def.format == "percent" then
        return string.format("%.1f%%", value)
    end
    return tostring(math.floor(value + 0.5))
end

local function ShouldShowEffective(def)
    return def.key == "penetration" or def.key == "critDamage"
end

local function FormatOwnValue(def, data)
    if not data then return "--" end
    return FormatValue(def, data.ownValue or data.value)
end

local function FormatEffectiveValue(def, data)
    if not data then return "--" end
    return FormatValue(def, data.effectiveValue or data.value)
end

local function GetOvercapValue(def, data)
    if not ShouldShowEffective(def) or not data then return nil end

    local cap = GetEffectiveCap(def)
    local uncappedValue = tonumber(data.uncappedEffectiveValue or data.effectiveValue)
    if not cap or not uncappedValue then return nil end
    return math.max(0, uncappedValue - cap)
end

local function FormatSeconds(ms)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatSeconds(ms)
    end
    return string.format("%.1f", math.max(0, tonumber(ms) or 0) / 1000)
end

local function FormatPercent(value)
    if EZOMetter_CombatSummary then
        return EZOMetter_CombatSummary.FormatPercent(value)
    end
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

local function GetBandPercent(row, band)
    if not row or not row.bandMs or (tonumber(row.requiredMs) or 0) <= 0 then return 0 end
    return ((row.bandMs[band] or 0) / row.requiredMs) * 100
end

local function GetDamageBandPercent(row, band)
    if not row or not row.bandDamage or (tonumber(row.damageWeight) or 0) <= 0 then return 0 end
    return ((row.bandDamage[band] or 0) / row.damageWeight) * 100
end

local function FormatBandBreakdown(prefix, lowPercent, okPercent, highPercent)
    return string.format(
        "  %s %s %s  %s %s  %s %s",
        prefix,
        GetString(EZOM_DD_STATS_SUMMARY_LOW),
        FormatPercent(lowPercent),
        GetString(EZOM_DD_STATS_SUMMARY_OK),
        FormatPercent(okPercent),
        GetString(EZOM_DD_STATS_SUMMARY_HIGH),
        FormatPercent(highPercent)
    )
end

local function FormatCapText(def)
    local cap = GetEffectiveCap(def)
    if not cap then return "" end
    return " " .. string.format("(%s %s)", GetString(EZOM_DD_STATS_SUMMARY_CAP), FormatValue(def, cap))
end

local function HasLibCombatDamage()
    return LibCombat ~= nil
        and LIBCOMBAT_EVENT_DAMAGE_OUT ~= nil
        and type(LibCombat.RegisterCallbackType) == "function"
end

local function RefreshCurrentValues()
    local settings = GetSettings()
    local ownValues = {}
    for _, def in ipairs(STAT_DEFS) do
        ownValues[def.key] = ReadStatValue(def.key)
    end

    local effectiveData = nil
    if EZOMetter_DDEffectiveStats and EZOMetter_DDEffectiveStats.BuildValues then
        effectiveData = EZOMetter_DDEffectiveStats.BuildValues(ownValues, settings)
    end

    for _, def in ipairs(STAT_DEFS) do
        local ownValue = ownValues[def.key]
        local effectiveValue = effectiveData and effectiveData.values and effectiveData.values[def.key] or ownValue
        local uncappedEffectiveValue = effectiveData and effectiveData.uncappedValues and effectiveData.uncappedValues[def.key] or effectiveValue
        local value = effectiveValue or ownValue

        currentValues[def.key] = {
            value = value,
            ownValue = ownValue,
            effectiveValue = effectiveValue,
            uncappedEffectiveValue = uncappedEffectiveValue,
            available = ownValue ~= nil,
            band = GetEffectiveBand(def, ownValue, uncappedEffectiveValue or effectiveValue),
        }
    end
end

local function GetTooltipSummary()
    if isCombat and statsTracker and statsTracker.GetCurrentSummary then
        local effectiveSummary = effectiveStatsTracker and effectiveStatsTracker:GetCurrentSummary() or nil
        local overcapSummary = overcapStatsTracker and overcapStatsTracker:GetCurrentSummary() or nil
        local weightedSummary = damageWeightedTracker and damageWeightedTracker:GetCurrentSummary() or nil
        return statsTracker:GetCurrentSummary(), effectiveSummary, overcapSummary, weightedSummary, GetString(EZOM_DD_STATS_SUMMARY_CURRENT)
    end
    return lastCombatSummary, lastEffectiveCombatSummary, lastOvercapCombatSummary, lastDamageWeightedSummary, GetString(EZOM_DD_STATS_SUMMARY_LAST)
end

local function AppendWeightedSummary(lines, weightedSummary)
    if not weightedSummary or not weightedSummary.hasData then return end

    table.insert(lines, "")
    table.insert(lines, GetString(EZOM_DD_STATS_WEIGHTED_TITLE))
    for _, def in ipairs(STAT_DEFS) do
        local row = weightedSummary.byKey and weightedSummary.byKey[def.key] or nil
        if row then
            if ShouldShowEffective(def) then
                table.insert(lines, GetLocalizedString(def.nameString, def.key) .. ":")
                table.insert(lines, string.format("  %s %s", GetString(EZOM_DD_STATS_SUMMARY_OWN), FormatValue(def, row.averageOwn)))
                table.insert(lines, string.format(
                    "  %s%s %s",
                    GetString(EZOM_DD_STATS_SUMMARY_EFFECTIVE),
                    FormatCapText(def),
                    FormatValue(def, row.averageEffective)
                ))
                table.insert(lines, string.format(
                    "  %s %s / %s",
                    GetString(EZOM_DD_STATS_SUMMARY_OVERCAP),
                    FormatValue(def, row.averageOvercap),
                    FormatValue(def, row.maxOvercap)
                ))
                table.insert(lines, FormatBandBreakdown(
                    GetString(EZOM_DD_STATS_WEIGHTED_BY_DAMAGE),
                    GetDamageBandPercent(row, BAND_LOW),
                    GetDamageBandPercent(row, BAND_OK),
                    GetDamageBandPercent(row, BAND_HIGH)
                ))
            else
                table.insert(lines, string.format(
                    "%s: %s",
                    GetLocalizedString(def.nameString, def.key),
                    FormatValue(def, row.averageOwn)
                ))
            end
        end
    end
end

local function BuildTooltipText()
    local summary, effectiveSummary, overcapSummary, weightedSummary, title = GetTooltipSummary()
    if not summary or not summary.hasData then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        title,
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(summary.durationMs) .. "s",
    }

    for _, def in ipairs(STAT_DEFS) do
        local row = summary.byKey and summary.byKey[def.key] or nil
        local effectiveRow = effectiveSummary and effectiveSummary.byKey and effectiveSummary.byKey[def.key] or nil
        local overcapRow = overcapSummary and overcapSummary.byKey and overcapSummary.byKey[def.key] or nil
        if row then
            if ShouldShowEffective(def) and effectiveRow then
                table.insert(lines, GetLocalizedString(def.nameString, def.key) .. ":")
                table.insert(lines, string.format(
                    "  %s %s / %s / %s",
                    GetString(EZOM_DD_STATS_SUMMARY_OWN),
                    FormatValue(def, row.minValue),
                    FormatValue(def, row.averageValue),
                    FormatValue(def, row.maxValue)
                ))
                table.insert(lines, string.format(
                    "  %s%s %s / %s / %s",
                    GetString(EZOM_DD_STATS_SUMMARY_EFFECTIVE),
                    FormatCapText(def),
                    FormatValue(def, effectiveRow.minValue),
                    FormatValue(def, effectiveRow.averageValue),
                    FormatValue(def, effectiveRow.maxValue)
                ))
                if overcapRow then
                    table.insert(lines, string.format(
                        "  %s %s / %s",
                        GetString(EZOM_DD_STATS_SUMMARY_OVERCAP),
                        FormatValue(def, overcapRow.averageValue),
                        FormatValue(def, overcapRow.maxValue)
                    ))
                end
                table.insert(lines, FormatBandBreakdown(
                    GetString(EZOM_DD_STATS_SUMMARY_TIME),
                    GetBandPercent(effectiveRow, BAND_LOW),
                    GetBandPercent(effectiveRow, BAND_OK),
                    GetBandPercent(effectiveRow, BAND_HIGH)
                ))
            else
                table.insert(lines, string.format(
                    "%s: %s / %s / %s",
                    GetLocalizedString(def.nameString, def.key),
                    FormatValue(def, row.minValue),
                    FormatValue(def, row.averageValue),
                    FormatValue(def, row.maxValue)
                ))
                table.insert(lines, FormatBandBreakdown(
                    GetString(EZOM_DD_STATS_SUMMARY_TIME),
                    GetBandPercent(row, BAND_LOW),
                    GetBandPercent(row, BAND_OK),
                    GetBandPercent(row, BAND_HIGH)
                ))
            end
        else
            table.insert(lines, GetLocalizedString(def.nameString, def.key) .. ": " .. GetString(EZOM_DD_STATS_UNAVAILABLE))
        end
    end

    AppendWeightedSummary(lines, weightedSummary)

    return table.concat(lines, "\n")
end

function Tracker.GetReportSection()
    if not lastCombatSummary or not lastCombatSummary.hasData then return nil end
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 170)
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
        backdrop:SetEdgeColor(0.45, 0.82, 0.35, 0.95)
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
    control:SetHandler("OnMoveStop", SavePosition)
    control:SetHandler("OnMouseEnter", ShowTooltip)
    control:SetHandler("OnMouseExit", HideTooltip)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    ApplyStyle()

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, 8)
    titleLabel:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, 8)
    titleLabel:SetHeight(24)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetText(GetString(EZOM_DD_STATS_TITLE))

    for index, def in ipairs(STAT_DEFS) do
        local top = 34 + ((index - 1) * ROW_HEIGHT)
        local row = {}

        row.name = wm:CreateControl(CONTROL_NAME .. def.key .. "Name", control, CT_LABEL)
        row.name:SetAnchor(TOPLEFT, control, TOPLEFT, PADDING, top)
        row.name:SetDimensions(NAME_WIDTH, ROW_HEIGHT)
        row.name:SetFont("ZoFontGameSmall")
        row.name:SetColor(0.82, 0.82, 0.82, 1)
        row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.name:SetMaxLineCount(1)

        row.value = wm:CreateControl(CONTROL_NAME .. def.key .. "Value", control, CT_LABEL)
        row.value:SetAnchor(TOPLEFT, row.name, TOPRIGHT, 6, 0)
        row.value:SetDimensions(VALUE_WIDTH, ROW_HEIGHT)
        row.value:SetFont("ZoFontGameSmall")
        row.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.value:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.value:SetMaxLineCount(1)

        row.effective = wm:CreateControl(CONTROL_NAME .. def.key .. "Effective", control, CT_LABEL)
        row.effective:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, top)
        row.effective:SetDimensions(EFFECTIVE_WIDTH, ROW_HEIGHT)
        row.effective:SetFont("ZoFontGameSmall")
        row.effective:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.effective:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.effective:SetMaxLineCount(1)
        row.effective:SetColor(EFFECTIVE_COLOR.r, EFFECTIVE_COLOR.g, EFFECTIVE_COLOR.b, EFFECTIVE_COLOR.a)

        rows[def.key] = row
    end

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

local function HasSummary()
    return lastCombatSummary and lastCombatSummary.hasData == true
end

local function UpdateVisibility()
    EnsureControl()

    local settings = GetSettings() or {}
    local hidden = false
    if not CanShowHud() then
        hidden = true
    elseif forceShow then
        hidden = false
    elseif IsHudUnlocked() then
        hidden = false
    elseif not IsEnabled() then
        hidden = true
    elseif settings.onlyCombat == true and not isCombat and not HasSummary() then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function UpdateVisuals()
    EnsureControl()
    titleLabel:SetText(GetString(EZOM_DD_STATS_TITLE))

    for _, def in ipairs(STAT_DEFS) do
        local row = rows[def.key]
        local data = currentValues[def.key] or {}
        local band = data.band or BAND_UNKNOWN
        local r, g, b, a = GetBandColor(band, def.positiveHigh)

        row.name:SetText(GetLocalizedString(def.nameString, def.key))
        row.value:SetText(FormatOwnValue(def, data))
        row.value:SetColor(r, g, b, a)
        row.effective:SetText(FormatEffectiveValue(def, data))
        if (GetOvercapValue(def, data) or 0) > 0 then
            row.effective:SetColor(
                EFFECTIVE_OVERCAP_COLOR.r,
                EFFECTIVE_OVERCAP_COLOR.g,
                EFFECTIVE_OVERCAP_COLOR.b,
                EFFECTIVE_OVERCAP_COLOR.a
            )
        else
            row.effective:SetColor(EFFECTIVE_COLOR.r, EFFECTIVE_COLOR.g, EFFECTIVE_COLOR.b, EFFECTIVE_COLOR.a)
        end
    end
end

local function OnUpdate()
    RefreshCurrentValues()
    UpdateVisuals()

    if isCombat and statsTracker then
        statsTracker:Sample(GetNowMs())
    end
    if isCombat and effectiveStatsTracker then
        effectiveStatsTracker:Sample(GetNowMs())
    end
    if isCombat and overcapStatsTracker then
        overcapStatsTracker:Sample(GetNowMs())
    end

    UpdateVisibility()
end

local function CreateDamageWeightedTracker()
    local tracker = {
        started = false,
        startMs = 0,
        durationMs = 0,
        totalDamage = 0,
        order = {},
        byKey = {},
        lastSummary = nil,
    }

    local function EnsureStat(self, def)
        local stat = self.byKey[def.key]
        if not stat then
            stat = {
                key = def.key,
                item = def,
                damageWeight = 0,
                ownWeighted = 0,
                effectiveWeighted = 0,
                overcapWeighted = 0,
                minOwn = nil,
                maxOwn = 0,
                minEffective = nil,
                maxEffective = 0,
                maxOvercap = 0,
                bandDamage = {},
            }
            self.byKey[def.key] = stat
            table.insert(self.order, def.key)
        else
            stat.item = def
        end
        return stat
    end

    local function BuildSummary(self, nowMs)
        local rows = {}
        local byKey = {}
        local durationMs = self.durationMs
        if self.started then
            durationMs = math.max(0, (nowMs or GetNowMs()) - self.startMs)
        end

        for _, key in ipairs(self.order) do
            local stat = self.byKey[key]
            if stat and stat.damageWeight > 0 then
                local row = {
                    key = key,
                    name = GetLocalizedString(stat.item.nameString, key),
                    damageWeight = stat.damageWeight,
                    averageOwn = stat.ownWeighted / stat.damageWeight,
                    averageEffective = stat.effectiveWeighted / stat.damageWeight,
                    averageOvercap = stat.overcapWeighted / stat.damageWeight,
                    minOwn = stat.minOwn or 0,
                    maxOwn = stat.maxOwn,
                    minEffective = stat.minEffective or 0,
                    maxEffective = stat.maxEffective,
                    maxOvercap = stat.maxOvercap,
                    bandDamage = stat.bandDamage,
                }
                table.insert(rows, row)
                byKey[key] = row
            end
        end

        return {
            durationMs = durationMs,
            totalDamage = self.totalDamage,
            rows = rows,
            byKey = byKey,
            hasData = #rows > 0,
        }
    end

    function tracker:Start(nowMs)
        self.started = true
        self.startMs = nowMs or GetNowMs()
        self.durationMs = 0
        self.totalDamage = 0
        self.order = {}
        self.byKey = {}
        self.lastSummary = nil
    end

    function tracker:AddDamage(hitValue)
        if not self.started then return end

        local damage = tonumber(hitValue) or 0
        if damage <= 0 then return end

        if not currentValues or not next(currentValues) then
            RefreshCurrentValues()
        end

        self.totalDamage = self.totalDamage + damage
        for _, def in ipairs(STAT_DEFS) do
            local data = currentValues[def.key]
            if data and data.available == true then
                local ownValue = tonumber(data.ownValue or data.value) or 0
                local effectiveValue = tonumber(data.effectiveValue or data.value) or ownValue
                local overcapValue = GetOvercapValue(def, data) or 0
                local band = data.band or GetBand(def, ownValue)
                local stat = EnsureStat(self, def)

                stat.damageWeight = stat.damageWeight + damage
                stat.ownWeighted = stat.ownWeighted + (ownValue * damage)
                stat.effectiveWeighted = stat.effectiveWeighted + (effectiveValue * damage)
                stat.overcapWeighted = stat.overcapWeighted + (overcapValue * damage)
                stat.minOwn = stat.minOwn and math.min(stat.minOwn, ownValue) or ownValue
                stat.maxOwn = math.max(stat.maxOwn, ownValue)
                stat.minEffective = stat.minEffective and math.min(stat.minEffective, effectiveValue) or effectiveValue
                stat.maxEffective = math.max(stat.maxEffective, effectiveValue)
                stat.maxOvercap = math.max(stat.maxOvercap, overcapValue)
                stat.bandDamage[band] = (stat.bandDamage[band] or 0) + damage
            end
        end
    end

    function tracker:Finish(nowMs)
        if not self.started then return self.lastSummary end

        self.durationMs = math.max(0, (nowMs or GetNowMs()) - self.startMs)
        self.lastSummary = BuildSummary(self, nowMs)
        self.started = false
        return self.lastSummary
    end

    function tracker:GetCurrentSummary()
        if self.started then
            return BuildSummary(self, GetNowMs())
        end
        return self.lastSummary
    end

    return tracker
end

local function OnLibCombatDamageOut(_, _timems, _result, _sourceUnitId, _targetUnitId, _abilityId, hitValue)
    if not isCombat or not damageWeightedTracker then return end
    damageWeightedTracker:AddDamage(hitValue)
end

local function RegisterLibCombat()
    if libCombatRegistered or not HasLibCombatDamage() then return end
    LibCombat:RegisterCallbackType(LIBCOMBAT_EVENT_DAMAGE_OUT, OnLibCombatDamageOut, CALLBACK_NAME)
    libCombatRegistered = true
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_DDStatsUpdate", UPDATE_INTERVAL_MS, OnUpdate)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_DDStatsUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    local settings = GetSettings() or {}
    if IsHudUnlocked() or forceShow or (IsEnabled() and (settings.onlyCombat ~= true or isCombat or HasSummary())) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    RefreshCurrentValues()

    if isCombat then
        lastCombatSummary = nil
        lastEffectiveCombatSummary = nil
        lastOvercapCombatSummary = nil
        lastDamageWeightedSummary = nil
        if statsTracker then
            statsTracker:Start(GetNowMs())
        end
        if effectiveStatsTracker then
            effectiveStatsTracker:Start(GetNowMs())
        end
        if overcapStatsTracker then
            overcapStatsTracker:Start(GetNowMs())
        end
        if damageWeightedTracker then
            damageWeightedTracker:Start(GetNowMs())
        end
    else
        if statsTracker then
            statsTracker:Sample(GetNowMs())
            lastCombatSummary = statsTracker:Finish(GetNowMs())
        end
        if effectiveStatsTracker then
            effectiveStatsTracker:Sample(GetNowMs())
            lastEffectiveCombatSummary = effectiveStatsTracker:Finish(GetNowMs())
        end
        if overcapStatsTracker then
            overcapStatsTracker:Sample(GetNowMs())
            lastOvercapCombatSummary = overcapStatsTracker:Finish(GetNowMs())
        end
        if damageWeightedTracker then
            lastDamageWeightedSummary = damageWeightedTracker:Finish(GetNowMs())
        end
    end

    UpdateVisuals()
    RefreshUpdateRegistration()
end

function Tracker.ShowTest()
    if not CanShowHud() then return end

    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    currentValues = {
        damage = { value = 6200, ownValue = 6200, effectiveValue = 6200, available = true, band = BAND_OK },
        crit = { value = 55.4, ownValue = 55.4, effectiveValue = 55.4, available = true, band = BAND_OK },
        penetration = { value = 18200, ownValue = 7200, effectiveValue = 18200, available = true, band = BAND_OK },
        critDamage = { value = 125, ownValue = 125, effectiveValue = 125, available = true, band = BAND_OK },
    }
    UpdateVisuals()
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        Tracker.ApplySettings()
    end, 5000)
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    ApplyStyle()
    RegisterLibCombat()
    OnUpdate()
    RefreshUpdateRegistration()
end

function Tracker.Init()
    EnsureControl()
    if EZOMetter_CombatSummary then
        statsTracker = EZOMetter_CombatSummary.CreateValueTracker({
            getItems = function()
                return STAT_DEFS
            end,
            getItemKey = function(item)
                return item.key
            end,
            getItemName = function(item)
                return GetLocalizedString(item.nameString, item.key)
            end,
            isItemRequired = function(item)
                local data = currentValues[item.key]
                return data and data.available == true
            end,
            getItemValue = function(item)
                local data = currentValues[item.key]
                return data and (data.ownValue or data.value) or 0
            end,
            getItemBand = function(item)
                local data = currentValues[item.key]
                return data and GetBand(item, data.ownValue or data.value) or BAND_UNKNOWN
            end,
        })
        effectiveStatsTracker = EZOMetter_CombatSummary.CreateValueTracker({
            getItems = function()
                return STAT_DEFS
            end,
            getItemKey = function(item)
                return item.key
            end,
            getItemName = function(item)
                return GetLocalizedString(item.nameString, item.key)
            end,
            isItemRequired = function(item)
                local data = currentValues[item.key]
                return data and data.available == true
            end,
            getItemValue = function(item)
                local data = currentValues[item.key]
                return data and (data.effectiveValue or data.value) or 0
            end,
            getItemBand = function(item)
                local data = currentValues[item.key]
                return data and data.band or BAND_UNKNOWN
            end,
        })
        overcapStatsTracker = EZOMetter_CombatSummary.CreateValueTracker({
            getItems = function()
                return STAT_DEFS
            end,
            getItemKey = function(item)
                return item.key
            end,
            getItemName = function(item)
                return GetLocalizedString(item.nameString, item.key)
            end,
            isItemRequired = function(item)
                local data = currentValues[item.key]
                return data and data.available == true and ShouldShowEffective(item) == true
            end,
            getItemValue = function(item)
                local data = currentValues[item.key]
                return GetOvercapValue(item, data) or 0
            end,
            getItemBand = function(item)
                local value = GetOvercapValue(item, currentValues[item.key]) or 0
                return value > 0 and BAND_HIGH or BAND_OK
            end,
        })
        damageWeightedTracker = CreateDamageWeightedTracker()
    end
    RegisterLibCombat()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_DDStatsCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

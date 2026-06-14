-- Tracker separado para stats ofensivos utiles de DD.
EZOMetter_DDStats = EZOMetter_DDStats or {}

local Tracker = EZOMetter_DDStats
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterDDStatsTracker"
local UPDATE_INTERVAL_MS = 250
local WIDTH = 320
local HEIGHT = 126
local PADDING = 12
local ROW_HEIGHT = 22
local NAME_WIDTH = 92
local VALUE_WIDTH = 86
local STATE_WIDTH = 70

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
local lastCombatSummary

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

local function GetBandName(band)
    if band == BAND_LOW then return GetString(EZOM_DD_STATS_STATE_LOW) end
    if band == BAND_HIGH then return GetString(EZOM_DD_STATS_STATE_HIGH) end
    if band == BAND_OK then return GetString(EZOM_DD_STATS_STATE_OK) end
    return GetString(EZOM_DD_STATS_STATE_UNKNOWN)
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

local function RefreshCurrentValues()
    for _, def in ipairs(STAT_DEFS) do
        local value = ReadStatValue(def.key)
        currentValues[def.key] = {
            value = value,
            available = value ~= nil,
            band = GetBand(def, value),
        }
    end
end

local function GetTooltipSummary()
    if isCombat and statsTracker and statsTracker.GetCurrentSummary then
        return statsTracker:GetCurrentSummary(), GetString(EZOM_DD_STATS_SUMMARY_CURRENT)
    end
    return lastCombatSummary, GetString(EZOM_DD_STATS_SUMMARY_LAST)
end

local function BuildTooltipText()
    local summary, title = GetTooltipSummary()
    if not summary or not summary.hasData then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local lines = {
        title,
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(summary.durationMs) .. "s",
    }

    for _, def in ipairs(STAT_DEFS) do
        local row = summary.byKey and summary.byKey[def.key] or nil
        if row then
            table.insert(lines, string.format(
                "%s: %s / %s / %s | %s %s %s %s %s %s",
                GetLocalizedString(def.nameString, def.key),
                FormatValue(def, row.minValue),
                FormatValue(def, row.averageValue),
                FormatValue(def, row.maxValue),
                GetString(EZOM_DD_STATS_SUMMARY_LOW),
                FormatPercent(GetBandPercent(row, BAND_LOW)),
                GetString(EZOM_DD_STATS_SUMMARY_OK),
                FormatPercent(GetBandPercent(row, BAND_OK)),
                GetString(EZOM_DD_STATS_SUMMARY_HIGH),
                FormatPercent(GetBandPercent(row, BAND_HIGH))
            ))
        else
            table.insert(lines, GetLocalizedString(def.nameString, def.key) .. ": " .. GetString(EZOM_DD_STATS_UNAVAILABLE))
        end
    end

    return table.concat(lines, "\n")
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

        row.state = wm:CreateControl(CONTROL_NAME .. def.key .. "State", control, CT_LABEL)
        row.state:SetAnchor(TOPRIGHT, control, TOPRIGHT, -PADDING, top)
        row.state:SetDimensions(STATE_WIDTH, ROW_HEIGHT)
        row.state:SetFont("ZoFontGameSmall")
        row.state:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        row.state:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        row.state:SetMaxLineCount(1)

        rows[def.key] = row
    end

    ApplyPosition()
    SetMoveMode(GetSettings() and GetSettings().unlock == true)
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
    elseif settings.unlock == true then
        hidden = not IsEnabled()
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
        row.value:SetText(FormatValue(def, data.value))
        row.value:SetColor(r, g, b, a)
        row.state:SetText(GetBandName(band))
        row.state:SetColor(r, g, b, a)
    end
end

local function OnUpdate()
    RefreshCurrentValues()
    UpdateVisuals()

    if isCombat and statsTracker then
        statsTracker:Sample(GetNowMs())
    end

    UpdateVisibility()
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
    if forceShow or (IsEnabled() and (settings.onlyCombat ~= true or isCombat or HasSummary())) then
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
        if statsTracker then
            statsTracker:Start(GetNowMs())
        end
    else
        if statsTracker then
            statsTracker:Sample(GetNowMs())
            lastCombatSummary = statsTracker:Finish(GetNowMs())
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
        damage = { value = 6200, available = true, band = BAND_OK },
        crit = { value = 55.4, available = true, band = BAND_OK },
        penetration = { value = 7200, available = true, band = BAND_OK },
        critDamage = { value = 125, available = true, band = BAND_OK },
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
    SetMoveMode(GetSettings() and GetSettings().unlock == true)
    ApplyStyle()
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
                return data and data.value or 0
            end,
            getItemBand = function(item)
                local data = currentValues[item.key]
                return data and data.band or BAND_UNKNOWN
            end,
        })
    end

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_DDStatsCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

-- Tracker separado para Coral Riptide.
EZOMetter_Coral = EZOMetter_Coral or {}

local Tracker = EZOMetter_Coral
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterCoralTracker"
local UPDATE_INTERVAL_MS = 250
local EQUIPMENT_SCAN_INTERVAL_MS = 1000
local MAX_BONUS = 600
local CAP_STAMINA_PCT = 50
local OK_STAMINA_PCT = 55
local MID_STAMINA_PCT = 65
local LOW_STAMINA_PCT = 80
local WIDTH = 196
local HEIGHT = 56
local PADDING = 12
local CONTENT_HEIGHT = 30
local TITLE_WIDTH = 96
local BONUS_WIDTH = 60
local BONUS_GAP = 4

local BAND_CAP = "cap"
local BAND_OK = "ok"
local BAND_MID = "mid"
local BAND_LOW = "low"
local BAND_BAD = "bad"
local BAND_INACTIVE = "inactive"

local CORAL_ALIASES = {
    "Coral Riptide",
    "Perfected Coral Riptide",
    "Marea de coral",
    "Marea de coral perfeccionado",
    "Marea de coral perfeccionada",
    "Marea coralina",
    "Marea coralina perfeccionada",
    "Marea coralina perfeccionado",
    "Perfeccionado Riptide de Coral",
    "Riptide de Coral",
}

local control
local backdrop
local stateLabel
local bonusLabel
local updateRegistered = false
local statsUpdateRegistered = false
local forceShow = false
local isCombat = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local currentBonus = 0
local currentBand = BAND_INACTIVE
local currentStaminaPct = 100
local statsTracker
local lastCombatSummary
local IsHudUnlocked

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.coral = EZOMetter.sv.coral or {}
    return EZOMetter.sv.coral
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

local function IsDebugEnabled()
    local settings = GetSettings()
    return settings and settings.debugEquipment == true and EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.debugMode == true
end

local function IsCoralSet(setName, setId)
    return EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.NameMatches(setName, CORAL_ALIASES)
end

local function ScanEquipment()
    if EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.GetWornSetSnapshot then
        currentSnapshot = EZOMetter_EquipmentSets.GetWornSetSnapshot(IsCoralSet)
    else
        currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
    end
    lastEquipmentScanMs = GetNowMs()
end

local function IsCoralActive()
    return currentSnapshot and currentSnapshot.hasSet == true and (tonumber(currentSnapshot.numEquipped) or 0) >= 5
end

local function GetStaminaPct()
    if type(GetUnitPower) ~= "function" or POWERTYPE_STAMINA == nil then
        return 100
    end

    local current, maximum = GetUnitPower("player", POWERTYPE_STAMINA)
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if maximum <= 0 then return 100 end
    return math.max(0, math.min(100, (current / maximum) * 100))
end

local function CalculateBonus(staminaPct)
    local missingPct = math.max(0, 100 - (tonumber(staminaPct) or 100))
    return math.floor((MAX_BONUS * math.min(missingPct / CAP_STAMINA_PCT, 1)) + 0.5)
end

local function GetBand(staminaPct, active)
    if not active then return BAND_INACTIVE end
    if staminaPct <= CAP_STAMINA_PCT then return BAND_CAP end
    if staminaPct <= OK_STAMINA_PCT then return BAND_OK end
    if staminaPct <= MID_STAMINA_PCT then return BAND_MID end
    if staminaPct <= LOW_STAMINA_PCT then return BAND_LOW end
    return BAND_BAD
end

local function GetBandName(band)
    if band == BAND_CAP then return GetString(EZOM_CORAL_STATE_CAP) end
    if band == BAND_OK then return GetString(EZOM_CORAL_STATE_OK) end
    if band == BAND_MID then return GetString(EZOM_CORAL_STATE_MID) end
    if band == BAND_LOW then return GetString(EZOM_CORAL_STATE_LOW) end
    if band == BAND_BAD then return GetString(EZOM_CORAL_STATE_BAD) end
    return GetString(EZOM_CORAL_STATE_INACTIVE)
end

local function GetBandColor(band)
    if band == BAND_CAP then return 0.15, 1, 0.35, 1 end
    if band == BAND_OK then return 0.55, 1, 0.35, 1 end
    if band == BAND_MID then return 1, 0.86, 0.25, 1 end
    if band == BAND_LOW then return 1, 0.52, 0.18, 1 end
    if band == BAND_BAD then return 1, 0.2, 0.18, 1 end
    return 0.72, 0.72, 0.72, 1
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

local function BuildTooltipText()
    if not lastCombatSummary or not lastCombatSummary.hasData then
        return GetString(EZOM_LAST_COMBAT_NO_DATA)
    end

    local row = lastCombatSummary.byKey and lastCombatSummary.byKey.coral
    if not row then return GetString(EZOM_LAST_COMBAT_NO_DATA) end

    local okPct = GetBandPercent(row, BAND_CAP) + GetBandPercent(row, BAND_OK)
    local badPct = GetBandPercent(row, BAND_BAD)
    local inactivePct = GetBandPercent(row, BAND_INACTIVE)

    local lines = {
        GetString(EZOM_CORAL_SUMMARY_TITLE),
        GetString(EZOM_SUMMARY_DURATION) .. ": " .. FormatSeconds(lastCombatSummary.durationMs) .. "s",
        GetString(EZOM_CORAL_SUMMARY_AVG_BONUS) .. ": +" .. string.format("%.0f", row.averageValue),
        GetString(EZOM_CORAL_SUMMARY_OK_TIME) .. ": " .. FormatPercent(okPct),
        GetString(EZOM_CORAL_SUMMARY_BAD_TIME) .. ": " .. FormatPercent(badPct),
    }

    if inactivePct > 0 then
        table.insert(lines, GetString(EZOM_CORAL_SUMMARY_INACTIVE_TIME) .. ": " .. FormatPercent(inactivePct))
    end

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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 40)
end

local function SetMoveMode(enabled)
    if not control then return end
    control:SetMouseEnabled(true)
    control:SetMovable(enabled == true)
end

local function ApplyStyle()
    if not backdrop then return end

    local settings = GetSettings() or {}
    local size = tonumber(settings.size) or 100
    if size < 70 then size = 70 end
    if size > 140 then size = 140 end
    if control and control.SetScale then
        control:SetScale(size / 100)
    end

    local opacity = tonumber(settings.backgroundOpacity) or 86
    if opacity < 0 then opacity = 0 end
    if opacity > 100 then opacity = 100 end

    backdrop:SetCenterColor(0.03, 0.03, 0.03, opacity / 100)
    if settings.showBorder == false then
        backdrop:SetEdgeColor(0, 0, 0, 0)
    else
        backdrop:SetEdgeColor(0.1, 0.75, 0.85, 0.95)
    end
end

local function GetLabelWidth(label, fallback)
    if not label then return fallback end
    if label.GetTextWidth then
        return tonumber(label:GetTextWidth()) or fallback
    end
    if label.GetTextDimensions then
        local width = label:GetTextDimensions()
        return tonumber(width) or fallback
    end
    return fallback
end

local function LayoutContent()
    if not control or not stateLabel or not bonusLabel then return end

    local maxContentWidth = WIDTH - (PADDING * 2)
    local measuredTitleWidth = math.ceil(GetLabelWidth(stateLabel, TITLE_WIDTH)) + 2
    local measuredBonusWidth = math.ceil(GetLabelWidth(bonusLabel, BONUS_WIDTH)) + 2
    local bonusWidth = math.max(40, math.min(BONUS_WIDTH, measuredBonusWidth))
    local titleWidth = math.max(1, math.min(maxContentWidth - BONUS_GAP - bonusWidth, measuredTitleWidth))
    local groupWidth = titleWidth + BONUS_GAP + bonusWidth
    local left = math.max(PADDING, (WIDTH - groupWidth) / 2)

    stateLabel:ClearAnchors()
    stateLabel:SetAnchor(LEFT, control, LEFT, left, 0)
    stateLabel:SetDimensions(titleWidth, CONTENT_HEIGHT)

    bonusLabel:ClearAnchors()
    bonusLabel:SetAnchor(LEFT, stateLabel, RIGHT, BONUS_GAP, 0)
    bonusLabel:SetDimensions(bonusWidth, CONTENT_HEIGHT)
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

    stateLabel = wm:CreateControl(CONTROL_NAME .. "State", control, CT_LABEL)
    stateLabel:SetAnchor(LEFT, control, LEFT, PADDING, 0)
    stateLabel:SetDimensions(TITLE_WIDTH, CONTENT_HEIGHT)
    stateLabel:SetFont("ZoFontGameMedium")
    stateLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    stateLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stateLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    stateLabel:SetMaxLineCount(1)

    bonusLabel = wm:CreateControl(CONTROL_NAME .. "Bonus", control, CT_LABEL)
    bonusLabel:SetAnchor(LEFT, stateLabel, RIGHT, BONUS_GAP, 0)
    bonusLabel:SetDimensions(BONUS_WIDTH, CONTENT_HEIGHT)
    bonusLabel:SetFont("ZoFontGameLargeBold")
    bonusLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    bonusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

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
    elseif settings.onlyCombat ~= false and not isCombat and not HasSummary() then
        hidden = true
    elseif not (currentSnapshot and currentSnapshot.hasSet) and not HasSummary() then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function UpdateVisuals()
    EnsureControl()

    local r, g, b, a = GetBandColor(currentBand)
    stateLabel:SetText("Coral Riptide")
    stateLabel:SetColor(r, g, b, a)
    bonusLabel:SetColor(r, g, b, a)

    if currentBand == BAND_INACTIVE then
        bonusLabel:SetText("+0")
    else
        bonusLabel:SetText("+" .. tostring(currentBonus))
    end

    LayoutContent()
end

local function RefreshState()
    local nowMs = GetNowMs()
    if nowMs - lastEquipmentScanMs >= EQUIPMENT_SCAN_INTERVAL_MS then
        ScanEquipment()
    end

    currentStaminaPct = GetStaminaPct()
    local active = IsCoralActive()
    currentBonus = active and CalculateBonus(currentStaminaPct) or 0
    currentBand = GetBand(currentStaminaPct, active)
    UpdateVisuals()
    UpdateVisibility()
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_CoralUpdate", UPDATE_INTERVAL_MS, RefreshState)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_CoralUpdate")
    updateRegistered = false
end

local function RegisterStatsUpdate()
    if statsUpdateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_CoralStats", UPDATE_INTERVAL_MS, function()
        if statsTracker then
            statsTracker:Sample(GetNowMs())
        end
    end)
    statsUpdateRegistered = true
end

local function UnregisterStatsUpdate()
    if not statsUpdateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_CoralStats")
    statsUpdateRegistered = false
end

local function RefreshUpdateRegistration()
    local settings = GetSettings() or {}
    if IsHudUnlocked() or forceShow or (IsEnabled() and (settings.onlyCombat == false or isCombat or HasSummary())) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    ScanEquipment()
    RefreshState()

    if isCombat then
        lastCombatSummary = nil
        if statsTracker then
            statsTracker:Start(GetNowMs())
            RegisterStatsUpdate()
        end
    else
        if statsTracker then
            lastCombatSummary = statsTracker:Finish(GetNowMs())
        end
        UnregisterStatsUpdate()
    end

    RefreshUpdateRegistration()
end

function Tracker.DebugScanEquipment()
    ScanEquipment()
    if not IsDebugEnabled() then
        if EZOMetter.Print then
            EZOMetter.Print(GetString(EZOM_CORAL_DEBUG_DISABLED))
        end
        return
    end

    if EZOMetter.DebugLog then
        EZOMetter.DebugLog("[Coral] equipment scan start")
        for _, row in ipairs(currentSnapshot.debugRows or {}) do
            EZOMetter.DebugLog(string.format(
                "[Coral] slot=%s set=%s setId=%s equipped=%s/%s",
                tostring(row.slot),
                tostring(row.setName),
                tostring(row.setId),
                tostring(row.numEquipped),
                tostring(row.maxEquipped)
            ))
        end
        EZOMetter.DebugLog(string.format(
            "[Coral] match hasSet=%s name=%s setId=%s equipped=%s/%s",
            tostring(currentSnapshot.hasSet),
            tostring(currentSnapshot.setName),
            tostring(currentSnapshot.setId),
            tostring(currentSnapshot.numEquipped),
            tostring(currentSnapshot.maxEquipped)
        ))
    end

    if EZOMetter.Print then
        EZOMetter.Print(GetString(EZOM_CORAL_DEBUG_SCAN_DONE))
    end
end

function Tracker.ShowTest()
    if not CanShowHud() then return end

    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    currentSnapshot = { hasSet = true, numEquipped = 5, maxEquipped = 5 }
    currentStaminaPct = 55
    currentBonus = CalculateBonus(currentStaminaPct)
    currentBand = BAND_OK
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
    ScanEquipment()
    RefreshState()
    RefreshUpdateRegistration()
end

function Tracker.Init()
    EnsureControl()
    if EZOMetter_CombatSummary then
        statsTracker = EZOMetter_CombatSummary.CreateValueTracker({
            getItems = function()
                return { { key = "coral", name = "Coral Riptide" } }
            end,
            getItemKey = function(item)
                return item.key
            end,
            getItemName = function(item)
                return item.name
            end,
            isItemRequired = function()
                return currentSnapshot and currentSnapshot.hasSet == true
            end,
            getItemValue = function()
                return currentBonus
            end,
            getItemBand = function()
                return currentBand
            end,
        })
    end

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CoralCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CoralInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            Tracker.ApplySettings()
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CoralWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            Tracker.ApplySettings()
        end)
    end

    ScanEquipment()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

-- Tracker separado para Highland Sentinel.
EZOMetter_Highland = EZOMetter_Highland or {}

local Tracker = EZOMetter_Highland
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterHighlandTracker"
local UPDATE_INTERVAL_MS = 250
local EQUIPMENT_SCAN_INTERVAL_MS = 1000

local HIGHLAND_ALIASES = {
    "Highland Sentinel",
    "Centinela de las Tierras Altas",
}

-- Buff tracking
local HIGHLAND_BUFF_NAMES = {
    "Sentinel's Eye",
    "Ojo del centinela"
}
local MAX_STACKS = 3
local CRIT_PER_STACK = 443

local WIDTH = 240
local HEIGHT = 46
local PADDING = 10
local ROW_HEIGHT = 20

local control
local backdrop
local titleLabel
local stacksLabel
local bonusLabel

local updateRegistered = false
local forceShow = false
local isCombat = false
local lastEquipmentScanMs = 0
local currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
local currentStacks = 0
local currentBonus = 0

local IsHudUnlocked

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.highland = EZOMetter.sv.highland or {}
    return EZOMetter.sv.highland
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

local function IsHighlandSet(setName, _setId)
    return EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.NameMatches(setName, HIGHLAND_ALIASES)
end

local function ScanEquipment()
    if EZOMetter_EquipmentSets and EZOMetter_EquipmentSets.GetWornSetSnapshot then
        currentSnapshot = EZOMetter_EquipmentSets.GetWornSetSnapshot(IsHighlandSet)
    else
        currentSnapshot = { hasSet = false, numEquipped = 0, maxEquipped = 0 }
    end
    lastEquipmentScanMs = GetNowMs()
end

local function IsHighlandActive()
    return currentSnapshot and currentSnapshot.hasSet == true and (tonumber(currentSnapshot.numEquipped) or 0) >= 5
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 80)
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
    local size = tonumber(settings.size) or 100
    if size < 70 then size = 70 end
    if size > 140 then size = 140 end

    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control, size)
        if EZOMetter_WindowStyle.ApplyBackdropStyle then
            EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
            return
        end
    elseif control and control.SetScale then
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

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("", 1, 1, 1)
    ApplyStyle()

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(LEFT, control, LEFT, PADDING, 0)
    titleLabel:SetDimensions(80, ROW_HEIGHT)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    titleLabel:SetText("Highland")

    stacksLabel = wm:CreateControl(CONTROL_NAME .. "Stacks", control, CT_LABEL)
    stacksLabel:SetAnchor(LEFT, titleLabel, RIGHT, 5, 0)
    stacksLabel:SetDimensions(75, ROW_HEIGHT)
    stacksLabel:SetFont("ZoFontGame")
    stacksLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stacksLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    bonusLabel = wm:CreateControl(CONTROL_NAME .. "Bonus", control, CT_LABEL)
    bonusLabel:SetAnchor(RIGHT, control, RIGHT, -PADDING, 0)
    bonusLabel:SetDimensions(50, ROW_HEIGHT)
    bonusLabel:SetFont("ZoFontGameLargeBold")
    bonusLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    bonusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    ApplyPosition()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
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
    elseif settings.onlyCombat ~= false and not isCombat then
        hidden = true
    elseif not IsHighlandActive() then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function GetStatusColor(stacks)
    if stacks >= 3 then return 0.15, 1, 0.35, 1 end
    if stacks >= 2 then return 1, 0.86, 0.25, 1 end
    if stacks >= 1 then return 1, 0.55, 0.15, 1 end
    return 0.72, 0.72, 0.72, 1
end

local function UpdateVisuals()
    EnsureControl()

    local r, g, b, a = GetStatusColor(currentStacks)
    titleLabel:SetColor(r, g, b, a)
    stacksLabel:SetColor(r, g, b, a)
    bonusLabel:SetColor(r, g, b, a)

    stacksLabel:SetText(GetString(EZOM_HIGHLAND_STACKS) .. ": " .. tostring(currentStacks) .. "/" .. tostring(MAX_STACKS))

    if currentStacks > 0 then
        bonusLabel:SetText("+" .. tostring(currentBonus))
    else
        bonusLabel:SetText("+0")
    end
end

local function RefreshState()
    local nowMs = GetNowMs()
    if nowMs - lastEquipmentScanMs >= EQUIPMENT_SCAN_INTERVAL_MS then
        ScanEquipment()
    end

    -- Si no está equipado o no está en combate, resetear los stacks a 0 para asegurar.
    if not IsHighlandActive() or not isCombat then
        currentStacks = 0
        currentBonus = 0
    end

    UpdateVisuals()
    UpdateVisibility()
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_HighlandUpdate", UPDATE_INTERVAL_MS, RefreshState)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_HighlandUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    local settings = GetSettings() or {}
    if IsHudUnlocked() or forceShow or (IsEnabled() and (settings.onlyCombat == false or isCombat)) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    ScanEquipment()
    if not isCombat then
        currentStacks = 0
        currentBonus = 0
    end
    RefreshState()
    RefreshUpdateRegistration()
end

local function OnEffectChanged(_, changeType, _effectSlot, effectName, unitTag, _beginTime, _endTime, stackCount, _iconName, _buffType, _effectType, _abilityType, _statusEffectType, _unitName, _unitId, abilityId, _sourceType)
    if unitTag ~= "player" then return end

    local matched = false
    local lowerName = string.lower(effectName or "")
    for _, name in ipairs(HIGHLAND_BUFF_NAMES) do
        if string.lower(name) == lowerName then
            matched = true
            break
        end
    end

    if matched then
        if changeType == EFFECT_RESULT_FADED then
            currentStacks = 0
        else
            currentStacks = math.min(MAX_STACKS, tonumber(stackCount) or 1)
        end
        currentBonus = currentStacks * CRIT_PER_STACK
        UpdateVisuals()

        -- Log the Ability ID to help the developer track it down easily.
        local settings = GetSettings()
        if settings and settings.debugEvents == true and EZOMetter.DebugLog then
            EZOMetter.DebugLog("[Highland] Found Sentinel's Eye! AbilityID: " .. tostring(abilityId) .. " Stacks: " .. tostring(currentStacks))
        end
    end
end

function Tracker.ShowTest()
    if not CanShowHud() then return end

    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    currentSnapshot = { hasSet = true, numEquipped = 5, maxEquipped = 5 }
    currentStacks = 3
    currentBonus = currentStacks * CRIT_PER_STACK
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

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HighlandCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HighlandEffects", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_HighlandEffects", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HighlandInventory", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            Tracker.ApplySettings()
        end)
    end
    if EVENT_ACTIVE_WEAPON_PAIR_CHANGED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_HighlandWeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
            Tracker.ApplySettings()
        end)
    end

    ScanEquipment()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

-- Direct tracker for Azureblight Reaper's Blight Seed debuff.
EZOMetter_Azureblight = EZOMetter_Azureblight or {}

local Tracker = EZOMetter_Azureblight
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterAzureblightTracker"
local BLIGHT_SEED_ID = 126631
local UPDATE_INTERVAL_MS = 250
local WIDTH = 220
local HEIGHT = 64
local PADDING = 8
local ICON_SIZE = 46
local BAR_HEIGHT = 9
local PREVIEW_STACKS = 12
local PREVIEW_DURATION_SECONDS = 5

local TRACKED_UNIT_TAGS = {
    "reticleover",
    "boss1",
    "boss2",
    "boss3",
    "boss4",
    "boss5",
    "boss6",
}

local control
local backdrop
local icon
local titleLabel
local stacksLabel
local timeLabel
local timerBar
local updateRegistered = false
local forceShow = false
local isCombat = false
local states = {}

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.azureblight = EZOMetter.sv.azureblight or {}
    return EZOMetter.sv.azureblight
end

local function GetNowSeconds()
    if type(GetFrameTimeSeconds) == "function" then
        return GetFrameTimeSeconds()
    end
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds() / 1000
    end
    if type(GetGameTimeSeconds) == "function" then
        return GetGameTimeSeconds()
    end
    return 0
end

local function CleanUnitName(name)
    name = tostring(name or "")
    if type(zo_strformat) == "function" then
        return zo_strformat("<<C:1>>", name)
    end
    return string.gsub(name, "%^.*", "")
end

local function IsTrackedUnitTag(unitTag)
    if unitTag == "reticleover" then return true end
    return type(unitTag) == "string" and string.match(unitTag, "^boss%d+$") ~= nil
end

local function CanShowHud()
    return EZOMetter_VisualContext
        and EZOMetter_VisualContext.CanShowHud
        and EZOMetter_VisualContext.CanShowHud()
end

local function IsHudUnlocked()
    return EZOMetter_VisualContext
        and EZOMetter_VisualContext.IsHudUnlocked
        and EZOMetter_VisualContext.IsHudUnlocked()
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.enabled == true
end

local function DebugEvent(source, unitTag, unitName, changeType, stacks, beginTime, endTime, abilityId)
    local settings = GetSettings()
    if not settings or settings.debugEvents ~= true or not EZOMetter.DebugLog then return end

    EZOMetter.DebugLog(string.format(
        "[Azureblight] %s tag=%s target=%s change=%s stacks=%s begin=%.3f end=%.3f abilityId=%s",
        tostring(source or ""),
        tostring(unitTag or ""),
        tostring(unitName or ""),
        tostring(changeType or ""),
        tostring(stacks or 0),
        tonumber(beginTime) or 0,
        tonumber(endTime) or 0,
        tostring(abilityId or 0)
    ))
end

local function ClearState(unitTag)
    states[unitTag] = nil
end

local function SetState(unitTag, unitName, beginTime, endTime, stackCount, source)
    if not IsTrackedUnitTag(unitTag) then return end

    beginTime = tonumber(beginTime) or 0
    endTime = tonumber(endTime) or 0
    stackCount = math.max(0, tonumber(stackCount) or 0)
    if endTime <= GetNowSeconds() then
        ClearState(unitTag)
        return
    end

    states[unitTag] = {
        unitTag = unitTag,
        unitName = CleanUnitName(unitName),
        beginTime = beginTime,
        endTime = endTime,
        stacks = stackCount,
        source = source or "direct",
    }
end

local function ScanUnit(unitTag)
    if type(DoesUnitExist) ~= "function"
        or not DoesUnitExist(unitTag)
        or type(GetNumBuffs) ~= "function"
        or type(GetUnitBuffInfo) ~= "function" then
        ClearState(unitTag)
        return false
    end

    for index = 1, GetNumBuffs(unitTag) do
        local _, beginTime, endTime, _, stackCount, _, _, _, _, _, abilityId =
            GetUnitBuffInfo(unitTag, index)
        if tonumber(abilityId) == BLIGHT_SEED_ID then
            local unitName = type(GetUnitName) == "function" and GetUnitName(unitTag) or ""
            local previous = states[unitTag]
            SetState(unitTag, unitName, beginTime, endTime, stackCount, "scan")
            if not previous
                or previous.stacks ~= (tonumber(stackCount) or 0)
                or previous.endTime ~= (tonumber(endTime) or 0) then
                DebugEvent("scan", unitTag, unitName, "observed", stackCount, beginTime, endTime, abilityId)
            end
            return true
        end
    end

    ClearState(unitTag)
    return false
end

local function ScanTrackedUnits()
    for _, unitTag in ipairs(TRACKED_UNIT_TAGS) do
        ScanUnit(unitTag)
    end
end

local function GetActiveState(nowSeconds)
    nowSeconds = nowSeconds or GetNowSeconds()

    for _, unitTag in ipairs(TRACKED_UNIT_TAGS) do
        local state = states[unitTag]
        if state then
            if state.endTime > nowSeconds then
                return state
            end
            ClearState(unitTag)
        end
    end

    return nil
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
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.x) or 0, tonumber(settings.y) or 120)
end

local function SetMoveMode(enabled)
    if not control then return end
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(true)
    if control.ezomPrimaryDragRefresh then
        control.ezomPrimaryDragRefresh()
    end
end

local function ApplyStyle()
    if not control or not backdrop then return end

    local settings = GetSettings() or {}
    local size = math.max(70, math.min(140, tonumber(settings.size) or 100))
    if EZOMetter_WindowStyle then
        EZOMetter_WindowStyle.ApplyControlScale(control, size)
        EZOMetter_WindowStyle.ApplyBackdropStyle(backdrop)
    else
        control:SetScale(size / 100)
        backdrop:SetCenterColor(0.03, 0.03, 0.03, 0.86)
        backdrop:SetEdgeColor(0.25, 0.75, 1, 0.95)
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

    icon = wm:CreateControl(CONTROL_NAME .. "Icon", control, CT_TEXTURE)
    icon:SetAnchor(LEFT, control, LEFT, PADDING, 0)
    icon:SetDimensions(ICON_SIZE, ICON_SIZE)
    local iconTexture = type(GetAbilityIcon) == "function" and GetAbilityIcon(BLIGHT_SEED_ID) or ""
    if not iconTexture or iconTexture == "" then
        iconTexture = "EsoUI/Art/Icons/icon_missing.dds"
    end
    icon:SetTexture(iconTexture)

    titleLabel = wm:CreateControl(CONTROL_NAME .. "Title", control, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, icon, TOPRIGHT, 8, 3)
    titleLabel:SetDimensions(146, 17)
    titleLabel:SetFont("ZoFontGameMedium")
    titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    stacksLabel = wm:CreateControl(CONTROL_NAME .. "Stacks", control, CT_LABEL)
    stacksLabel:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 0)
    stacksLabel:SetDimensions(93, 19)
    stacksLabel:SetFont("ZoFontGameLargeBold")
    stacksLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    timeLabel = wm:CreateControl(CONTROL_NAME .. "Time", control, CT_LABEL)
    timeLabel:SetAnchor(TOPRIGHT, titleLabel, BOTTOMRIGHT, 0, 0)
    timeLabel:SetDimensions(50, 19)
    timeLabel:SetFont("ZoFontGameBold")
    timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    timeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    timerBar = wm:CreateControl(CONTROL_NAME .. "TimerBar", control, CT_STATUSBAR)
    timerBar:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, PADDING + ICON_SIZE + 8, -5)
    timerBar:SetDimensions(146, BAR_HEIGHT)
    timerBar:SetMinMax(0, PREVIEW_DURATION_SECONDS)
    timerBar:SetValue(0)
    timerBar:SetColor(0.2, 0.7, 1, 0.95)

    ApplyPosition()
    ApplyStyle()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function GetPreviewState(nowSeconds)
    return {
        beginTime = nowSeconds,
        endTime = nowSeconds + PREVIEW_DURATION_SECONDS,
        stacks = PREVIEW_STACKS,
    }
end

local function UpdateVisuals()
    EnsureControl()

    local nowSeconds = GetNowSeconds()
    local state = GetActiveState(nowSeconds)
    if not state and (forceShow or IsHudUnlocked()) then
        state = GetPreviewState(nowSeconds)
    end

    local stacks = state and state.stacks or 0
    local remaining = state and math.max(0, state.endTime - nowSeconds) or 0
    local duration = state and math.max(0.1, state.endTime - state.beginTime) or PREVIEW_DURATION_SECONDS

    titleLabel:SetText(GetString(EZOM_AZUREBLIGHT_TITLE))
    stacksLabel:SetText(tostring(stacks) .. " " .. GetString(EZOM_AZUREBLIGHT_STACKS))
    timeLabel:SetText(string.format("%.1fs", remaining))
    timerBar:SetMinMax(0, duration)
    timerBar:SetValue(math.min(duration, remaining))

    local ratio = duration > 0 and remaining / duration or 0
    if ratio <= 0.25 then
        timerBar:SetColor(1, 0.25, 0.2, 0.95)
        timeLabel:SetColor(1, 0.35, 0.25, 1)
    elseif ratio <= 0.5 then
        timerBar:SetColor(1, 0.75, 0.2, 0.95)
        timeLabel:SetColor(1, 0.82, 0.3, 1)
    else
        timerBar:SetColor(0.2, 0.75, 1, 0.95)
        timeLabel:SetColor(0.45, 0.85, 1, 1)
    end
    stacksLabel:SetColor(stacks > 0 and 0.35 or 0.7, stacks > 0 and 1 or 0.7, stacks > 0 and 0.65 or 0.7, 1)
end

local function UpdateVisibility()
    EnsureControl()

    local settings = GetSettings() or {}
    local hidden = false
    if not CanShowHud() then
        hidden = true
    elseif forceShow or IsHudUnlocked() then
        hidden = false
    elseif not IsEnabled() then
        hidden = true
    elseif settings.onlyCombat ~= false and not isCombat then
        hidden = true
    elseif not GetActiveState(GetNowSeconds()) then
        hidden = true
    end

    control:SetHidden(hidden)
end

local function RefreshState()
    if not forceShow and not IsHudUnlocked() then
        ScanTrackedUnits()
    end
    UpdateVisuals()
    UpdateVisibility()
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_AzureblightUpdate", UPDATE_INTERVAL_MS, RefreshState)
    updateRegistered = true
end

local function UnregisterUpdate()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_AzureblightUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    local settings = GetSettings() or {}
    if forceShow
        or IsHudUnlocked()
        or (IsEnabled() and (settings.onlyCombat == false or isCombat)) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    UpdateVisibility()
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true
        or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    RefreshState()
    RefreshUpdateRegistration()
end

local function OnReticleTargetChanged()
    ClearState("reticleover")
    RefreshState()
end

local function OnEffectChanged(
    _,
    changeType,
    _effectSlot,
    _effectName,
    unitTag,
    beginTime,
    endTime,
    stackCount,
    _iconName,
    _buffType,
    _effectType,
    _abilityType,
    _statusEffectType,
    unitName,
    _unitId,
    abilityId,
    _sourceType
)
    if tonumber(abilityId) ~= BLIGHT_SEED_ID or not IsTrackedUnitTag(unitTag) then return end

    DebugEvent("event", unitTag, unitName, changeType, stackCount, beginTime, endTime, abilityId)
    if changeType == EFFECT_RESULT_FADED then
        ClearState(unitTag)
    else
        SetState(unitTag, unitName, beginTime, endTime, stackCount, "event")
    end
    UpdateVisuals()
    UpdateVisibility()
end

function Tracker.ShowTest()
    if not CanShowHud() then return end

    forceShow = true
    EnsureControl()
    SetMoveMode(true)
    RefreshState()
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        Tracker.ApplySettings()
    end, 5000)
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
    ApplyStyle()
    SetMoveMode(IsHudUnlocked())
    RefreshState()
    RefreshUpdateRegistration()
end

function Tracker.Init()
    EnsureControl()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_AzureblightCombat",
        EVENT_PLAYER_COMBAT_STATE,
        OnCombatState
    )
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_AzureblightEffects",
        EVENT_EFFECT_CHANGED,
        OnEffectChanged
    )
    if REGISTER_FILTER_ABILITY_ID ~= nil then
        EVENT_MANAGER:AddFilterForEvent(
            ADDON_NAME .. "_AzureblightEffects",
            EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_ABILITY_ID,
            BLIGHT_SEED_ID
        )
    end
    if EVENT_RETICLE_TARGET_CHANGED then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_AzureblightReticle",
            EVENT_RETICLE_TARGET_CHANGED,
            OnReticleTargetChanged
        )
    end
    if EVENT_EFFECTS_FULL_UPDATE then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_AzureblightFullEffects",
            EVENT_EFFECTS_FULL_UPDATE,
            RefreshState
        )
    end
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_AzureblightActivated",
            EVENT_PLAYER_ACTIVATED,
            RefreshState
        )
    end

    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

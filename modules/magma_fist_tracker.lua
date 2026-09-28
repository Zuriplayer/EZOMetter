-- Magma Fist alert driven by the player's direct Heat Shock effect events.
EZOMetter_MagmaFist = EZOMetter_MagmaFist or {}

local Tracker = EZOMetter_MagmaFist
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterMagmaFistTracker"
local MAGMA_FIST_ID = 31816
local HEAT_SHOCK_ID = 134340
local MAX_STACKS = 3
local HEAT_SHOCK_DURATION_MS = 7000
local WINDOW_MS = 6000
local EXPIRY_WARNING_MS = 1500
local UPDATE_INTERVAL_MS = 100
local REFRESH_TOLERANCE_MS = 250
local EVENT_REFRESH_DEDUPE_MS = 450
local SAME_CAST_GUARD_MS = 600
local IMPACT_DEDUPE_MS = 300
local BASE_SIZE = 64

local control
local backdrop
local icon
local timerLabel
local stackBackdrop
local stackLabel
local updateRegistered = false
local UnregisterUpdate
local forceShow = false
local previewEndMs = 0
local isCombat = false
local hasMagmaFistSlotted = false
local states = {}
local scanKeysByTag = {}
local windowStartMs = 0
local windowEndMs = 0
local cooldownUntilMs = 0
local lastMagmaImpactMs = 0

local function GetNowMs()
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetFrameTimeSeconds) == "function" then
        return GetFrameTimeSeconds() * 1000
    end
    return 0
end

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.abilities = EZOMetter.sv.abilities or {}
    return EZOMetter.sv.abilities
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.magmaFistEnabled == true
end

local function IsDebugEnabled()
    local settings = GetSettings()
    return settings
        and settings.magmaFistDebugEvents == true
        and EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.debugMode == true
end

local function Debug(message)
    if IsDebugEnabled() and EZOMetter.DebugLog then
        EZOMetter.DebugLog("[MagmaFist] " .. tostring(message))
    end
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

local function CleanUnitName(name)
    return string.gsub(tostring(name or ""), "%^.*", "")
end

local function GetStateKey(unitTag, unitName, unitId)
    unitId = tonumber(unitId) or 0
    if unitId > 0 then return "id:" .. tostring(unitId) end
    if unitTag and unitTag ~= "" then return "tag:" .. tostring(unitTag) end
    return "name:" .. CleanUnitName(unitName)
end

local function ClearExpiredStates(nowMs)
    for key, state in pairs(states) do
        if (tonumber(state.endMs) or 0) <= nowMs then
            states[key] = nil
        end
    end
end

local function GetMaxStackState(nowMs)
    ClearExpiredStates(nowMs)
    local best
    for _, state in pairs(states) do
        if (tonumber(state.stacks) or 0) >= MAX_STACKS
            and (tonumber(state.endMs) or 0) > nowMs
            and (not best or (tonumber(state.lastObservedMs) or 0) > (tonumber(best.lastObservedMs) or 0)) then
            best = state
        end
    end
    return best
end

local function GetCurrentStackState(nowMs)
    ClearExpiredStates(nowMs)
    local best
    for _, state in pairs(states) do
        if not best
            or (tonumber(state.lastObservedMs) or 0) > (tonumber(best.lastObservedMs) or 0) then
            best = state
        end
    end
    return best
end

local function IsWindowActive(nowMs)
    return windowEndMs > nowMs and windowStartMs > 0
end

local function ScanPlayerWindowCandidates()
    if not IsDebugEnabled()
        or type(GetNumBuffs) ~= "function"
        or type(GetUnitBuffInfo) ~= "function" then
        return
    end

    local nowSeconds = GetNowMs() / 1000
    for index = 1, GetNumBuffs("player") do
        local buffName, beginTime, endTime, _, stackCount, iconName, _, _, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo("player", index)
        local duration = (tonumber(endTime) or 0) - (tonumber(beginTime) or 0)
        local remaining = (tonumber(endTime) or 0) - nowSeconds
        if castByPlayer == true and duration >= 5.5 and duration <= 6.5 and remaining > 0 then
            Debug(string.format(
                "six-second player-effect candidate name=%s abilityId=%s duration=%.3f remaining=%.3f stacks=%s icon=%s",
                tostring(buffName or ""),
                tostring(abilityId or 0),
                duration,
                remaining,
                tostring(stackCount or 0),
                tostring(iconName or "")
            ))
        end
    end
end

local function ArmWindow(nowMs, state)
    windowStartMs = nowMs
    windowEndMs = nowMs + WINDOW_MS
    cooldownUntilMs = windowEndMs
    Debug(string.format(
        "empowered window armed from max-stack refresh target=%s key=%s until=%d",
        tostring(state and state.unitName or ""),
        tostring(state and state.key or ""),
        windowEndMs
    ))
    if type(zo_callLater) == "function" then
        zo_callLater(ScanPlayerWindowCandidates, 50)
    end
end

local function ConsumeWindow(nowMs, source)
    if not IsWindowActive(nowMs) then return false end
    Debug(string.format(
        "empowered window consumed source=%s remaining=%.2f",
        tostring(source or ""),
        math.max(0, windowEndMs - nowMs) / 1000
    ))
    windowStartMs = 0
    windowEndMs = 0
    return true
end

local function ExpireWindow(nowMs)
    if windowEndMs > 0 and nowMs >= windowEndMs then
        Debug("empowered window expired")
        windowStartMs = 0
        windowEndMs = 0
    end
end

local function ObserveHeatShock(
    unitTag,
    unitName,
    unitId,
    beginTime,
    endTime,
    stackCount,
    fromEvent,
    changeType
)
    local nowMs = GetNowMs()
    local key = not fromEvent and unitTag and scanKeysByTag[unitTag]
        or GetStateKey(unitTag, unitName, unitId)
    local scanKey = unitTag and scanKeysByTag[unitTag] or nil
    local state = states[key]
    if not state and fromEvent and scanKey and scanKey ~= key and states[scanKey] then
        state = states[scanKey]
        states[scanKey] = nil
        state.key = key
        scanKeysByTag[unitTag] = key
    end
    state = state or { key = key }
    local previousEventStacks = tonumber(state.eventStacks) or 0
    local previousEventEndMs = tonumber(state.eventEndMs) or 0
    local previousEventMs = tonumber(state.lastEventMs) or 0
    local eventSeen = state.eventSeen == true
    local directEndMs = math.floor(((tonumber(endTime) or 0) * 1000) + 0.5)
    local hasDirectEnd = directEndMs > nowMs
    local newEndMs = directEndMs
    local newStacks = math.max(0, tonumber(stackCount) or 0)
    if newEndMs <= nowMs then
        newEndMs = nowMs + HEAT_SHOCK_DURATION_MS
    end

    state.unitTag = unitTag or state.unitTag
    state.unitName = CleanUnitName(unitName ~= "" and unitName or state.unitName)
    state.unitId = tonumber(unitId) or state.unitId
    state.beginMs = math.floor(((tonumber(beginTime) or 0) * 1000) + 0.5)
    state.endMs = newEndMs
    state.stacks = newStacks
    state.lastObservedMs = nowMs
    states[key] = state
    if unitTag and unitTag ~= "" then
        scanKeysByTag[unitTag] = key
    end

    if not fromEvent then
        state.eventSeen = true
        state.eventStacks = newStacks
        state.eventEndMs = newEndMs
        state.lastEventMs = nowMs
        return
    end

    local isUpdatedEvent = (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED)
        and nowMs - previousEventMs > EVENT_REFRESH_DEDUPE_MS
    local refreshedAtMax = eventSeen
        and previousEventStacks >= MAX_STACKS
        and newStacks >= MAX_STACKS
        and (isUpdatedEvent
            or (hasDirectEnd and newEndMs > previousEventEndMs + REFRESH_TOLERANCE_MS))

    state.eventSeen = true
    state.eventStacks = newStacks
    state.eventEndMs = newEndMs
    state.lastEventMs = nowMs

    Debug(string.format(
        "Heat Shock target=%s key=%s change=%s stacks=%d previous=%d end=%d refreshedAtMax=%s",
        tostring(state.unitName or ""),
        key,
        tostring(changeType or "scan"),
        newStacks,
        previousEventStacks,
        newEndMs,
        tostring(refreshedAtMax)
    ))

    if not refreshedAtMax then return end

    ExpireWindow(nowMs)
    if IsWindowActive(nowMs) then
        if nowMs - windowStartMs >= SAME_CAST_GUARD_MS then
            ConsumeWindow(nowMs, "Heat Shock refresh")
        end
    elseif nowMs >= cooldownUntilMs then
        ArmWindow(nowMs, state)
    end
end

local function ScanUnit(unitTag)
    if type(DoesUnitExist) ~= "function"
        or not DoesUnitExist(unitTag)
        or type(GetNumBuffs) ~= "function"
        or type(GetUnitBuffInfo) ~= "function" then
        return false
    end

    for index = 1, GetNumBuffs(unitTag) do
        local _, beginTime, endTime, _, stackCount, _, _, _, _, _, abilityId, _, castByPlayer =
            GetUnitBuffInfo(unitTag, index)
        if tonumber(abilityId) == HEAT_SHOCK_ID and castByPlayer == true then
            local unitName = type(GetUnitName) == "function" and GetUnitName(unitTag) or ""
            local unitId = 0
            ObserveHeatShock(unitTag, unitName, unitId, beginTime, endTime, stackCount, false, nil)
            return true
        end
    end

    local oldKey = scanKeysByTag[unitTag]
    if oldKey then
        states[oldKey] = nil
        scanKeysByTag[unitTag] = nil
    end
    return false
end

local function ScanVisibleTargets()
    ScanUnit("reticleover")
    for index = 1, 6 do
        ScanUnit("boss" .. tostring(index))
    end
end

local function GetSlotAbilityId(slotIndex, hotbarCategory)
    if type(GetSlotBoundId) ~= "function" then return nil end
    local boundId = GetSlotBoundId(slotIndex, hotbarCategory)
    if not boundId or boundId == 0 then return nil end

    if type(GetSlotType) == "function"
        and ACTION_TYPE_CRAFTED_ABILITY ~= nil
        and GetSlotType(slotIndex, hotbarCategory) == ACTION_TYPE_CRAFTED_ABILITY
        and type(GetAbilityIdForCraftedAbilityId) == "function" then
        return GetAbilityIdForCraftedAbilityId(boundId), boundId
    end
    return boundId, nil
end

local function ScanMagmaFistSlot()
    hasMagmaFistSlotted = false
    local categories = {}
    if HOTBAR_CATEGORY_PRIMARY then table.insert(categories, HOTBAR_CATEGORY_PRIMARY) end
    if HOTBAR_CATEGORY_BACKUP then table.insert(categories, HOTBAR_CATEGORY_BACKUP) end
    if #categories == 0 and type(GetActiveHotbarCategory) == "function" then
        table.insert(categories, GetActiveHotbarCategory())
    end

    for _, hotbarCategory in ipairs(categories) do
        for slotIndex = 3, 7 do
            local abilityId, boundId = GetSlotAbilityId(slotIndex, hotbarCategory)
            if abilityId == MAGMA_FIST_ID
                or abilityId == HEAT_SHOCK_ID
                or boundId == MAGMA_FIST_ID
                or boundId == HEAT_SHOCK_ID then
                hasMagmaFistSlotted = true
                if icon and type(GetSlotTexture) == "function" then
                    local texture = GetSlotTexture(slotIndex, hotbarCategory)
                    if texture and texture ~= "" then icon:SetTexture(texture) end
                end
                return true
            end
        end
    end
    return false
end

local function SavePosition()
    local settings = GetSettings()
    if not settings or not control then return end
    settings.magmaFistX = control:GetLeft() - GuiRoot:GetWidth() / 2 + control:GetWidth() / 2
    settings.magmaFistY = control:GetTop() - GuiRoot:GetHeight() / 2 + control:GetHeight() / 2
end

local function ApplyPosition()
    if not control then return end
    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        tonumber(settings.magmaFistX) or 80,
        tonumber(settings.magmaFistY) or -210
    )
end

local function SetMoveMode(enabled)
    if not control then return end
    control.ezomMoveEnabled = enabled == true
    control:SetMouseEnabled(enabled == true)
    if control.ezomPrimaryDragRefresh then control.ezomPrimaryDragRefresh() end
end

local function ApplyStyle()
    if not control then return end
    local settings = GetSettings() or {}
    local size = math.max(70, math.min(180, tonumber(settings.magmaFistSize) or 100))
    control:SetScale(size / 100)
end

local function EnsureControl()
    if control then return control end

    local wm = WINDOW_MANAGER
    control = wm:CreateTopLevelWindow(CONTROL_NAME)
    control:SetDimensions(BASE_SIZE, BASE_SIZE)
    control:SetClampedToScreen(true)
    control:SetDrawTier(DT_HIGH)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetHidden(true)

    EZOMetter_VisualContext.BindPrimaryDrag(control, function()
        return control.ezomMoveEnabled == true
    end, SavePosition)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("", 4, 4, 4)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.9)

    icon = wm:CreateControl(CONTROL_NAME .. "Icon", control, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, control, TOPLEFT, 4, 4)
    icon:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -4, -4)
    local texture = type(GetAbilityIcon) == "function" and GetAbilityIcon(MAGMA_FIST_ID) or ""
    icon:SetTexture(texture ~= "" and texture or "EsoUI/Art/Icons/icon_missing.dds")

    timerLabel = wm:CreateControl(CONTROL_NAME .. "Timer", control, CT_LABEL)
    timerLabel:SetAnchorFill(control)
    timerLabel:SetFont("ZoFontWinH2")
    timerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    timerLabel:SetColor(1, 1, 1, 1)

    stackBackdrop = wm:CreateControl(CONTROL_NAME .. "StackBackdrop", control, CT_BACKDROP)
    stackBackdrop:SetAnchor(TOPRIGHT, control, TOPRIGHT, -2, 2)
    stackBackdrop:SetDimensions(20, 20)
    stackBackdrop:SetEdgeTexture("", 1, 1, 1)
    stackBackdrop:SetCenterColor(0, 0, 0, 0.92)
    stackBackdrop:SetEdgeColor(1, 0.65, 0.1, 1)

    stackLabel = wm:CreateControl(CONTROL_NAME .. "Stacks", stackBackdrop, CT_LABEL)
    stackLabel:SetAnchorFill(stackBackdrop)
    stackLabel:SetFont("ZoFontGameBold")
    stackLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    stackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    stackLabel:SetText(tostring(MAX_STACKS))
    stackLabel:SetColor(1, 0.78, 0.2, 1)

    ApplyPosition()
    ApplyStyle()
    SetMoveMode(IsHudUnlocked())
    if EZOMetter_VisualContext and EZOMetter_VisualContext.AddHudFragment then
        EZOMetter_VisualContext.AddHudFragment(control)
    end
    return control
end

local function GetVisualState(nowMs)
    if forceShow then
        return "window", math.max(0, previewEndMs - nowMs)
    end
    if IsHudUnlocked() then
        return "window", 4800
    end
    if IsWindowActive(nowMs) then
        return "window", windowEndMs - nowMs
    end
    if GetMaxStackState(nowMs) then
        return "ready", 0
    end
    return nil, 0
end

local function UpdateVisuals()
    EnsureControl()
    local nowMs = GetNowMs()
    ExpireWindow(nowMs)
    local visualState, remainingMs = GetVisualState(nowMs)
    local stackState = GetCurrentStackState(nowMs)
    local stacks = math.max(0, math.min(MAX_STACKS, tonumber(stackState and stackState.stacks) or 0))
    local heatRemainingMs = math.max(0, (tonumber(stackState and stackState.endMs) or 0) - nowMs)
    if forceShow or IsHudUnlocked() then stacks = MAX_STACKS end
    stackLabel:SetText(tostring(stacks))
    if stacks >= MAX_STACKS then
        stackBackdrop:SetEdgeColor(1, 0.65, 0.1, 1)
        stackLabel:SetColor(1, 0.78, 0.2, 1)
    else
        stackBackdrop:SetEdgeColor(0.7, 0.7, 0.7, 0.9)
        stackLabel:SetColor(0.9, 0.9, 0.9, 1)
    end

    if visualState == "window" then
        timerLabel:SetText(string.format("%.1f", math.max(0, remainingMs) / 1000))
        if remainingMs <= EXPIRY_WARNING_MS then
            timerLabel:SetColor(1, 0.25, 0.18, 1)
            backdrop:SetEdgeColor(1, 0.1, 0.05, 1)
        else
            timerLabel:SetColor(0.3, 1, 0.35, 1)
            backdrop:SetEdgeColor(0.1, 0.9, 0.18, 1)
        end
    elseif visualState == "ready" then
        timerLabel:SetText(string.format("%.1f", heatRemainingMs / 1000))
        if heatRemainingMs <= EXPIRY_WARNING_MS then
            timerLabel:SetColor(1, 0.25, 0.18, 1)
            backdrop:SetEdgeColor(1, 0.1, 0.05, 1)
            stackBackdrop:SetEdgeColor(1, 0.1, 0.05, 1)
            stackLabel:SetColor(1, 0.35, 0.22, 1)
        else
            timerLabel:SetColor(1, 0.82, 0.18, 1)
            backdrop:SetEdgeColor(1, 0.65, 0.08, 1)
        end
    else
        if stacks > 0 and heatRemainingMs > 0 then
            timerLabel:SetText(string.format("%.1f", heatRemainingMs / 1000))
            timerLabel:SetColor(1, 1, 1, 1)
        else
            timerLabel:SetText("")
        end
        backdrop:SetEdgeColor(0.65, 0.65, 0.65, 0.75)
    end
end

local function UpdateVisibility()
    EnsureControl()
    local hidden = not CanShowHud()
        or (not forceShow
            and not IsHudUnlocked()
            and (not IsEnabled()
                or not hasMagmaFistSlotted))
    control:SetHidden(hidden)
end

local function Refresh()
    UpdateVisuals()
    UpdateVisibility()
    local nowMs = GetNowMs()
    if updateRegistered
        and not forceShow
        and not IsHudUnlocked()
        and not IsWindowActive(nowMs)
        and (not IsEnabled() or not hasMagmaFistSlotted or GetCurrentStackState(nowMs) == nil) then
        UnregisterUpdate()
    end
end

local function RegisterUpdate()
    if updateRegistered then return end
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_MagmaFistUpdate", UPDATE_INTERVAL_MS, Refresh)
    updateRegistered = true
end

UnregisterUpdate = function()
    if not updateRegistered then return end
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_MagmaFistUpdate")
    updateRegistered = false
end

local function RefreshUpdateRegistration()
    local nowMs = GetNowMs()
    if forceShow
        or IsHudUnlocked()
        or IsWindowActive(nowMs)
        or (IsEnabled() and hasMagmaFistSlotted and GetCurrentStackState(nowMs) ~= nil) then
        RegisterUpdate()
    else
        UnregisterUpdate()
    end
    Refresh()
end

local function OnCombatState(_, inCombat)
    isCombat = inCombat == true
        or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    if not isCombat then
        states = {}
        scanKeysByTag = {}
        windowStartMs = 0
        windowEndMs = 0
        cooldownUntilMs = 0
        lastMagmaImpactMs = 0
    end
    ScanMagmaFistSlot()
    RefreshUpdateRegistration()
end

local function OnEffectChanged(
    _,
    changeType,
    _,
    _,
    unitTag,
    beginTime,
    endTime,
    stackCount,
    _,
    _,
    _,
    _,
    _,
    unitName,
    unitId,
    abilityId,
    sourceUnitType
)
    if tonumber(abilityId) ~= HEAT_SHOCK_ID then return end
    if COMBAT_UNIT_TYPE_PLAYER ~= nil and sourceUnitType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local key = GetStateKey(unitTag, unitName, unitId)
    if changeType == EFFECT_RESULT_FADED then
        states[key] = nil
        local scanKey = unitTag and scanKeysByTag[unitTag] or nil
        if scanKey then
            states[scanKey] = nil
            scanKeysByTag[unitTag] = nil
        end
    elseif changeType == EFFECT_RESULT_GAINED
        or changeType == EFFECT_RESULT_UPDATED
        or changeType == EFFECT_RESULT_FULL_REFRESH then
        ObserveHeatShock(unitTag, unitName, unitId, beginTime, endTime, stackCount, true, changeType)
    end
    RefreshUpdateRegistration()
end

local function IsMagmaImpactResult(result)
    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DAMAGE_SHIELDED
end

local function OnMagmaFistCombatEvent(
    _,
    result,
    isError,
    _,
    _,
    _,
    _,
    sourceType,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    _,
    abilityId
)
    if isError or tonumber(abilityId) ~= MAGMA_FIST_ID or not IsMagmaImpactResult(result) then return end
    if COMBAT_UNIT_TYPE_PLAYER ~= nil and sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end

    local nowMs = GetNowMs()
    if nowMs - lastMagmaImpactMs < IMPACT_DEDUPE_MS then return end
    lastMagmaImpactMs = nowMs
    Debug(string.format("Magma Fist impact result=%s window=%s", tostring(result), tostring(IsWindowActive(nowMs))))
    if IsWindowActive(nowMs) and nowMs - windowStartMs >= SAME_CAST_GUARD_MS then
        ConsumeWindow(nowMs, "Magma Fist impact")
    end
    RefreshUpdateRegistration()
end

local function OnSlotsChanged()
    ScanMagmaFistSlot()
    RefreshUpdateRegistration()
end

local function OnPlayerActivated()
    ScanMagmaFistSlot()
    ScanVisibleTargets()
    OnCombatState(nil, type(IsUnitInCombat) == "function" and IsUnitInCombat("player"))
end

function Tracker.ShowTest()
    if not CanShowHud() then return end
    forceShow = true
    previewEndMs = GetNowMs() + WINDOW_MS
    EnsureControl()
    SetMoveMode(true)
    RefreshUpdateRegistration()
    zo_callLater(function()
        forceShow = false
        previewEndMs = 0
        Tracker.ApplySettings()
    end, 5000)
end

function Tracker.ApplySettings()
    EnsureControl()
    ApplyPosition()
    ApplyStyle()
    SetMoveMode(IsHudUnlocked())
    ScanMagmaFistSlot()
    RefreshUpdateRegistration()
end

function Tracker.Init()
    EnsureControl()

    if EZOMetter_VisualContext and EZOMetter_VisualContext.RegisterRefresh then
        EZOMetter_VisualContext.RegisterRefresh(UpdateVisibility)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_MagmaFistCombat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_MagmaFistEffects", EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "_MagmaFistEffects",
        EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_ABILITY_ID,
        HEAT_SHOCK_ID
    )

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_MagmaFistImpacts", EVENT_COMBAT_EVENT, OnMagmaFistCombatEvent)
    EVENT_MANAGER:AddFilterForEvent(
        ADDON_NAME .. "_MagmaFistImpacts",
        EVENT_COMBAT_EVENT,
        REGISTER_FILTER_ABILITY_ID,
        MAGMA_FIST_ID
    )
    if REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and COMBAT_UNIT_TYPE_PLAYER then
        EVENT_MANAGER:AddFilterForEvent(
            ADDON_NAME .. "_MagmaFistImpacts",
            EVENT_COMBAT_EVENT,
            REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,
            COMBAT_UNIT_TYPE_PLAYER
        )
    end

    if EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_MagmaFistSlots",
            EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED,
            OnSlotsChanged
        )
    end
    if EVENT_ACTION_SLOT_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_MagmaFistSlot", EVENT_ACTION_SLOT_UPDATED, OnSlotsChanged)
    end
    if EVENT_RETICLE_TARGET_CHANGED then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_MagmaFistReticle",
            EVENT_RETICLE_TARGET_CHANGED,
            ScanVisibleTargets
        )
    end
    if EVENT_EFFECTS_FULL_UPDATE then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_MagmaFistFullEffects",
            EVENT_EFFECTS_FULL_UPDATE,
            ScanVisibleTargets
        )
    end
    if EVENT_PLAYER_ACTIVATED then
        EVENT_MANAGER:RegisterForEvent(
            ADDON_NAME .. "_MagmaFistActivated",
            EVENT_PLAYER_ACTIVATED,
            OnPlayerActivated
        )
    end

    OnPlayerActivated()
end

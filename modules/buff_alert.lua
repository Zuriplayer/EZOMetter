-- Aviso movible para buffs requeridos que no estan activos en el jugador.
EZOMetter_BuffAlert = EZOMetter_BuffAlert or {}

local BuffAlert = EZOMetter_BuffAlert
local ADDON_NAME = "EZOMetter"
local CONTROL_NAME = "EZOMetterMissingBuffAlert"
local ROW_HEIGHT = 32
local ROW_GAP = 4
local WIDTH = 280

local activeEffects = {}
local lastMissing = {}
local lastIconByKey = {}
local rows = {}
local control
local backdrop

local function GetSettings()
    if not EZOMetter.sv then return nil end
    EZOMetter.sv.alerts = EZOMetter.sv.alerts or {}
    return EZOMetter.sv.alerts
end

local function GetRole()
    return EZOMetter.sv and EZOMetter.sv.general and EZOMetter.sv.general.role or "dd"
end

local function IsEnabled()
    local settings = GetSettings()
    return settings and settings.missingBuffAlerts == true and GetRole() == "dd"
end

local function GetEffectName(effect)
    local stringId = effect and effect.nameString and _G[effect.nameString]
    if stringId then
        return GetString(stringId)
    end
    return tostring(effect and effect.key or "")
end

local function GetEffectIcon(effect)
    if not effect then return "" end
    if lastIconByKey[effect.key] then
        return lastIconByKey[effect.key]
    end

    local abilityId = EZOMetter.Effects and EZOMetter.Effects.GetPrimaryAbilityId(effect) or nil
    if abilityId and type(GetAbilityIcon) == "function" then
        return GetAbilityIcon(abilityId)
    end

    return ""
end

local function SavePosition()
    local settings = GetSettings()
    if not settings or not control then return end

    settings.alertX = control:GetLeft() - GuiRoot:GetWidth() / 2 + control:GetWidth() / 2
    settings.alertY = control:GetTop() - GuiRoot:GetHeight() / 2 + control:GetHeight() / 2
end

local function ApplyPosition()
    if not control then return end

    local settings = GetSettings() or {}
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, tonumber(settings.alertX) or 0, tonumber(settings.alertY) or -180)
end

local function SetMoveMode(enabled)
    if not control then return end

    control:SetMouseEnabled(enabled == true)
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
        backdrop:SetEdgeColor(0.75, 0.25, 0.95, 0.95)
    end
end

local function CreateRow(index)
    local wm = WINDOW_MANAGER
    local row = wm:CreateControl(CONTROL_NAME .. "Row" .. index, control, CT_CONTROL)
    row:SetDimensions(WIDTH - 20, ROW_HEIGHT)
    row:SetAnchor(TOPLEFT, control, TOPLEFT, 10, 10 + (index - 1) * (ROW_HEIGHT + ROW_GAP))

    row.icon = wm:CreateControl(CONTROL_NAME .. "Row" .. index .. "Icon", row, CT_TEXTURE)
    row.icon:SetDimensions(28, 28)
    row.icon:SetAnchor(LEFT, row, LEFT, 0, 0)

    row.label = wm:CreateControl(CONTROL_NAME .. "Row" .. index .. "Label", row, CT_LABEL)
    row.label:SetAnchor(LEFT, row.icon, RIGHT, 8, 0)
    row.label:SetAnchor(RIGHT, row, RIGHT, 0, 0)
    row.label:SetFont("ZoFontGameMedium")
    row.label:SetColor(1, 0.92, 0.78, 1)
    row.label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

    rows[index] = row
    return row
end

local function EnsureControl()
    if control then return control end

    local wm = WINDOW_MANAGER
    control = wm:CreateTopLevelWindow(CONTROL_NAME)
    control:SetDimensions(WIDTH, 48)
    control:SetClampedToScreen(true)
    control:SetDrawTier(DT_HIGH)
    control:SetHidden(true)
    control:SetHandler("OnMoveStop", SavePosition)

    backdrop = wm:CreateControl(CONTROL_NAME .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16)
    ApplyStyle()

    ApplyPosition()
    SetMoveMode(GetSettings() and GetSettings().unlockAlert == true)
    return control
end

local function HideAlert()
    if control and not (GetSettings() and GetSettings().unlockAlert == true) then
        control:SetHidden(true)
    end
end

local function ShowEffects(effects)
    EnsureControl()

    local count = #effects
    if count == 0 then
        HideAlert()
        return
    end

    control:SetDimensions(WIDTH, 20 + count * ROW_HEIGHT + (count - 1) * ROW_GAP)

    for index, effect in ipairs(effects) do
        local row = rows[index] or CreateRow(index)
        row.icon:SetTexture(GetEffectIcon(effect))
        row.label:SetText(GetEffectName(effect))
        row:SetHidden(false)
    end

    for index = count + 1, #rows do
        rows[index]:SetHidden(true)
    end

    control:SetHidden(false)
end

local function EffectIsActive(effect)
    return effect and activeEffects[effect.key] == true
end

local function GetMissingEffects()
    local missing = {}
    local required = EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole(GetRole()) or {}

    for _, effect in ipairs(required) do
        if not EffectIsActive(effect) then
            table.insert(missing, effect)
        end
    end

    return missing
end

local function MissingChanged(missing)
    local current = {}
    for _, effect in ipairs(missing) do
        current[effect.key] = true
    end

    for key in pairs(current) do
        if lastMissing[key] ~= true then
            lastMissing = current
            return true
        end
    end

    for key in pairs(lastMissing) do
        if current[key] ~= true then
            lastMissing = current
            return false
        end
    end

    lastMissing = current
    return false
end

local function Refresh()
    if not IsEnabled() then
        activeEffects = {}
        lastMissing = {}
        if control then control:SetHidden(true) end
        return
    end

    local missing = GetMissingEffects()
    MissingChanged(missing)
    ShowEffects(missing)
end

local function ScanPlayerBuffs()
    activeEffects = {}

    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        Refresh()
        return
    end

    local buffCount = GetNumBuffs("player") or 0
    for index = 1, buffCount do
        local buffName, _, _, _, _, iconFilename, _, _, _, _, abilityId = GetUnitBuffInfo("player", index)
        if EZOMetter.Effects then
            for _, effect in ipairs(EZOMetter.Effects.GetRequiredForRole(GetRole())) do
                if EZOMetter.Effects.Matches(effect, abilityId, buffName) then
                    activeEffects[effect.key] = true
                    if iconFilename then
                        lastIconByKey[effect.key] = iconFilename
                    end
                end
            end
        end
    end

    Refresh()
end

local function OnEffectChanged(_, changeType, _, effectName, unitTag, _, _, _, iconName, _, _, _, _, _, _, abilityId)
    if unitTag ~= "player" then return end

    if changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED then
        if EZOMetter.Effects then
            for _, effect in ipairs(EZOMetter.Effects.GetRequiredForRole(GetRole())) do
                if EZOMetter.Effects.Matches(effect, abilityId, effectName) then
                    activeEffects[effect.key] = true
                    if iconName then
                        lastIconByKey[effect.key] = iconName
                    end
                end
            end
        end
        Refresh()
    elseif changeType == EFFECT_RESULT_FADED then
        ScanPlayerBuffs()
    end
end

function BuffAlert.Refresh()
    ScanPlayerBuffs()
end

function BuffAlert.ShowTest()
    local required = EZOMetter.Effects and EZOMetter.Effects.GetRequiredForRole("dd") or {}
    ShowEffects(required)
end

function BuffAlert.ApplySettings()
    EnsureControl()
    ApplyPosition()
    SetMoveMode(GetSettings() and GetSettings().unlockAlert == true)
    ApplyStyle()
    ScanPlayerBuffs()
    if GetSettings() and GetSettings().unlockAlert == true then
        BuffAlert.ShowTest()
    end
end

function BuffAlert.Init()
    EnsureControl()
    EVENT_MANAGER:RegisterForEvent(
        ADDON_NAME .. "_PlayerBuffs",
        EVENT_EFFECT_CHANGED,
        OnEffectChanged
    )
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "_PlayerBuffs", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    zo_callLater(function()
        ScanPlayerBuffs()
    end, 2000)
end

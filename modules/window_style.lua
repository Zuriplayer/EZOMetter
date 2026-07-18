-- Shared visual scaling for EZOMetter HUD windows.
EZOMetter_WindowStyle = EZOMetter_WindowStyle or {}

local WindowStyle = EZOMetter_WindowStyle
local DEFAULT_TEXT_SIZE = 100
local MIN_TEXT_SIZE = 70
local MAX_TEXT_SIZE = 150

local function ClampPercent(value, fallback)
    value = tonumber(value) or fallback or DEFAULT_TEXT_SIZE
    if value < MIN_TEXT_SIZE then return MIN_TEXT_SIZE end
    if value > MAX_TEXT_SIZE then return MAX_TEXT_SIZE end
    return value
end

function WindowStyle.GetDefaultTextSize()
    return DEFAULT_TEXT_SIZE
end

function WindowStyle.NormalizeTextSize(value)
    return ClampPercent(value, DEFAULT_TEXT_SIZE)
end

function WindowStyle.GetTextScale()
    local settings = EZOMetter and EZOMetter.sv and EZOMetter.sv.general
    return ClampPercent(settings and settings.windowTextSize, DEFAULT_TEXT_SIZE) / 100
end

function WindowStyle.ApplyControlScale(control, extraPercent)
    if not control or not control.SetScale then return end
    local extraScale = ClampPercent(extraPercent or 100, 100) / 100
    control:SetScale(WindowStyle.GetTextScale() * extraScale)
end

-- Shared visual scaling for EZOMetter HUD windows.
EZOMetter_WindowStyle = EZOMetter_WindowStyle or {}

local WindowStyle = EZOMetter_WindowStyle
local DEFAULT_TEXT_SIZE = 100
local MIN_TEXT_SIZE = 70
local MAX_TEXT_SIZE = 150
local DEFAULT_BACKGROUND = { r = 0.03, g = 0.03, b = 0.03 }
local DEFAULT_BACKGROUND_OPACITY = 86
local DEFAULT_BORDER_COLOR = { r = 0.69, g = 0.25, b = 1, a = 0.92 }

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

function WindowStyle.GetHudAppearance()
    local general = EZOMetter and EZOMetter.sv and EZOMetter.sv.general or {}
    local opacity = tonumber(general.hudBackgroundOpacity) or DEFAULT_BACKGROUND_OPACITY
    local storedColor = general.hudBorderColor or DEFAULT_BORDER_COLOR

    return {
        backgroundOpacity = math.max(0, math.min(100, opacity)),
        showBorder = general.hudShowBorder ~= false,
        borderColor = {
            r = tonumber(storedColor.r) or DEFAULT_BORDER_COLOR.r,
            g = tonumber(storedColor.g) or DEFAULT_BORDER_COLOR.g,
            b = tonumber(storedColor.b) or DEFAULT_BORDER_COLOR.b,
            a = tonumber(storedColor.a) or DEFAULT_BORDER_COLOR.a,
        },
    }
end

function WindowStyle.ApplyBackdropStyle(backdrop, options)
    if not backdrop then return end
    options = options or {}

    local appearance = WindowStyle.GetHudAppearance()
    local background = options.backgroundColor or DEFAULT_BACKGROUND
    local opacityMultiplier = math.max(0, math.min(1, tonumber(options.opacityMultiplier) or 1))
    backdrop:SetCenterColor(
        background.r or 0,
        background.g or 0,
        background.b or 0,
        (appearance.backgroundOpacity / 100) * opacityMultiplier
    )

    if appearance.showBorder and options.hideBorder ~= true then
        local border = appearance.borderColor
        backdrop:SetEdgeColor(border.r, border.g, border.b, border.a)
    else
        backdrop:SetEdgeColor(0, 0, 0, 0)
    end
end

function WindowStyle.CreatePanel(name, width, height, options)
    if not WINDOW_MANAGER then return nil end
    options = options or {}

    local control = WINDOW_MANAGER:CreateTopLevelWindow(name)
    control:SetDimensions(width, height)
    control:SetClampedToScreen(true)
    control:SetHidden(true)
    if control.SetDrawTier and options.drawTier then
        control:SetDrawTier(options.drawTier)
    end
    if control.SetDrawLayer and options.drawLayer then
        control:SetDrawLayer(options.drawLayer)
    end
    if control.SetDrawLevel and options.drawLevel then
        control:SetDrawLevel(options.drawLevel)
    end

    local backdrop = WINDOW_MANAGER:CreateControl(name .. "Backdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetEdgeTexture(options.edgeTexture or "", 1, 1, 1)

    local accent = WINDOW_MANAGER:CreateControl(name .. "Accent", control, CT_BACKDROP)
    accent:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
    accent:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
    accent:SetDimensions(options.accentWidth or 3, 0)
    accent:SetEdgeTexture("", 1, 1, 1)

    return {
        control = control,
        backdrop = backdrop,
        accent = accent,
    }
end

function WindowStyle.ApplyPanelStyle(panel, options)
    if not panel or not panel.control or not panel.backdrop then return end
    options = options or {}

    WindowStyle.ApplyControlScale(panel.control, options.extraScale)

    WindowStyle.ApplyBackdropStyle(panel.backdrop, options)

    if panel.accent then
        local appearance = WindowStyle.GetHudAppearance()
        local accent = appearance.borderColor
        panel.accent:SetCenterColor(accent.r, accent.g, accent.b, accent.a)
        panel.accent:SetEdgeColor(accent.r, accent.g, accent.b, accent.a)
        panel.accent:SetHidden(not appearance.showBorder or options.showAccent == false)
    end
end

function WindowStyle.CreateGrid(parent, definition)
    if not parent or type(definition) ~= "table" or type(definition.columns) ~= "table" then
        return nil
    end

    local columns = {}
    local offsets = {}
    local gap = tonumber(definition.columnGap) or 0
    local totalWidth = 0
    for index, width in ipairs(definition.columns) do
        offsets[index] = totalWidth
        columns[index] = math.max(0, tonumber(width) or 0)
        totalWidth = totalWidth + columns[index]
        if index < #definition.columns then
            totalWidth = totalWidth + gap
        end
    end

    local grid = {
        parent = parent,
        columns = columns,
        offsets = offsets,
        left = tonumber(definition.left) or 0,
        top = tonumber(definition.top) or 0,
        rowHeight = math.max(1, tonumber(definition.rowHeight) or 1),
        rowGap = math.max(0, tonumber(definition.rowGap) or 0),
        columnGap = gap,
        width = totalWidth,
    }

    function grid:Place(control, column, row, columnSpan, rowSpan)
        if not control or not self.columns[column] then return end
        columnSpan = math.max(1, tonumber(columnSpan) or 1)
        rowSpan = math.max(1, tonumber(rowSpan) or 1)
        local finalColumn = math.min(#self.columns, column + columnSpan - 1)
        local width = 0
        for index = column, finalColumn do
            width = width + self.columns[index]
            if index < finalColumn then
                width = width + self.columnGap
            end
        end
        local y = self.top + ((math.max(1, tonumber(row) or 1) - 1) * (self.rowHeight + self.rowGap))
        local height = (self.rowHeight * rowSpan) + (self.rowGap * (rowSpan - 1))

        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, self.parent, TOPLEFT, self.left + self.offsets[column], y)
        control:SetDimensions(width, height)
    end

    return grid
end

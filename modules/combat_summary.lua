-- Utilidades compartidas para resumenes de ultimo combate.
EZOMetter_CombatSummary = EZOMetter_CombatSummary or {}

local Summary = EZOMetter_CombatSummary

function Summary.GetNowMs()
    if type(GetGameTimeMilliseconds) == "function" then
        return GetGameTimeMilliseconds()
    end
    if type(GetGameTimeSeconds) == "function" then
        return GetGameTimeSeconds() * 1000
    end
    return 0
end

function Summary.FormatSeconds(ms)
    return string.format("%.1f", math.max(0, tonumber(ms) or 0) / 1000)
end

function Summary.FormatPercent(value)
    return string.format("%.1f%%", math.max(0, math.min(100, tonumber(value) or 0)))
end

function Summary.ShowTooltip(control, text)
    if not control or not InformationTooltip or type(InitializeTooltip) ~= "function" then return end

    InitializeTooltip(InformationTooltip, control, TOPLEFT, 0, 0, BOTTOMLEFT)
    SetTooltipText(InformationTooltip, tostring(text or ""))
end

function Summary.HideTooltip()
    if InformationTooltip and type(ClearTooltip) == "function" then
        ClearTooltip(InformationTooltip)
    end
end

function Summary.CreateUptimeTracker(options)
    local tracker = {
        toleranceMs = options and options.toleranceMs or 250,
        getItems = options and options.getItems,
        getItemKey = options and options.getItemKey,
        getItemName = options and options.getItemName,
        isItemRequired = options and options.isItemRequired,
        isItemActive = options and options.isItemActive,
        order = {},
        byKey = {},
        started = false,
        startMs = 0,
        lastSampleMs = 0,
        durationMs = 0,
        lastSummary = nil,
    }

    local function EnsureStat(item)
        local key = tracker.getItemKey(item)
        local stat = tracker.byKey[key]
        if not stat then
            stat = {
                key = key,
                item = item,
                requiredMs = 0,
                activeMs = 0,
                missingMs = 0,
                drops = 0,
                lastActive = nil,
            }
            tracker.byKey[key] = stat
            table.insert(tracker.order, key)
        else
            stat.item = item
        end
        return stat
    end

    function tracker:Start(nowMs)
        nowMs = nowMs or Summary.GetNowMs()
        self.order = {}
        self.byKey = {}
        self.started = true
        self.startMs = nowMs
        self.lastSampleMs = nowMs
        self.durationMs = 0
        self.lastSummary = nil
    end

    function tracker:Sample(nowMs)
        if not self.started then return end

        nowMs = nowMs or Summary.GetNowMs()
        local deltaMs = nowMs - (self.lastSampleMs or nowMs)
        if deltaMs <= 0 then
            self.lastSampleMs = nowMs
            return
        end

        self.durationMs = self.durationMs + deltaMs
        local items = self.getItems and self.getItems() or {}
        for _, item in ipairs(items) do
            if not self.isItemRequired or self.isItemRequired(item) then
                local stat = EnsureStat(item)
                local active = self.isItemActive and self.isItemActive(item) == true
                stat.requiredMs = stat.requiredMs + deltaMs
                if active then
                    stat.activeMs = stat.activeMs + deltaMs
                else
                    stat.missingMs = stat.missingMs + deltaMs
                end

                if stat.lastActive == true and active == false then
                    stat.drops = stat.drops + 1
                end
                stat.lastActive = active
            end
        end

        self.lastSampleMs = nowMs
    end

    function tracker:Finish(nowMs)
        if not self.started then return self.lastSummary end

        self:Sample(nowMs or Summary.GetNowMs())
        local rows = {}
        local byKey = {}
        local allRows = {}
        local allByKey = {}
        local hasIssues = false

        for _, key in ipairs(self.order) do
            local stat = self.byKey[key]
            if stat and stat.requiredMs > 0 then
                local missingMs = math.max(0, stat.requiredMs - stat.activeMs)
                local uptime = (stat.activeMs / stat.requiredMs) * 100
                local row = {
                    key = key,
                    name = self.getItemName and self.getItemName(stat.item) or tostring(key),
                    requiredMs = stat.requiredMs,
                    activeMs = stat.activeMs,
                    missingMs = missingMs,
                    uptime = uptime,
                    drops = stat.drops,
                }

                table.insert(allRows, row)
                allByKey[key] = row

                if missingMs > self.toleranceMs then
                    hasIssues = true
                    table.insert(rows, row)
                    byKey[key] = row
                end
            end
        end

        self.lastSummary = {
            durationMs = self.durationMs,
            rows = rows,
            byKey = byKey,
            allRows = allRows,
            allByKey = allByKey,
            hasIssues = hasIssues,
        }
        self.started = false
        return self.lastSummary
    end

    function tracker:GetLastSummary()
        return self.lastSummary
    end

    return tracker
end

function Summary.CreateValueTracker(options)
    local tracker = {
        getItems = options and options.getItems,
        getItemKey = options and options.getItemKey,
        getItemName = options and options.getItemName,
        isItemRequired = options and options.isItemRequired,
        getItemValue = options and options.getItemValue,
        getItemBand = options and options.getItemBand,
        order = {},
        byKey = {},
        started = false,
        startMs = 0,
        lastSampleMs = 0,
        durationMs = 0,
        lastSummary = nil,
    }

    local function EnsureStat(item)
        local key = tracker.getItemKey(item)
        local stat = tracker.byKey[key]
        if not stat then
            stat = {
                key = key,
                item = item,
                requiredMs = 0,
                weightedValue = 0,
                minValue = nil,
                maxValue = 0,
                lastValue = nil,
                bandMs = {},
            }
            tracker.byKey[key] = stat
            table.insert(tracker.order, key)
        else
            stat.item = item
        end
        return stat
    end

    function tracker:Start(nowMs)
        nowMs = nowMs or Summary.GetNowMs()
        self.order = {}
        self.byKey = {}
        self.started = true
        self.startMs = nowMs
        self.lastSampleMs = nowMs
        self.durationMs = 0
        self.lastSummary = nil
    end

    function tracker:Sample(nowMs)
        if not self.started then return end

        nowMs = nowMs or Summary.GetNowMs()
        local deltaMs = nowMs - (self.lastSampleMs or nowMs)
        if deltaMs <= 0 then
            self.lastSampleMs = nowMs
            return
        end

        self.durationMs = self.durationMs + deltaMs
        local items = self.getItems and self.getItems() or {}
        for _, item in ipairs(items) do
            if not self.isItemRequired or self.isItemRequired(item) then
                local stat = EnsureStat(item)
                local value = tonumber(self.getItemValue and self.getItemValue(item) or 0) or 0
                local band = self.getItemBand and self.getItemBand(item) or nil

                stat.requiredMs = stat.requiredMs + deltaMs
                stat.weightedValue = stat.weightedValue + (value * deltaMs)
                stat.minValue = stat.minValue and math.min(stat.minValue, value) or value
                stat.maxValue = math.max(stat.maxValue, value)
                stat.lastValue = value
                if band then
                    stat.bandMs[band] = (stat.bandMs[band] or 0) + deltaMs
                end
            end
        end

        self.lastSampleMs = nowMs
    end

    local function BuildSummary(self)
        local rows = {}
        local byKey = {}

        for _, key in ipairs(self.order) do
            local stat = self.byKey[key]
            if stat and stat.requiredMs > 0 then
                local row = {
                    key = key,
                    name = self.getItemName and self.getItemName(stat.item) or tostring(key),
                    requiredMs = stat.requiredMs,
                    averageValue = stat.weightedValue / stat.requiredMs,
                    minValue = stat.minValue or 0,
                    maxValue = stat.maxValue,
                    lastValue = stat.lastValue or 0,
                    bandMs = stat.bandMs,
                }
                table.insert(rows, row)
                byKey[key] = row
            end
        end

        return {
            durationMs = self.durationMs,
            rows = rows,
            byKey = byKey,
            hasData = #rows > 0,
        }
    end

    function tracker:Finish(nowMs)
        if not self.started then return self.lastSummary end

        self:Sample(nowMs or Summary.GetNowMs())
        self.lastSummary = BuildSummary(self)
        self.started = false
        return self.lastSummary
    end

    function tracker:GetCurrentSummary()
        if self.started then
            return BuildSummary(self)
        end
        return self.lastSummary
    end

    function tracker:GetLastSummary()
        return self.lastSummary
    end

    return tracker
end

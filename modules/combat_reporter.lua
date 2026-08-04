-- Informe informativo unico al terminar combate.
EZOMetter_CombatReporter = EZOMetter_CombatReporter or {}

local Reporter = EZOMetter_CombatReporter
local ADDON_NAME = "EZOMetter"
local REPORT_DELAY_MS = 750

local combatActive = false
local reportSequence = 0
local currentContext = nil

local ARENA_ZONE_IDS = {
    [635] = true, -- Dragonstar Arena
    [677] = true, -- Maelstrom Arena
    [1082] = true, -- Blackrose Prison
    [1227] = true, -- Vateshran Hollows
    [1436] = true, -- Infinite Archive
}

local providers = {
    { settingsKey = "alerts", get = function() return EZOMetter_BuffAlert end },
    { settingsKey = "offBalance", get = function() return EZOMetter_OffBalance end },
    { settingsKey = "coral", get = function() return EZOMetter_Coral end },
    { settingsKey = "highland", get = function() return EZOMetter_Highland end },
    { settingsKey = "alkosh", get = function() return EZOMetter_Alkosh end },
    { settingsKey = "zen", get = function() return EZOMetter_Zen end },
    { settingsKey = "ddStats", get = function() return EZOMetter_DDStats end },
    { settingsKey = "observedDamage", get = function() return EZOMetter_ObservedDamage end },
    { settingsKey = "observedHealing", get = function() return EZOMetter_ObservedHealing end },
    { settingsKey = "abilities", get = function() return EZOMetter_AbilityTracker end },
}

local function IsEnabled()
    return EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.combatReportEnabled == true
end

local function GetNowText()
    if type(GetTimeStamp) == "function" and os and os.date then
        return os.date("%Y-%m-%d %H:%M:%S", GetTimeStamp())
    end
    if type(GetDate) == "function" and type(GetTimeString) == "function" then
        return tostring(GetDate()) .. " " .. GetTimeString()
    end
    return "--:--"
end

local function GetCharacterName()
    if type(GetUnitName) ~= "function" then return nil end

    local name = GetUnitName("player")
    if name and name ~= "" then
        return name
    end

    return nil
end

local function GetZoneInfo()
    local zoneName = "-"
    local zoneId = nil

    if type(GetUnitZoneIndex) == "function" and type(GetZoneNameByIndex) == "function" then
        local zoneIndex = GetUnitZoneIndex("player")
        local rawZoneName = zoneIndex and GetZoneNameByIndex(zoneIndex) or ""
        if rawZoneName and rawZoneName ~= "" then
            zoneName = rawZoneName
        end
        if zoneIndex and type(GetZoneId) == "function" then
            zoneId = GetZoneId(zoneIndex)
        end
    end

    return zoneName, zoneId
end

local function GetDifficulty()
    if type(GetCurrentZoneDungeonDifficulty) ~= "function" then
        return nil
    end
    return GetCurrentZoneDungeonDifficulty()
end

local function IsDungeonDifficulty(difficulty)
    if difficulty == nil then return false end
    if type(DUNGEON_DIFFICULTY_NONE) == "number" then
        return difficulty ~= DUNGEON_DIFFICULTY_NONE
    end
    return difficulty ~= 0
end

local function GetDifficultyText(difficulty)
    if not IsDungeonDifficulty(difficulty) then return nil end
    if type(DUNGEON_DIFFICULTY_VETERAN) == "number" and difficulty == DUNGEON_DIFFICULTY_VETERAN then
        return GetString(EZOM_REPORT_DIFFICULTY_VETERAN)
    end
    if type(DUNGEON_DIFFICULTY_NORMAL) == "number" and difficulty == DUNGEON_DIFFICULTY_NORMAL then
        return GetString(EZOM_REPORT_DIFFICULTY_NORMAL)
    end
    return tostring(difficulty)
end

local function GetContentText(difficulty, zoneId)
    if type(IsPlayerInRaid) == "function" and IsPlayerInRaid() then
        return GetString(EZOM_REPORT_CONTENT_TRIAL)
    end

    if zoneId and ARENA_ZONE_IDS[zoneId] then
        return GetString(EZOM_REPORT_CONTENT_ARENA)
    end

    if type(IsUnitInDungeon) == "function"
        and IsUnitInDungeon("player")
        and IsDungeonDifficulty(difficulty) then
        return GetString(EZOM_REPORT_CONTENT_DUNGEON)
    end

    if IsDungeonDifficulty(difficulty) then
        return GetString(EZOM_REPORT_CONTENT_INSTANCE)
    end

    return GetString(EZOM_REPORT_CONTENT_OVERLAND)
end

local function GetBossNames()
    if type(GetUnitName) ~= "function" then return nil end

    local bossNames = {}
    local maxBosses = type(BOSS_RANK_ITERATION_END) == "number" and BOSS_RANK_ITERATION_END or 6

    for index = 1, maxBosses do
        local unitTag = "boss" .. tostring(index)
        local exists = type(DoesUnitExist) ~= "function" or DoesUnitExist(unitTag)
        if exists then
            local name = GetUnitName(unitTag)
            if name and name ~= "" then
                table.insert(bossNames, name)
            end
        end
    end

    if #bossNames > 0 then
        return table.concat(bossNames, " / ")
    end

    return nil
end

local function BuildContext()
    local zoneName, zoneId = GetZoneInfo()
    local difficulty = GetDifficulty()

    return {
        date = GetNowText(),
        characterName = GetCharacterName(),
        zoneName = zoneName,
        zoneId = zoneId,
        content = GetContentText(difficulty, zoneId),
        difficulty = GetDifficultyText(difficulty),
        bossName = GetBossNames(),
    }
end

local function RefreshContextBoss(context)
    if not context then return end
    local bossName = GetBossNames()
    if bossName and bossName ~= "" then
        context.bossName = bossName
    end
end

local function LogInfo(message)
    local logger = nil
    if EZOMetter and type(EZOMetter.GetDebugLogger) == "function" then
        logger = EZOMetter.GetDebugLogger()
    end

    if logger and type(logger.Info) == "function" then
        local ok = pcall(function()
            if logger.SetLogTracesOverride then
                logger:SetLogTracesOverride(false)
            end
            logger:Info("%s", tostring(message))
        end)
        return ok == true
    end

    return false
end

local function CollectSections()
    local sections = {}
    for _, providerConfig in ipairs(providers) do
        local settings = EZOMetter.sv and EZOMetter.sv[providerConfig.settingsKey]
        local provider = providerConfig.get()
        if settings
            and settings.combatReportEnabled ~= false
            and provider
            and provider.GetReportSection then
            local section = provider.GetReportSection()
            if section and section ~= "" then
                table.insert(sections, section)
            end
        end
    end
    return sections
end

local function EmitReport(context, sections)
    local zoneText = context.zoneName or "-"
    if context.zoneId then
        zoneText = zoneText .. " (" .. tostring(context.zoneId) .. ")"
    end

    local lines = {
        GetString(EZOM_REPORT_TITLE),
        GetString(EZOM_REPORT_DATE) .. ": " .. (context.date or GetNowText()),
        GetString(EZOM_REPORT_CHARACTER) .. ": " .. (context.characterName or "-"),
        GetString(EZOM_REPORT_CONTENT) .. ": " .. (context.content or "-"),
        GetString(EZOM_REPORT_ZONE) .. ": " .. zoneText,
        GetString(EZOM_REPORT_BOSS) .. ": " .. (context.bossName or GetString(EZOM_REPORT_TRASH)),
    }

    if context.difficulty then
        table.insert(lines, GetString(EZOM_REPORT_DIFFICULTY) .. ": " .. context.difficulty)
    end

    if #sections == 0 then
        table.insert(lines, GetString(EZOM_REPORT_NO_DATA))
    else
        for _, section in ipairs(sections) do
            table.insert(lines, "")
            table.insert(lines, section)
        end
    end

    LogInfo(table.concat(lines, "\n"))
end

local function ScheduleReport(context, sections)
    reportSequence = reportSequence + 1
    local sequence = reportSequence

    if type(zo_callLater) == "function" then
        zo_callLater(function() EmitReport(context, sections) end, REPORT_DELAY_MS)
    else
        local updateName = ADDON_NAME .. "_CombatReportOnce_" .. tostring(sequence)
        EVENT_MANAGER:RegisterForUpdate(updateName, REPORT_DELAY_MS, function()
            EVENT_MANAGER:UnregisterForUpdate(updateName)
            EmitReport(context, sections)
        end)
    end
end

local function OnCombatState(_, inCombat)
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    if nowCombat then
        if combatActive then
            RefreshContextBoss(currentContext)
            return
        end
        combatActive = true
        currentContext = BuildContext()
        return
    end

    if not combatActive then return end
    RefreshContextBoss(currentContext)
    local context = currentContext or BuildContext()
    combatActive = false
    currentContext = nil

    if not IsEnabled() then return end
    ScheduleReport(context, CollectSections())
end

local function OnBossesChanged()
    if combatActive then
        RefreshContextBoss(currentContext)
    end
end

function Reporter.Init()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CombatReporter", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_CombatReporterBosses", EVENT_BOSSES_CHANGED, OnBossesChanged)
end

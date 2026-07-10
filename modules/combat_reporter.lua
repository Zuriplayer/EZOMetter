-- Informe informativo unico al terminar combate.
EZOMetter_CombatReporter = EZOMetter_CombatReporter or {}

local Reporter = EZOMetter_CombatReporter
local ADDON_NAME = "EZOMetter"
local REPORT_DELAY_MS = 750

local combatActive = false
local reportToken = 0
local currentContext = nil
local lastContext = nil

local ARENA_ZONE_IDS = {
    [635] = true, -- Dragonstar Arena
    [677] = true, -- Maelstrom Arena
    [1082] = true, -- Blackrose Prison
    [1227] = true, -- Vateshran Hollows
    [1436] = true, -- Infinite Archive
}

local providers = {
    function() return EZOMetter_BuffAlert end,
    function() return EZOMetter_OffBalance end,
    function() return EZOMetter_Coral end,
    function() return EZOMetter_DDStats end,
    function() return EZOMetter_ObservedDamage end,
    function() return EZOMetter_ObservedHealing end,
    function() return EZOMetter_AbilityTracker end,
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
    if LibDebugLogger then
        local logger = LibDebugLogger(ADDON_NAME)
        if logger and logger.Info then
            if logger.SetLogTracesOverride then
                logger:SetLogTracesOverride(false)
            end
            logger:Info("%s", tostring(message))
            return
        end
    end

    if EZOMetter.Print then
        EZOMetter.Print("|cFFFF75" .. tostring(message) .. "|r")
    end
end

local function CollectSections()
    local sections = {}
    for _, getProvider in ipairs(providers) do
        local provider = getProvider()
        if provider and provider.GetReportSection then
            local section = provider.GetReportSection()
            if section and section ~= "" then
                table.insert(sections, section)
            end
        end
    end
    return sections
end

local function EmitReport(token)
    if token ~= reportToken or not IsEnabled() then return end

    RefreshContextBoss(currentContext)
    local context = lastContext or currentContext or BuildContext()
    local sections = CollectSections()
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

local function OnCombatState(_, inCombat)
    local nowCombat = inCombat == true or (type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true)
    if nowCombat then
        combatActive = true
        currentContext = BuildContext()
        lastContext = nil
        reportToken = reportToken + 1
        return
    end

    if not combatActive then return end
    RefreshContextBoss(currentContext)
    lastContext = currentContext
    combatActive = false
    reportToken = reportToken + 1
    local token = reportToken

    if type(zo_callLater) == "function" then
        zo_callLater(function() EmitReport(token) end, REPORT_DELAY_MS)
    else
        EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_CombatReportOnce", REPORT_DELAY_MS, function()
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "_CombatReportOnce")
            EmitReport(token)
        end)
    end
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

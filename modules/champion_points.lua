-- Minimal Champion Point helpers used by combat trackers.
EZOMetter_ChampionPoints = EZOMetter_ChampionPoints or {}

local CP = EZOMetter_ChampionPoints
local ADDON_NAME = "EZOMetter"
local EXPLOITER_MAX_BONUS = 10
local EXPLOITER_BONUS_PER_STAGE = 2
local EXPLOITER_POINTS_PER_STAGE = 10

local exploiterId
local cachedExploiter

local EXPLOITER_NAMES = {
    ["exploiter"] = true,
    ["explotador"] = true,
}

local function NormalizeName(name)
    name = tostring(name or "")
    if type(zo_strformat) == "function" and SI_CHAMPION_CONSTELLATION_NAME_FORMAT then
        name = zo_strformat(SI_CHAMPION_CONSTELLATION_NAME_FORMAT, name)
    end
    name = string.gsub(name, "%^.*", "")
    name = string.gsub(name, "%s+", " ")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if type(zo_strlower) == "function" then
        return zo_strlower(name)
    end
    return string.lower(name)
end

local function GetChampionName(starId)
    if type(GetChampionSkillName) ~= "function" then return "" end
    local name = GetChampionSkillName(starId)
    if type(zo_strformat) == "function" and SI_CHAMPION_CONSTELLATION_NAME_FORMAT then
        name = zo_strformat(SI_CHAMPION_CONSTELLATION_NAME_FORMAT, name)
    end
    return tostring(name or "")
end

local function IsExploiterName(name)
    return EXPLOITER_NAMES[NormalizeName(name)] == true
end

local function DiscoverExploiterId()
    if exploiterId then return exploiterId end
    if not CHAMPION_DATA_MANAGER or not CHAMPION_DATA_MANAGER.disciplineDatas then return nil end

    for _, discipline in pairs(CHAMPION_DATA_MANAGER.disciplineDatas) do
        local stars = discipline and discipline.championSkillDatas
        if stars then
            for _, star in pairs(stars) do
                local starId = star and (star.championSkillId or (star.GetId and star:GetId()))
                if starId and IsExploiterName(GetChampionName(starId)) then
                    exploiterId = starId
                    return exploiterId
                end
            end
        end
    end

    return nil
end

local function IsChampionSlotSlotted(starId)
    if not starId or type(GetSlotBoundId) ~= "function" or HOTBAR_CATEGORY_CHAMPION == nil then
        return false
    end

    for slotIndex = 1, 12 do
        if GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION) == starId then
            return true
        end
    end
    return false
end

local function FindSlottedExploiterId()
    if type(GetSlotBoundId) ~= "function" or HOTBAR_CATEGORY_CHAMPION == nil then return nil end

    for slotIndex = 1, 12 do
        local starId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_CHAMPION)
        if starId and starId > 0 and IsExploiterName(GetChampionName(starId)) then
            exploiterId = starId
            return starId
        end
    end
    return nil
end

local function GetPoints(starId)
    if not starId or type(GetNumPointsSpentOnChampionSkill) ~= "function" then return 0 end
    return tonumber(GetNumPointsSpentOnChampionSkill(starId)) or 0
end

function CP.Refresh()
    local starId = DiscoverExploiterId() or FindSlottedExploiterId()
    local points = GetPoints(starId)
    local slotted = IsChampionSlotSlotted(starId)
    local bonus = 0

    if slotted then
        bonus = math.floor(points / EXPLOITER_POINTS_PER_STAGE) * EXPLOITER_BONUS_PER_STAGE
        bonus = math.max(0, math.min(EXPLOITER_MAX_BONUS, bonus))
    end

    cachedExploiter = {
        id = starId,
        name = starId and GetChampionName(starId) or "Exploiter",
        found = starId ~= nil,
        slotted = slotted,
        points = points,
        bonusPct = bonus,
        maxBonusPct = EXPLOITER_MAX_BONUS,
    }

    return cachedExploiter
end

function CP.GetExploiter()
    if not cachedExploiter then
        return CP.Refresh()
    end
    return cachedExploiter
end

local function RegisterEvent(eventId, suffix)
    if eventId == nil then return end
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ChampionPoints" .. suffix, eventId, function()
        CP.Refresh()
    end)
end

function CP.Init()
    CP.Refresh()
    RegisterEvent(EVENT_PLAYER_ACTIVATED, "Activated")
    RegisterEvent(EVENT_CHAMPION_POINT_UPDATE, "PointUpdate")
    RegisterEvent(EVENT_CHAMPION_PURCHASE_RESULT, "Purchase")
    RegisterEvent(EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, "Hotbars")
    RegisterEvent(EVENT_ACTION_SLOT_UPDATED, "Slot")
end

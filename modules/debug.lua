-- Salida tecnica opcional; el chat queda para mensajes funcionales cortos.
local ADDON_NAME = "EZOMetter"
local PLAYER_BUFF_CAPTURE_NAMESPACE = ADDON_NAME .. "_PlayerBuffCapture"
local PLAYER_BUFF_CAPTURE_MS = 15000
local PLAYER_BUFF_CAPTURE_PREFIX = "[U51BuffCapture]"
local PLAYER_BUFF_CAPTURE_MAX_ENTRIES = 1000
local PLAYER_BUFF_SNAPSHOT_FORMAT =
    "[U51BuffCapture] snapshot index=%s name=%s abilityId=%s begin=%s end=%s" ..
    " slot=%s stacks=%s icon=%s deprecatedBuffType=%s effectType=%s" ..
    " abilityType=%s statusEffectType=%s canClickOff=%s castByPlayer=%s"
local PLAYER_BUFF_EVENT_FORMAT =
    "[U51BuffCapture] event changeType=%s name=%s abilityId=%s begin=%s end=%s" ..
    " slot=%s stacks=%s icon=%s deprecatedBuffType=%s effectType=%s" ..
    " abilityType=%s statusEffectType=%s unitName=%s unitId=%s sourceType=%s"

local logger
local loggerUnavailable = false
local playerBuffCaptureToken = 0

local function ResetStoredPlayerBuffCapture()
    if not EZOMetter.sv then return end

    EZOMetter.sv.debugCapture = EZOMetter.sv.debugCapture or {}
    EZOMetter.sv.debugCapture.u51BuffCapture = {
        entries = {},
        truncated = false,
    }
end

local function StorePlayerBuffCapture(message)
    if not EZOMetter.sv or type(message) ~= "string" then return end
    if message:sub(1, #PLAYER_BUFF_CAPTURE_PREFIX) ~= PLAYER_BUFF_CAPTURE_PREFIX then return end

    EZOMetter.sv.debugCapture = EZOMetter.sv.debugCapture or {}
    local capture = EZOMetter.sv.debugCapture.u51BuffCapture
    if type(capture) ~= "table" then
        ResetStoredPlayerBuffCapture()
        capture = EZOMetter.sv.debugCapture.u51BuffCapture
    end

    capture.entries = capture.entries or {}
    if #capture.entries >= PLAYER_BUFF_CAPTURE_MAX_ENTRIES then
        capture.truncated = true
        return
    end

    capture.entries[#capture.entries + 1] = message
end

local function GetLogger()
    if loggerUnavailable then
        return nil
    end

    if logger then
        return logger
    end

    local lib = _G.LibDebugLogger
    if type(lib) ~= "function" and type(lib) ~= "table" then
        loggerUnavailable = true
        return nil
    end

    local ok, created = false, nil
    if type(lib) == "function" then
        ok, created = pcall(lib, ADDON_NAME)
    end
    if (not ok or created == nil) and type(lib) == "table" and type(lib.Create) == "function" then
        ok, created = pcall(function()
            return lib:Create(ADDON_NAME)
        end)
    end

    if ok and created then
        logger = created
        loggerUnavailable = false
        return logger
    end

    loggerUnavailable = true
    return nil
end

function EZOMetter.DebugLog(message)
    if not EZOMetter.sv or not EZOMetter.sv.general or EZOMetter.sv.general.debugMode ~= true then
        return
    end

    local text = tostring(message)
    StorePlayerBuffCapture(text)

    local log = GetLogger()
    if log and type(log.Debug) == "function" then
        pcall(function()
            log:Debug(text)
        end)
    end
end

local function IsDebugEnabled()
    return EZOMetter.sv
        and EZOMetter.sv.general
        and EZOMetter.sv.general.debugMode == true
end

local function Notify(stringId)
    if EZOMetter.Print and stringId then
        EZOMetter.Print(GetString(stringId))
    end
end

local function LogPlayerBuffSnapshot(stage)
    if type(GetNumBuffs) ~= "function" or type(GetUnitBuffInfo) ~= "function" then
        EZOMetter.DebugLog("[U51BuffCapture] snapshot unavailable: player buff API missing")
        return false
    end

    local buffCount = GetNumBuffs("player") or 0
    EZOMetter.DebugLog(string.format(
        "[U51BuffCapture] snapshot stage=%s count=%s",
        tostring(stage or "manual"),
        tostring(buffCount)
    ))

    for index = 1, buffCount do
        local buffName, beginTime, endTime, effectSlot, stackCount, iconFilename,
            deprecatedBuffType, effectType, abilityType, statusEffectType, abilityId,
            canClickOff, castByPlayer = GetUnitBuffInfo("player", index)

        EZOMetter.DebugLog(string.format(
            PLAYER_BUFF_SNAPSHOT_FORMAT,
            tostring(index),
            tostring(buffName or ""),
            tostring(abilityId),
            tostring(beginTime),
            tostring(endTime),
            tostring(effectSlot),
            tostring(stackCount),
            tostring(iconFilename or ""),
            tostring(deprecatedBuffType),
            tostring(effectType),
            tostring(abilityType),
            tostring(statusEffectType),
            tostring(canClickOff),
            tostring(castByPlayer)
        ))
    end

    return true
end


function EZOMetter.DebugScanPlayerBuffs()
    if not IsDebugEnabled() then
        Notify(EZOM_DEBUG_PLAYER_CAPTURE_DISABLED)
        return false
    end

    ResetStoredPlayerBuffCapture()
    local logged = LogPlayerBuffSnapshot("manual")
    if logged then
        Notify(EZOM_DEBUG_PLAYER_SCAN_DONE)
    end
    return logged
end


local function OnPlayerEffectChanged(
    _, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount,
    iconName, deprecatedBuffType, effectType, abilityType, statusEffectType,
    unitName, unitId, abilityId, sourceType
)
    if unitTag ~= "player" then return end

    EZOMetter.DebugLog(string.format(
        PLAYER_BUFF_EVENT_FORMAT,
        tostring(changeType),
        tostring(effectName or ""),
        tostring(abilityId),
        tostring(beginTime),
        tostring(endTime),
        tostring(effectSlot),
        tostring(stackCount),
        tostring(iconName or ""),
        tostring(deprecatedBuffType),
        tostring(effectType),
        tostring(abilityType),
        tostring(statusEffectType),
        tostring(unitName or ""),
        tostring(unitId),
        tostring(sourceType)
    ))
end


function EZOMetter.DebugCapturePlayerBuffs()
    if not IsDebugEnabled() then
        Notify(EZOM_DEBUG_PLAYER_CAPTURE_DISABLED)
        return false
    end
    ResetStoredPlayerBuffCapture()
    if not EVENT_MANAGER or not EVENT_EFFECT_CHANGED or type(zo_callLater) ~= "function" then
        EZOMetter.DebugLog("[U51BuffCapture] capture unavailable: event API missing")
        return false
    end

    playerBuffCaptureToken = playerBuffCaptureToken + 1
    local token = playerBuffCaptureToken
    EVENT_MANAGER:UnregisterForEvent(PLAYER_BUFF_CAPTURE_NAMESPACE, EVENT_EFFECT_CHANGED)
    EVENT_MANAGER:RegisterForEvent(
        PLAYER_BUFF_CAPTURE_NAMESPACE,
        EVENT_EFFECT_CHANGED,
        OnPlayerEffectChanged
    )
    if REGISTER_FILTER_UNIT_TAG then
        EVENT_MANAGER:AddFilterForEvent(
            PLAYER_BUFF_CAPTURE_NAMESPACE,
            EVENT_EFFECT_CHANGED,
            REGISTER_FILTER_UNIT_TAG,
            "player"
        )
    end

    EZOMetter.DebugLog(string.format("[U51BuffCapture] capture start durationMs=%s", PLAYER_BUFF_CAPTURE_MS))
    LogPlayerBuffSnapshot("start")
    Notify(EZOM_DEBUG_PLAYER_CAPTURE_STARTED)

    zo_callLater(function()
        if token ~= playerBuffCaptureToken then return end
        EVENT_MANAGER:UnregisterForEvent(PLAYER_BUFF_CAPTURE_NAMESPACE, EVENT_EFFECT_CHANGED)
        LogPlayerBuffSnapshot("end")
        EZOMetter.DebugLog("[U51BuffCapture] capture stop")
        Notify(EZOM_DEBUG_PLAYER_CAPTURE_FINISHED)
    end, PLAYER_BUFF_CAPTURE_MS)

    return true
end

function EZOMetter.GetDebugLogger()
    return GetLogger()
end

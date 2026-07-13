-- Salida tecnica opcional; el chat queda para mensajes funcionales cortos.
local ADDON_NAME = "EZOMetter"

local logger
local loggerUnavailable = false

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

    local log = GetLogger()
    if log and type(log.Debug) == "function" then
        pcall(function()
            log:Debug(tostring(message))
        end)
    end
end

function EZOMetter.GetDebugLogger()
    return GetLogger()
end

-- Salida tecnica opcional; el chat queda para mensajes funcionales cortos.
local ADDON_NAME = "EZOMetter"

function EZOMetter.DebugLog(message)
    if not EZOMetter.sv or not EZOMetter.sv.general or EZOMetter.sv.general.debugMode ~= true then
        return
    end

    if LibDebugLogger then
        local logger = LibDebugLogger(ADDON_NAME)
        if logger and logger.Debug then
            logger:Debug(tostring(message))
            return
        end
    end
end

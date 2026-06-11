-- Defaults y SavedVariables centralizados.
EZOMetter.savedVars = EZOMetter.savedVars or {}

function EZOMetter.savedVars.Init()
    local world = GetWorldName()
    local defaults = {
        general = {
            language = EZOMetter.GetDefaultLanguage(),
            debugMode = false,
        },
    }

    EZOMetter.sv = ZO_SavedVars:NewCharacterIdSettings("EZOMetter_Saved", 1, world, defaults)
end

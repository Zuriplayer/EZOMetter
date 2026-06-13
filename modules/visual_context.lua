-- Guard compartido para HUDs/overlays propios de EZOMetter.
EZOMetter_VisualContext = EZOMetter_VisualContext or {}

local VisualContext = EZOMetter_VisualContext
local ADDON_NAME = "EZOMetter"
local refreshCallbacks = {}
local sceneCallbackRegistered = false

function VisualContext.IsHudSceneShowing()
    if not SCENE_MANAGER then return false end

    local hudScene = SCENE_MANAGER:GetScene("hud")
    local hudUiScene = SCENE_MANAGER:GetScene("hudui")

    return (hudScene and hudScene:IsShowing()) or (hudUiScene and hudUiScene:IsShowing()) or false
end

function VisualContext.AddHudFragment(control)
    if not control or control.ezomHudFragment then return end
    if not ZO_SimpleSceneFragment or not HUD_SCENE or not HUD_UI_SCENE then return end

    local fragment = ZO_SimpleSceneFragment:New(control)
    if fragment and fragment.SetConditional then
        fragment:SetConditional(function()
            return VisualContext.IsHudSceneShowing()
        end)
    end

    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    control.ezomHudFragment = fragment
end

function VisualContext.RefreshFragments()
    local callbacks = refreshCallbacks
    for _, callback in ipairs(callbacks) do
        callback()
    end
end

function VisualContext.RegisterRefresh(callback)
    if type(callback) ~= "function" then return end
    table.insert(refreshCallbacks, callback)

    if sceneCallbackRegistered or not SCENE_MANAGER then return end
    sceneCallbackRegistered = true
    SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
        VisualContext.RefreshFragments()
    end)
end

function VisualContext.CanShowHud()
    return VisualContext.IsHudSceneShowing()
end

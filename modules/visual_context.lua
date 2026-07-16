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

    control:SetHidden(true)

    local fragment = ZO_SimpleSceneFragment:New(control)
    if fragment and fragment.SetConditional then
        fragment:SetConditional(function()
            return VisualContext.IsHudSceneShowing()
        end)
    end

    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
    control.ezomHudFragment = fragment
    control:SetHidden(true)
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

function VisualContext.IsHudUnlocked()
    return EZOMetter
        and type(EZOMetter.IsHudLayoutEditMode) == "function"
        and EZOMetter.IsHudLayoutEditMode()
end

function VisualContext.BindPrimaryDrag(control, canMove, onMoveStop)
    if not control or type(canMove) ~= "function" then return end

    local dragActive = false
    control:SetMovable(false)
    control:SetHandler("OnMouseDown", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or canMove() ~= true then
            return
        end
        dragActive = true
        control:SetMovable(true)
        control:StartMoving()
    end)
    control:SetHandler("OnMouseUp", function(_, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT or not dragActive then
            return
        end
        control:StopMovingOrResizing()
        dragActive = false
        control:SetMovable(false)
    end)
    control:SetHandler("OnMoveStop", function()
        dragActive = false
        control:SetMovable(false)
        if type(onMoveStop) == "function" then
            onMoveStop()
        end
    end)

    control.ezomPrimaryDragRefresh = function()
        if dragActive and canMove() ~= true then
            control:StopMovingOrResizing()
            dragActive = false
        end
        control:SetMovable(false)
    end
end

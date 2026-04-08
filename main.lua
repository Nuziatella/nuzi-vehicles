local api = require("api")

local function loadModule(name)
    local ok, mod = pcall(require, "nuzi-vehicles/" .. name)
    if ok then
        return mod
    end
    ok, mod = pcall(require, "nuzi-vehicles." .. name)
    if ok then
        return mod
    end
    return nil
end

local Constants = loadModule("constants")
local Shared = loadModule("shared")
local Controller = loadModule("controller")
local Ui = loadModule("ui")
local Adapter = loadModule("game_adapter")

local Addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Vehicles",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.0.0",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Boat compass"
}

local updateAccumMs = 0
local function noop()
end

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Controller ~= nil and Ui ~= nil and Adapter ~= nil
end

local function renderNow()
    if not modulesReady() then
        return
    end
    Ui.Render(Controller.BuildViewModel())
end

local function saveCurrentWindowPositions()
    if not modulesReady() or Ui.GetPositions == nil then
        return
    end
    local positions = Ui.GetPositions()
    local settings = Shared.EnsureSettings()

    settings.x = tonumber(positions.main_x) or settings.x
    settings.y = tonumber(positions.main_y) or settings.y
    settings.speed_x = tonumber(positions.speed_x) or settings.speed_x
    settings.speed_y = tonumber(positions.speed_y) or settings.speed_y
    settings.compass_x = tonumber(positions.compass_x) or settings.compass_x
    settings.compass_y = tonumber(positions.compass_y) or settings.compass_y
    settings.button_x = tonumber(positions.button_x) or settings.button_x
    settings.button_y = tonumber(positions.button_y) or settings.button_y
    Shared.SaveSettings()
end

local function savePosition(kind, x, y)
    local settings = Shared.EnsureSettings()
    if kind == "speed" then
        settings.speed_x = tonumber(x) or settings.speed_x
        settings.speed_y = tonumber(y) or settings.speed_y
    elseif kind == "compass" then
        settings.compass_x = tonumber(x) or settings.compass_x
        settings.compass_y = tonumber(y) or settings.compass_y
    elseif kind == "button" then
        settings.button_x = tonumber(x) or settings.button_x
        settings.button_y = tonumber(y) or settings.button_y
    else
        settings.x = tonumber(x) or settings.x
        settings.y = tonumber(y) or settings.y
    end
    Shared.SaveSettings()
end

local function toggleSpeed()
    local settings = Shared.EnsureSettings()
    settings.show_speed_window = not (settings.show_speed_window and true or false)
    Shared.SaveSettings()
    renderNow()
end

local function toggleCompass()
    local settings = Shared.EnsureSettings()
    settings.show_compass_window = not (settings.show_compass_window and true or false)
    Shared.SaveSettings()
    renderNow()
end

local function toggleMain()
    local settings = Shared.EnsureSettings()
    settings.show_main_window = not (settings.show_main_window and true or false)
    Shared.SaveSettings()
    renderNow()
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end
    updateAccumMs = updateAccumMs + Shared.NormalizeDeltaMs(dt)
    if updateAccumMs < Constants.UPDATE_INTERVAL_MS then
        return
    end
    updateAccumMs = 0
    Controller.Update()
    renderNow()
end

local function buildActions()
    return {
        previous_profile = function()
            Controller.SelectPreviousProfile()
            Controller.Update()
            renderNow()
        end,
        next_profile = function()
            Controller.SelectNextProfile()
            Controller.Update()
            renderNow()
        end,
        toggle_main = toggleMain,
        toggle_speed = toggleSpeed,
        toggle_compass = toggleCompass,
        save_position = savePosition
    }
end

local function onUiReloaded()
    if not modulesReady() then
        return
    end
    saveCurrentWindowPositions()
    Ui.Destroy()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Controller.Update()
    renderNow()
end

local function onLoad()
    if not modulesReady() then
        return
    end
    Shared.LoadSettings()
    Controller.Initialize()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Controller.Update()
    renderNow()

    api.On("UPDATE", onUpdate)
    api.On("UI_RELOADED", onUiReloaded)
end

local function onUnload()
    api.On("UPDATE", noop)
    api.On("UI_RELOADED", noop)
    if Ui ~= nil then
        saveCurrentWindowPositions()
        Ui.Destroy()
    end
end

Addon.OnLoad = onLoad
Addon.OnUnload = onUnload

return Addon

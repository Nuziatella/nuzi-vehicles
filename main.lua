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
local lastRenderSignature = nil
local function noop()
end

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Controller ~= nil and Ui ~= nil and Adapter ~= nil
end

local function renderNow()
    if not modulesReady() then
        return
    end
    local viewModel = Controller.BuildViewModel()
    local bands = {}
    for index, band in ipairs(viewModel.compass_bands or {}) do
        bands[index] = string.format(
            "%s:%s:%s",
            tostring(band.text or ""),
            band.is_current and "1" or "0",
            band.is_preferred and "1" or "0"
        )
    end
    local signature = table.concat({
        viewModel.enabled and "1" or "0",
        tostring(viewModel.selected_profile_label or ""),
        tostring(viewModel.world_heading_text or ""),
        tostring(viewModel.travel_direction_text or ""),
        string.format("%.2f", tonumber(viewModel.current_speed) or 0),
        string.format("%.2f", tonumber(viewModel.current_turn_speed) or 0),
        tostring(viewModel.speed_source or ""),
        tostring(viewModel.heading_source or ""),
        tostring(viewModel.preferred_axis_text or ""),
        tostring(viewModel.current_axis_text or ""),
        tostring(viewModel.axis_state_label or ""),
        tostring(viewModel.axis_turn_hint or ""),
        viewModel.axis_boost_active and "1" or "0",
        string.format("%.1f", tonumber(viewModel.estimated_efficiency_pct) or 0),
        string.format("%.1f", tonumber(viewModel.estimated_penalty_pct) or 0),
        string.format("%.1f", tonumber(viewModel.deviation_deg) or 0),
        string.format("%.1f", tonumber(viewModel.speed_bar_max) or 0),
        string.format("%.0f", tonumber(viewModel.toggle_button_size) or 0),
        tostring(viewModel.arrow_text or ""),
        viewModel.show_main_window and "1" or "0",
        viewModel.show_speed_window and "1" or "0",
        viewModel.show_compass_window and "1" or "0",
        viewModel.show_helm_window and "1" or "0",
        table.concat(bands, "|")
    }, "||")
    if signature == lastRenderSignature then
        return
    end
    Ui.Render(viewModel)
    lastRenderSignature = signature
end

local function savePosition(kind, x, y)
    local settings = Shared.EnsureSettings()
    if kind == "speed" then
        settings.speed_x = tonumber(x) or settings.speed_x
        settings.speed_y = tonumber(y) or settings.speed_y
    elseif kind == "compass" then
        settings.compass_x = tonumber(x) or settings.compass_x
        settings.compass_y = tonumber(y) or settings.compass_y
    elseif kind == "helm" then
        settings.helm_x = tonumber(x) or settings.helm_x
        settings.helm_y = tonumber(y) or settings.helm_y
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

local function toggleHelm()
    local settings = Shared.EnsureSettings()
    settings.show_helm_window = not (settings.show_helm_window and true or false)
    Shared.SaveSettings()
    renderNow()
end

local function toggleMain()
    local settings = Shared.EnsureSettings()
    settings.show_main_window = not (settings.show_main_window and true or false)
    Shared.SaveSettings()
    renderNow()
end

local function setButtonSize(value)
    local settings = Shared.EnsureSettings()
    local numeric = math.floor((tonumber(value) or settings.button_size or 48) + 0.5)
    numeric = math.max(36, math.min(96, numeric))
    if settings.button_size == numeric then
        return
    end
    settings.button_size = numeric
    Shared.SaveSettings()
    lastRenderSignature = nil
    renderNow()
end

local function toggleEnabled()
    local settings = Shared.EnsureSettings()
    settings.enabled = not (settings.enabled and true or false)
    Shared.SaveSettings()
    if settings.enabled then
        Controller.Update()
    end
    lastRenderSignature = nil
    renderNow()
end

local function onUpdate(dt)
    if not modulesReady() then
        return
    end
    local settings = Shared.EnsureSettings()
    local intervalMs = Constants.UPDATE_INTERVAL_MS
    if not settings.enabled then
        intervalMs = 750
    elseif not settings.show_main_window and not settings.show_speed_window and not settings.show_compass_window and not settings.show_helm_window then
        intervalMs = 300
    elseif Controller.IsTelemetryActive ~= nil and not Controller.IsTelemetryActive() then
        intervalMs = 220
    end
    updateAccumMs = updateAccumMs + Shared.NormalizeDeltaMs(dt)
    if updateAccumMs < intervalMs then
        return
    end
    updateAccumMs = 0
    if not settings.enabled then
        return
    end
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
        toggle_enabled = toggleEnabled,
        toggle_main = toggleMain,
        toggle_speed = toggleSpeed,
        toggle_compass = toggleCompass,
        toggle_helm = toggleHelm,
        set_button_size = setButtonSize,
        save_position = savePosition
    }
end

local function onUiReloaded()
    if not modulesReady() then
        return
    end
    Ui.Destroy()
    lastRenderSignature = nil
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
    lastRenderSignature = nil
    renderNow()

    api.On("UPDATE", onUpdate)
    api.On("UI_RELOADED", onUiReloaded)
end

local function onUnload()
    api.On("UPDATE", noop)
    api.On("UI_RELOADED", noop)
    if Ui ~= nil then
        Ui.Destroy()
    end
    lastRenderSignature = nil
end

Addon.OnLoad = onLoad
Addon.OnUnload = onUnload

return Addon

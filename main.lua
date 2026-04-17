local api = require("api")
local Core = api._NuziCore or require("nuzi-core/core")

local Actions = Core.Actions
local Events = Core.Events
local Log = Core.Log
local Render = Core.Render
local Require = Core.Require
local Scheduler = Core.Scheduler

local bootstrapLogger = Log.Create("Nuzi Vehicles")
local moduleErrors = {}

local function appendModuleErrors(name, errors)
    if type(errors) ~= "table" or #errors == 0 then
        moduleErrors[#moduleErrors + 1] = string.format("%s: unknown load failure", tostring(name))
        return
    end
    moduleErrors[#moduleErrors + 1] = string.format(
        "%s: %s",
        tostring(name),
        Require.DescribeErrors(errors)
    )
end

local Constants, _, constantErrors = Require.Addon("nuzi-vehicles", "constants")
if Constants == nil then
    appendModuleErrors("constants", constantErrors)
end

local logger = Log.Create(Constants ~= nil and Constants.ADDON_NAME or "Nuzi Vehicles")
local modules = nil
local failures = nil
if Constants ~= nil then
    modules, failures = Require.AddonSet("nuzi-vehicles", {
        "shared",
        "controller",
        "ui",
        "game_adapter"
    })
else
    modules = {}
    failures = {}
end

for name, failure in pairs(failures or {}) do
    appendModuleErrors(name, failure.errors)
end

local Shared = modules.shared
local Controller = modules.controller
local Ui = modules.ui
local Adapter = modules.game_adapter

local Addon = {
    name = Constants ~= nil and Constants.ADDON_NAME or "Nuzi Vehicles",
    author = Constants ~= nil and Constants.ADDON_AUTHOR or "Nuzi",
    version = Constants ~= nil and Constants.ADDON_VERSION or "1.0.9",
    desc = Constants ~= nil and Constants.ADDON_DESC or "Boat compass"
}

local positionMappings = {
    default = { x = "x", y = "y" },
    main = { x = "x", y = "y" },
    speed = { x = "speed_x", y = "speed_y" },
    compass = { x = "compass_x", y = "compass_y" },
    helm = { x = "helm_x", y = "helm_y" },
    button = { x = "button_x", y = "button_y" }
}

local renderGate = Render.CreateSignatureGate()
local updateTicker = Scheduler.CreateTicker({
    interval_ms = Constants ~= nil and Constants.UPDATE_INTERVAL_MS or 120,
    max_elapsed_ms = (Constants ~= nil and Constants.UPDATE_INTERVAL_MS or 120) * 6
})
local events = Events.Create({
    logger = logger
})

local function modulesReady()
    return Constants ~= nil and Shared ~= nil and Controller ~= nil and Ui ~= nil and Adapter ~= nil
end

local function logModuleErrors()
    if #moduleErrors == 0 then
        return
    end
    for _, detail in ipairs(moduleErrors) do
        logger:Err("Module load error: " .. tostring(detail))
    end
end

local function renderNow(viewModel)
    if not modulesReady() then
        return
    end

    viewModel = type(viewModel) == "table" and viewModel or Controller.BuildViewModel()

    local bandParts = {}
    for index, band in ipairs(viewModel.compass_bands or {}) do
        bandParts[index] = string.format(
            "%s:%s:%s",
            tostring(band.text or ""),
            band.is_current and "1" or "0",
            band.is_preferred and "1" or "0"
        )
    end

    local signature = Render.BuildSignature({
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
        string.format("%.1f", tonumber(viewModel.base_speed) or 0),
        string.format("%.0f", tonumber(viewModel.toggle_button_size) or 0),
        tostring(viewModel.arrow_text or ""),
        viewModel.show_main_window and "1" or "0",
        viewModel.show_speed_window and "1" or "0",
        viewModel.show_compass_window and "1" or "0",
        viewModel.show_helm_window and "1" or "0",
        table.concat(bandParts, "|")
    })
    if not renderGate:ShouldRender(signature) then
        return
    end

    Ui.Render(viewModel)
end

local function buildActions()
    if not modulesReady() then
        return {}
    end

    local getSettings = function()
        return Shared.EnsureSettings()
    end
    local saveSettings = function()
        return Shared.SaveSettings()
    end
    local rerender = function()
        renderNow()
    end

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
        toggle_enabled = Actions.CreateToggle({
            get_settings = getSettings,
            key = "enabled",
            save = saveSettings,
            after = function(settings)
                if settings.enabled then
                    Controller.Update()
                end
                renderNow()
            end
        }),
        toggle_main = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_main_window",
            save = saveSettings,
            after = rerender
        }),
        toggle_speed = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_speed_window",
            save = saveSettings,
            after = rerender
        }),
        toggle_compass = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_compass_window",
            save = saveSettings,
            after = rerender
        }),
        toggle_helm = Actions.CreateToggle({
            get_settings = getSettings,
            key = "show_helm_window",
            save = saveSettings,
            after = rerender
        }),
        set_button_size = Actions.CreateClampedNumberSetter({
            get_settings = getSettings,
            key = "button_size",
            min = 36,
            max = 96,
            save = saveSettings,
            after = rerender,
            skip_if_unchanged = true
        }),
        save_position = Actions.CreateNamedPositionSaver({
            get_settings = getSettings,
            save_settings = saveSettings,
            mappings = positionMappings
        })
    }
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

    local shouldRun = updateTicker:Advance(dt, intervalMs)
    if not shouldRun then
        return
    end

    if not settings.enabled then
        return
    end

    Controller.Update()
    renderNow()
end

local function onUiReloaded()
    if not modulesReady() then
        return
    end

    updateTicker:Reset()
    renderGate:Reset()
    Ui.Destroy()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Controller.Update()
    renderNow()
end

local function onLoad()
    if not modulesReady() then
        logModuleErrors()
        bootstrapLogger:Err("Failed to load one or more modules.")
        return
    end

    logModuleErrors()
    Shared.LoadSettings()
    Controller.Initialize()
    updateTicker:Reset()
    renderGate:Reset()
    Ui.Init(buildActions())
    Ui.ApplyPositions(Shared.EnsureSettings())
    Controller.Update()
    renderNow()

    events:OnSafe("UPDATE", "UPDATE", onUpdate)
    events:OnSafe("UI_RELOADED", "UI_RELOADED", onUiReloaded)
    logger:Info("Loaded v" .. tostring(Addon.version))
end

local function onUnload()
    events:ClearAll()
    updateTicker:Reset()
    renderGate:Reset()
    if Ui ~= nil then
        Ui.Destroy()
    end
end

Addon.OnLoad = onLoad
Addon.OnUnload = onUnload

return Addon

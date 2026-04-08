local api = require("api")
local Constants = require("nuzi-vehicles/constants")

local Ui = {
    window = nil,
    speed_window = nil,
    compass_window = nil,
    toggle_window = nil,
    actions = nil,
    labels = {},
    buttons = {},
    compass_labels = {},
    speed = {},
    compass = {}
}

local function safeCall(fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return nil
end

local function safeShow(widget, visible)
    if widget ~= nil and widget.Show ~= nil then
        pcall(function()
            widget:Show(visible and true or false)
        end)
    end
end

local function safeSetText(widget, text)
    if widget ~= nil and widget.SetText ~= nil then
        pcall(function()
            widget:SetText(tostring(text or ""))
        end)
    end
end

local function safeSetColor(widget, color)
    if widget == nil or widget.style == nil or widget.style.SetColor == nil or type(color) ~= "table" then
        return
    end
    pcall(function()
        widget.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
    end)
end

local function safeSetExtent(widget, width, height)
    if widget ~= nil and widget.SetExtent ~= nil then
        pcall(function()
            widget:SetExtent(width, height)
        end)
    end
end

local function safeSetBarValue(widget, value)
    if widget ~= nil and widget.SetValue ~= nil then
        pcall(function()
            widget:SetValue(value)
        end)
    end
end

local function safeSetBarMinMax(widget, minValue, maxValue)
    if widget ~= nil and widget.SetMinMaxValues ~= nil then
        pcall(function()
            widget:SetMinMaxValues(minValue, maxValue)
        end)
    end
end

local function createWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    return safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
end

local function createBackground(window)
    if window == nil or window.CreateNinePartDrawable == nil then
        return nil
    end
    local background = safeCall(function()
        return window:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
    end)
    if background ~= nil then
        safeCall(function()
            background:SetTextureInfo("bg_quest")
            background:SetColor(0, 0, 0, 0.8)
            background:AddAnchor("TOPLEFT", window, 0, 0)
            background:AddAnchor("BOTTOMRIGHT", window, 0, 0)
        end)
    end
    return background
end

local function getAlignLeft()
    if ALIGN_LEFT ~= nil then
        return ALIGN_LEFT
    end
    if ALIGN ~= nil then
        return ALIGN.LEFT
    end
    return nil
end

local function getAlignCenter()
    if ALIGN_CENTER ~= nil then
        return ALIGN_CENTER
    end
    if ALIGN ~= nil then
        return ALIGN.CENTER
    end
    return nil
end

local function createLabel(parent, id, x, y, width, height, fontSize, color, align)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local label = safeCall(function()
        return parent:CreateChildWidget("label", id, 0, true)
    end)
    if label == nil then
        return nil
    end
    safeCall(function()
        label:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetExtent(label, width, height)
    if label.style ~= nil then
        safeCall(function()
            label.style:SetFontSize(fontSize)
        end)
        if align ~= nil then
            safeCall(function()
                label.style:SetAlign(align)
            end)
        end
    end
    safeSetColor(label, color)
    safeShow(label, true)
    return label
end

local function createButton(id, parent, text, x, y, width, height, onClick)
    if api.Interface == nil or api.Interface.CreateWidget == nil then
        return nil
    end
    local button = safeCall(function()
        return api.Interface:CreateWidget("button", id, parent)
    end)
    if button == nil then
        return nil
    end
    safeCall(function()
        button:AddAnchor("TOPLEFT", x, y)
    end)
    safeSetText(button, text)
    if BUTTON_BASIC ~= nil and BUTTON_BASIC.DEFAULT ~= nil and api.Interface.ApplyButtonSkin ~= nil then
        safeCall(function()
            api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
        end)
    end
    safeSetExtent(button, width, height)
    if onClick ~= nil and button.SetHandler ~= nil then
        button:SetHandler("OnClick", onClick)
    end
    safeShow(button, true)
    return button
end

local function createEmptyWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    return safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
end

local function createStatusBar(parent, id, x, y, width, height)
    if api.Interface == nil or api.Interface.CreateStatusBar == nil then
        return nil
    end
    local bar = safeCall(function()
        return api.Interface:CreateStatusBar(id, parent, "item_evolving_material")
    end)
    if bar == nil then
        return nil
    end
    safeCall(function()
        bar:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetExtent(bar, width, height)
    safeCall(function()
        bar:SetBarColor({ ConvertColor(92), ConvertColor(170), ConvertColor(212), 1 })
    end)
    safeSetBarMinMax(bar, 0, Constants.DEFAULT_SPEED_BAR_MAX)
    if bar.bg ~= nil and bar.bg.SetColor ~= nil then
        safeCall(function()
            bar.bg:SetColor(ConvertColor(16), ConvertColor(30), ConvertColor(45), 0.45)
        end)
    end
    return bar
end

local function attachDrag(window, dragTarget, key)
    if window == nil or dragTarget == nil or dragTarget.SetHandler == nil then
        return
    end
    local function onDragStart()
        if api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil and not api.Input:IsShiftKeyDown() then
            return
        end
        if window.StartMoving ~= nil then
            window:StartMoving()
        end
        if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            api.Cursor:ClearCursor()
        end
        if api.Cursor ~= nil and api.Cursor.SetCursorImage ~= nil then
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
    end
    local function onDragStop()
        if window.StopMovingOrSizing ~= nil then
            window:StopMovingOrSizing()
        end
        if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
            api.Cursor:ClearCursor()
        end
        if window.GetOffset ~= nil and Ui.actions ~= nil and Ui.actions.save_position ~= nil then
            local x, y = window:GetOffset()
            if window.RemoveAllAnchors ~= nil and window.AddAnchor ~= nil then
                safeCall(function()
                    window:RemoveAllAnchors()
                    window:AddAnchor("TOPLEFT", "UIParent", tonumber(x) or 0, tonumber(y) or 0)
                end)
            end
            Ui.actions.save_position(key, x, y)
        end
    end
    if window.EnableDrag ~= nil then
        safeCall(function()
            window:EnableDrag(true)
        end)
    end
    if window.RegisterForDrag ~= nil then
        safeCall(function()
            window:RegisterForDrag("LeftButton")
        end)
    end
    if dragTarget.EnableDrag ~= nil then
        safeCall(function()
            dragTarget:EnableDrag(true)
        end)
    end
    if dragTarget.RegisterForDrag ~= nil then
        safeCall(function()
            dragTarget:RegisterForDrag("LeftButton")
        end)
    end
    window:SetHandler("OnDragStart", onDragStart)
    window:SetHandler("OnDragStop", onDragStop)
    dragTarget:SetHandler("OnDragStart", onDragStart)
    dragTarget:SetHandler("OnDragStop", onDragStop)
end

local function attachDragTargets(window, key, widgets)
    for _, widget in ipairs(widgets or {}) do
        if widget ~= nil then
            attachDrag(window, widget, key)
        end
    end
end

local function createToggleWindow()
    local window = createEmptyWindow(Constants.TOGGLE_WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 96, 28)
    local dragBar = createLabel(window, "NuziVehiclesToggleDragBar", 0, 0, 96, 28, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "button")
    Ui.buttons.toggle = createButton("NuziVehiclesToggleButton", window, "Nuzi Vehicle", 0, 0, 96, 28, function()
        if Ui.actions ~= nil and Ui.actions.toggle_main ~= nil then
            Ui.actions.toggle_main()
        end
    end)
    attachDragTargets(window, "button", { Ui.buttons.toggle })
    return window
end

local function createMainWindow()
    local window = createWindow(Constants.WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 390, 172)
    createBackground(window)
    local dragBar = createLabel(window, "NuziVehiclesDragBar", 0, 0, 390, 20, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "main")

    Ui.labels.title = createLabel(window, "NuziVehiclesTitle", 12, 6, 180, 18, 14, { 1, 1, 1, 1 }, getAlignLeft())
    Ui.labels.profile = createLabel(window, "NuziVehiclesProfile", 12, 28, 362, 18, 13, { 0.9, 0.94, 1, 1 }, getAlignLeft())
    Ui.labels.heading = createLabel(window, "NuziVehiclesHeading", 12, 50, 362, 18, 12, { 0.92, 0.86, 0.58, 1 }, getAlignLeft())
    Ui.labels.speed = createLabel(window, "NuziVehiclesSpeed", 12, 72, 362, 18, 12, { 0.95, 0.95, 0.95, 1 }, getAlignLeft())
    Ui.labels.base = createLabel(window, "NuziVehiclesBase", 12, 94, 362, 18, 12, { 0.84, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.labels.estimate = createLabel(window, "NuziVehiclesEstimate", 12, 116, 362, 18, 12, { 0.84, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.labels.sector = createLabel(window, "NuziVehiclesSector", 12, 138, 362, 18, 12, { 0.95, 0.88, 0.58, 1 }, getAlignLeft())

    Ui.buttons.prev = createButton("NuziVehiclesPrev", window, "<", 258, 24, 34, 24, function()
        if Ui.actions ~= nil and Ui.actions.previous_profile ~= nil then
            Ui.actions.previous_profile()
        end
    end)
    Ui.buttons.next = createButton("NuziVehiclesNext", window, ">", 298, 24, 34, 24, function()
        if Ui.actions ~= nil and Ui.actions.next_profile ~= nil then
            Ui.actions.next_profile()
        end
    end)
    Ui.buttons.speed_toggle = createButton("NuziVehiclesSpeedToggle", window, "Speed HUD", 250, 66, 124, 24, function()
        if Ui.actions ~= nil and Ui.actions.toggle_speed ~= nil then
            Ui.actions.toggle_speed()
        end
    end)
    Ui.buttons.compass_toggle = createButton("NuziVehiclesCompassToggle", window, "Compass", 250, 98, 124, 24, function()
        if Ui.actions ~= nil and Ui.actions.toggle_compass ~= nil then
            Ui.actions.toggle_compass()
        end
    end)

    attachDragTargets(window, "main", {
        Ui.labels.title,
        Ui.labels.profile,
        Ui.labels.heading,
        Ui.labels.speed,
        Ui.labels.base,
        Ui.labels.estimate,
        Ui.labels.sector,
        Ui.buttons.prev,
        Ui.buttons.next,
        Ui.buttons.speed_toggle,
        Ui.buttons.compass_toggle
    })

    return window
end

local function createSpeedWindow()
    local window = createWindow(Constants.SPEED_WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 280, 66)
    createBackground(window)
    local dragBar = createLabel(window, "NuziVehiclesSpeedDragBar", 0, 0, 280, 20, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "speed")

    Ui.speed.title = createLabel(window, "NuziVehiclesSpeedTitle", 10, 6, 140, 16, 13, { 1, 1, 1, 1 }, getAlignLeft())
    Ui.speed.close = createButton("NuziVehiclesSpeedClose", window, "X", 248, 4, 22, 20, function()
        if Ui.actions ~= nil and Ui.actions.toggle_speed ~= nil then
            Ui.actions.toggle_speed()
        end
    end)
    Ui.speed.value = createLabel(window, "NuziVehiclesSpeedValue", 10, 24, 100, 18, 14, { 0.95, 0.95, 0.95, 1 }, getAlignLeft())
    Ui.speed.modifier = createLabel(window, "NuziVehiclesSpeedModifier", 180, 24, 86, 18, 12, { 0.95, 0.88, 0.58, 1 }, getAlignCenter())
    Ui.speed.bar = createStatusBar(window, "NuziVehiclesSpeedBar", 10, 48, 260, 10)
    attachDragTargets(window, "speed", {
        Ui.speed.title,
        Ui.speed.close,
        Ui.speed.value,
        Ui.speed.modifier,
        Ui.speed.bar
    })
    return window
end

local function createCompassWindow()
    local window = createWindow(Constants.COMPASS_WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 250, 246)
    createBackground(window)
    local dragBar = createLabel(window, "NuziVehiclesCompassDragBar", 0, 0, 250, 20, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "compass")

    Ui.compass.title = createLabel(window, "NuziVehiclesCompassTitle", 12, 6, 120, 16, 13, { 1, 1, 1, 1 }, getAlignLeft())
    Ui.compass.close = createButton("NuziVehiclesCompassClose", window, "X", 218, 4, 22, 20, function()
        if Ui.actions ~= nil and Ui.actions.toggle_compass ~= nil then
            Ui.actions.toggle_compass()
        end
    end)
    Ui.compass.heading = createLabel(window, "NuziVehiclesCompassHeading", 12, 26, 226, 14, 12, { 0.92, 0.86, 0.58, 1 }, getAlignLeft())
    Ui.compass.travel = createLabel(window, "NuziVehiclesCompassTravel", 12, 42, 226, 14, 12, { 0.82, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.compass.arrow = createLabel(window, "NuziVehiclesCompassArrow", 88, 94, 74, 44, 34, { 1, 0.25, 0.25, 1 }, getAlignCenter())
    Ui.compass.axis = createLabel(window, "NuziVehiclesCompassAxis", 12, 204, 226, 14, 11, { 0.72, 0.8, 0.86, 1 }, getAlignLeft())
    Ui.compass.efficiency = createLabel(window, "NuziVehiclesCompassEfficiency", 12, 220, 226, 14, 11, { 0.95, 0.88, 0.58, 1 }, getAlignLeft())

    local positions = {
        { 102, 54 }, { 160, 76 }, { 186, 118 }, { 160, 160 },
        { 102, 180 }, { 44, 160 }, { 18, 118 }, { 44, 76 }
    }
    for index = 1, 8 do
        Ui.compass_labels[index] = createLabel(
            window,
            "NuziVehiclesCompassSector" .. tostring(index),
            positions[index][1],
            positions[index][2],
            52,
            18,
            11,
            { 0.82, 0.86, 0.92, 1 },
            getAlignCenter()
        )
    end
    attachDragTargets(window, "compass", {
        Ui.compass.title,
        Ui.compass.close,
        Ui.compass.heading,
        Ui.compass.travel,
        Ui.compass.arrow,
        Ui.compass.axis,
        Ui.compass.efficiency,
        Ui.compass_labels[1],
        Ui.compass_labels[2],
        Ui.compass_labels[3],
        Ui.compass_labels[4],
        Ui.compass_labels[5],
        Ui.compass_labels[6],
        Ui.compass_labels[7],
        Ui.compass_labels[8]
    })
    return window
end

function Ui.Init(actions)
    Ui.actions = actions
    Ui.toggle_window = createToggleWindow()
    Ui.window = createMainWindow()
    Ui.speed_window = createSpeedWindow()
    Ui.compass_window = createCompassWindow()
    safeShow(Ui.toggle_window, true)
    safeShow(Ui.window, true)
    safeShow(Ui.speed_window, true)
    safeShow(Ui.compass_window, true)
end

function Ui.Destroy()
    for _, window in ipairs({ Ui.window, Ui.speed_window, Ui.compass_window, Ui.toggle_window }) do
        if window ~= nil then
            safeShow(window, false)
            if window.Destroy ~= nil then
                safeCall(function()
                    window:Destroy()
                end)
            end
        end
    end
    Ui.window = nil
    Ui.speed_window = nil
    Ui.compass_window = nil
    Ui.toggle_window = nil
    Ui.actions = nil
    Ui.labels = {}
    Ui.buttons = {}
    Ui.compass_labels = {}
    Ui.speed = {}
    Ui.compass = {}
end

function Ui.ApplyPositions(settings)
    settings = settings or {}
    if Ui.window ~= nil and Ui.window.RemoveAllAnchors ~= nil and Ui.window.AddAnchor ~= nil then
        safeCall(function()
            Ui.window:RemoveAllAnchors()
            Ui.window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.x) or 260, tonumber(settings.y) or 260)
        end)
    end
    if Ui.speed_window ~= nil and Ui.speed_window.RemoveAllAnchors ~= nil and Ui.speed_window.AddAnchor ~= nil then
        safeCall(function()
            Ui.speed_window:RemoveAllAnchors()
            Ui.speed_window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.speed_x) or 260, tonumber(settings.speed_y) or 170)
        end)
    end
    if Ui.compass_window ~= nil and Ui.compass_window.RemoveAllAnchors ~= nil and Ui.compass_window.AddAnchor ~= nil then
        safeCall(function()
            Ui.compass_window:RemoveAllAnchors()
            Ui.compass_window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.compass_x) or 560, tonumber(settings.compass_y) or 170)
        end)
    end
    if Ui.toggle_window ~= nil and Ui.toggle_window.RemoveAllAnchors ~= nil and Ui.toggle_window.AddAnchor ~= nil then
        safeCall(function()
            Ui.toggle_window:RemoveAllAnchors()
            Ui.toggle_window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.button_x) or 40, tonumber(settings.button_y) or 220)
        end)
    end
end

function Ui.GetPositions()
    local positions = {}
    local function readOffset(window)
        if window ~= nil and window.GetOffset ~= nil then
            local x, y = safeCall(function()
                return window:GetOffset()
            end)
            return tonumber(x), tonumber(y)
        end
        return nil, nil
    end

    positions.main_x, positions.main_y = readOffset(Ui.window)
    positions.speed_x, positions.speed_y = readOffset(Ui.speed_window)
    positions.compass_x, positions.compass_y = readOffset(Ui.compass_window)
    positions.button_x, positions.button_y = readOffset(Ui.toggle_window)
    return positions
end

function Ui.Render(viewModel)
    if type(viewModel) ~= "table" then
        return
    end

    safeShow(Ui.window, viewModel.show_main_window and true or false)
    if Ui.toggle_window ~= nil then
        safeShow(Ui.toggle_window, true)
        if Ui.buttons.toggle ~= nil then
            safeSetText(Ui.buttons.toggle, viewModel.show_main_window and "Hide NV" or "Show NV")
        end
    end

    if viewModel.show_main_window then
        safeSetText(Ui.labels.title, Constants.ADDON_NAME)
        safeSetText(
            Ui.labels.profile,
            string.format(
                "Boat: %s | Source: %s",
                tostring(viewModel.selected_profile_label or ""),
                tostring(viewModel.speed_source or "Idle")
            )
        )
        safeSetText(Ui.labels.heading, "World Heading: " .. tostring(viewModel.world_heading_text or "--"))
        safeSetText(
            Ui.labels.speed,
            string.format("Current Speed: %.1f m/s", tonumber(viewModel.current_speed) or 0)
        )
        safeSetText(Ui.labels.base, "Travel Direction: " .. tostring(viewModel.travel_direction_text or "--"))
        safeSetText(
            Ui.labels.estimate,
            string.format(
                "Preferred Axis: %s | Current Axis: %s",
                tostring(viewModel.preferred_axis_text or "Unknown"),
                tostring(viewModel.current_axis_text or "Unknown")
            )
        )
        safeSetText(
            Ui.labels.sector,
            string.format(
                "Efficiency: %.0f%% | Penalty: %+.0f%% | Deviation: %.0f deg",
                tonumber(viewModel.estimated_efficiency_pct) or 0,
                tonumber(viewModel.estimated_penalty_pct) or 0,
                tonumber(viewModel.deviation_deg) or 0
            )
        )
        safeSetText(Ui.buttons.speed_toggle, viewModel.show_speed_window and "Hide Speed" or "Show Speed")
        safeSetText(Ui.buttons.compass_toggle, viewModel.show_compass_window and "Hide Compass" or "Show Compass")
    end

    safeShow(Ui.speed_window, viewModel.show_speed_window and true or false)
    if viewModel.show_speed_window then
        safeSetText(Ui.speed.title, "Travel Speed")
        safeSetText(Ui.speed.value, string.format("%.1f m/s", tonumber(viewModel.current_speed) or 0))
        safeSetText(Ui.speed.modifier, tostring(viewModel.speed_source or "Idle"))
        safeSetBarMinMax(Ui.speed.bar, 0, tonumber(viewModel.speed_bar_max) or Constants.DEFAULT_SPEED_BAR_MAX)
        safeSetBarValue(Ui.speed.bar, math.abs(tonumber(viewModel.current_speed) or 0))
    end

    safeShow(Ui.compass_window, viewModel.show_compass_window and true or false)
    if viewModel.show_compass_window then
        safeSetText(Ui.compass.title, "Nautical Compass")
        safeSetText(Ui.compass.heading, "Heading: " .. tostring(viewModel.world_heading_text or "--"))
        safeSetText(Ui.compass.travel, "Travel: " .. tostring(viewModel.travel_direction_text or "--"))
        safeSetText(Ui.compass.arrow, tostring(viewModel.arrow_text or "^"))
        safeSetColor(Ui.compass.arrow, viewModel.arrow_color or { 1, 0.25, 0.25, 1 })
        safeSetText(
            Ui.compass.axis,
            string.format(
                "Preferred: %s | Current: %s",
                tostring(viewModel.preferred_axis_text or "Unknown"),
                tostring(viewModel.current_axis_text or "Unknown")
            )
        )
        safeSetText(
            Ui.compass.efficiency,
            string.format(
                "%s | Eff %.0f%% | Pen %+.0f%% | Dev %.0f deg",
                tostring(viewModel.axis_state_label or "Unknown"),
                tonumber(viewModel.estimated_efficiency_pct) or 0,
                tonumber(viewModel.estimated_penalty_pct) or 0,
                tonumber(viewModel.deviation_deg) or 0
            )
        )
        for index = 1, #Ui.compass_labels do
            local label = Ui.compass_labels[index]
            local band = (viewModel.compass_bands or {})[index]
            if label ~= nil then
                if band ~= nil then
                    safeSetText(label, band.text)
                    if band.is_current and band.is_preferred then
                        safeSetColor(label, { 0.55, 1, 0.45, 1 })
                    elseif band.is_current then
                        safeSetColor(label, { 0.3, 1, 0.52, 1 })
                    elseif band.is_preferred then
                        safeSetColor(label, { 1, 0.86, 0.58, 1 })
                    else
                        safeSetColor(label, { 0.82, 0.86, 0.92, 1 })
                    end
                else
                    safeSetText(label, "")
                end
            end
        end
    end
end

return Ui

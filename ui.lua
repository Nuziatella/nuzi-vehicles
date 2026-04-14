local api = require("api")
local Constants = require("nuzi-vehicles/constants")

local Ui = {
    window = nil,
    speed_window = nil,
    compass_window = nil,
    helm_window = nil,
    toggle_window = nil,
    actions = nil,
    labels = {},
    buttons = {},
    sliders = {},
    compass_labels = {},
    speed = {},
    compass = {},
    helm = {}
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
        local want = visible and true or false
        if widget.__nuzi_visible ~= want then
            widget.__nuzi_visible = want
            pcall(function()
                widget:Show(want)
            end)
        end
    end
end

local function safeSetText(widget, text)
    if widget ~= nil and widget.SetText ~= nil then
        local nextText = tostring(text or "")
        if widget.__nuzi_text ~= nextText then
            widget.__nuzi_text = nextText
            pcall(function()
                widget:SetText(nextText)
            end)
        end
    end
end

local function safeSetColor(widget, color)
    if widget == nil or widget.style == nil or widget.style.SetColor == nil or type(color) ~= "table" then
        return
    end
    local signature = table.concat({
        tostring(color[1] or 1),
        tostring(color[2] or 1),
        tostring(color[3] or 1),
        tostring(color[4] or 1)
    }, ",")
    if widget.__nuzi_color ~= signature then
        widget.__nuzi_color = signature
        pcall(function()
            widget.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
        end)
    end
end

local function safeSetExtent(widget, width, height)
    if widget ~= nil and widget.SetExtent ~= nil then
        pcall(function()
            widget:SetExtent(width, height)
        end)
    end
end

local function safeSetTexture(drawable, path)
    if drawable ~= nil and drawable.SetTexture ~= nil and type(path) == "string" and path ~= "" then
        if drawable.__nuzi_texture ~= path then
            drawable.__nuzi_texture = path
            pcall(function()
                drawable:SetTexture(path)
            end)
        end
    end
end

local function safeSetSliderValue(slider, value)
    if slider ~= nil and slider.SetValue ~= nil then
        local nextValue = tonumber(value) or 0
        if slider.__nuzi_slider_value ~= nextValue then
            slider.__nuzi_slider_value = nextValue
            pcall(function()
                slider:SetValue(nextValue, false)
            end)
        end
    end
end

local function safeSetBarValue(widget, value)
    if widget ~= nil and widget.SetValue ~= nil then
        local nextValue = tonumber(value) or 0
        if widget.__nuzi_bar_value ~= nextValue then
            widget.__nuzi_bar_value = nextValue
            pcall(function()
                widget:SetValue(nextValue)
            end)
        end
    end
end

local function safeSetBarMinMax(widget, minValue, maxValue)
    if widget ~= nil and widget.SetMinMaxValues ~= nil then
        local minNum = tonumber(minValue) or 0
        local maxNum = tonumber(maxValue) or 0
        local signature = tostring(minNum) .. ":" .. tostring(maxNum)
        if widget.__nuzi_bar_range ~= signature then
            widget.__nuzi_bar_range = signature
            pcall(function()
                widget:SetMinMaxValues(minNum, maxNum)
            end)
        end
    end
end

local function applyCommonWindowBehavior(window)
    if window == nil then
        return
    end
    safeCall(function()
        window:SetCloseOnEscape(false)
    end)
    safeCall(function()
        window:EnableHidingIsRemove(false)
    end)
    safeCall(function()
        window:SetUILayer("normal")
    end)
end

local function isShiftDown()
    if api ~= nil and api.Input ~= nil and api.Input.IsShiftKeyDown ~= nil then
        local ok, down = pcall(function()
            return api.Input:IsShiftKeyDown()
        end)
        if ok then
            return down and true or false
        end
    end
    return false
end

local function createWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    applyCommonWindowBehavior(window)
    return window
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

local function createPlainButton(parent, id, x, y, width, height, onClick)
    if parent == nil or parent.CreateChildWidget == nil then
        return nil
    end
    local button = safeCall(function()
        return parent:CreateChildWidget("button", id, 0, true)
    end)
    if button == nil then
        return nil
    end
    safeCall(function()
        button:AddAnchor("TOPLEFT", parent, x, y)
    end)
    safeSetExtent(button, width, height)
    safeSetText(button, "")
    if button.SetHandler ~= nil and onClick ~= nil then
        button:SetHandler("OnClick", onClick)
    end
    if button.Enable ~= nil then
        safeCall(function()
            button:Enable(true)
        end)
    end
    safeShow(button, true)
    return button
end

local function createSlider(id, parent, x, y, width, minValue, maxValue, step)
    if api._Library == nil or api._Library.UI == nil or api._Library.UI.CreateSlider == nil then
        return nil
    end
    local slider = safeCall(function()
        return api._Library.UI.CreateSlider(id, parent)
    end)
    if slider == nil then
        return nil
    end
    safeCall(function()
        slider:AddAnchor("TOPLEFT", x, y)
    end)
    safeSetExtent(slider, width, 26)
    safeCall(function()
        slider:SetMinMaxValues(minValue, maxValue)
    end)
    if slider.SetStep ~= nil then
        safeCall(function()
            slider:SetStep(step)
        end)
    elseif slider.SetValueStep ~= nil then
        safeCall(function()
            slider:SetValueStep(step)
        end)
    end
    safeShow(slider, true)
    return slider
end

local function assetPath(relativePath)
    local baseDir = type(api) == "table" and type(api.baseDir) == "string" and api.baseDir or ""
    baseDir = string.gsub(baseDir, "\\", "/")
    if baseDir ~= "" then
        return string.gsub(baseDir .. "/" .. tostring(relativePath or ""), "/+", "/")
    end
    return tostring(relativePath or "")
end

local function createImageDrawable(widget, id, path, layer, width, height)
    if widget == nil then
        return nil
    end
    local drawable = safeCall(function()
        if widget.CreateImageDrawable ~= nil then
            return widget:CreateImageDrawable(id, layer or "artwork")
        end
        if widget.CreateDrawable ~= nil then
            return widget:CreateDrawable(id, layer or "artwork")
        end
        return nil
    end)
    if drawable == nil then
        return nil
    end
    safeSetTexture(drawable, path)
    if drawable.AddAnchor ~= nil then
        safeCall(function()
            drawable:AddAnchor("TOPLEFT", widget, 0, 0)
        end)
    end
    if drawable.SetExtent ~= nil then
        safeCall(function()
            drawable:SetExtent(width, height)
        end)
    end
    if drawable.Show ~= nil then
        safeCall(function()
            drawable:Show(true)
        end)
    end
    return drawable
end

local function createEmptyWindow(id)
    if api.Interface == nil or api.Interface.CreateEmptyWindow == nil then
        return nil
    end
    local window = safeCall(function()
        return api.Interface:CreateEmptyWindow(id, "UIParent")
    end)
    applyCommonWindowBehavior(window)
    return window
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
    local function readWindowOffset()
        local ok = false
        local x, y = nil, nil
        if window.GetEffectiveOffset ~= nil then
            ok, x, y = pcall(function()
                return window:GetEffectiveOffset()
            end)
        end
        if (not ok or x == nil or y == nil) and window.GetOffset ~= nil then
            ok, x, y = pcall(function()
                return window:GetOffset()
            end)
        end
        if ok then
            return tonumber(x), tonumber(y)
        end
        return nil, nil
    end
    local function onDragStart()
        if not isShiftDown() then
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
        if Ui.actions ~= nil and Ui.actions.save_position ~= nil then
            local x, y = readWindowOffset()
            if x == nil or y == nil then
                return
            end
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
    local defaultSize = tonumber(Constants.DEFAULT_SETTINGS.button_size) or 48
    safeSetExtent(window, defaultSize, defaultSize)
    local dragBar = createLabel(window, "NuziVehiclesToggleDragBar", 0, 0, defaultSize, defaultSize, 12, { 1, 1, 1, 0 }, getAlignLeft())
    Ui.labels.toggle_drag_bar = dragBar
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "button")
    Ui.buttons.toggle = createPlainButton(window, "NuziVehiclesToggleButton", 0, 0, defaultSize, defaultSize, function()
        if Ui.actions ~= nil and Ui.actions.toggle_main ~= nil then
            Ui.actions.toggle_main()
        end
    end)
    Ui.labels.toggle_icon = createImageDrawable(
        window,
        "NuziVehiclesToggleIcon",
        assetPath("nuzi-vehicles/icon_launcher.png"),
        "artwork",
        defaultSize,
        defaultSize
    )
    attachDragTargets(window, "button", { Ui.buttons.toggle })
    return window
end

local function applyToggleWindowLayout(size)
    local resolvedSize = math.max(36, math.min(96, math.floor((tonumber(size) or 48) + 0.5)))
    if Ui.toggle_window ~= nil then
        safeSetExtent(Ui.toggle_window, resolvedSize, resolvedSize)
    end
    if Ui.labels.toggle_icon ~= nil and Ui.labels.toggle_icon.SetExtent ~= nil then
        safeCall(function()
            Ui.labels.toggle_icon:SetExtent(resolvedSize, resolvedSize)
        end)
    end
    if Ui.buttons.toggle ~= nil then
        safeSetExtent(Ui.buttons.toggle, resolvedSize, resolvedSize)
    end
    if Ui.labels.toggle_drag_bar ~= nil then
        safeSetExtent(Ui.labels.toggle_drag_bar, resolvedSize, resolvedSize)
    end
end

local function createMainWindow()
    local window = createWindow(Constants.WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 390, 202)
    createBackground(window)
    local dragBar = createLabel(window, "NuziVehiclesDragBar", 0, 0, 390, 20, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "main")

    Ui.labels.title = createLabel(window, "NuziVehiclesTitle", 12, 6, 180, 18, 14, { 1, 1, 1, 1 }, getAlignLeft())
    Ui.labels.profile = createLabel(window, "NuziVehiclesProfile", 12, 30, 228, 18, 13, { 0.9, 0.94, 1, 1 }, getAlignLeft())
    Ui.labels.heading = createLabel(window, "NuziVehiclesHeading", 12, 52, 228, 18, 12, { 0.92, 0.86, 0.58, 1 }, getAlignLeft())
    Ui.labels.speed = createLabel(window, "NuziVehiclesSpeed", 12, 74, 228, 18, 12, { 0.95, 0.95, 0.95, 1 }, getAlignLeft())
    Ui.labels.base = createLabel(window, "NuziVehiclesBase", 12, 96, 228, 18, 12, { 0.84, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.labels.estimate = createLabel(window, "NuziVehiclesEstimate", 12, 118, 228, 18, 12, { 0.84, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.labels.sector = createLabel(window, "NuziVehiclesSector", 12, 140, 228, 18, 12, { 0.95, 0.88, 0.58, 1 }, getAlignLeft())
    Ui.labels.toggle_size = createLabel(window, "NuziVehiclesToggleSizeLabel", 12, 168, 98, 18, 12, { 0.95, 0.88, 0.58, 1 }, getAlignLeft())
    Ui.labels.toggle_size_value = createLabel(window, "NuziVehiclesToggleSizeValue", 350, 168, 28, 18, 12, { 0.95, 0.95, 0.95, 1 }, getAlignCenter())
    Ui.sliders.toggle_size = createSlider("NuziVehiclesToggleSizeSlider", window, 106, 166, 238, 36, 96, 1)

    Ui.buttons.prev = createButton("NuziVehiclesPrev", window, "<", 244, 24, 28, 24, function()
        if Ui.actions ~= nil and Ui.actions.previous_profile ~= nil then
            Ui.actions.previous_profile()
        end
    end)
    Ui.buttons.next = createButton("NuziVehiclesNext", window, ">", 278, 24, 28, 24, function()
        if Ui.actions ~= nil and Ui.actions.next_profile ~= nil then
            Ui.actions.next_profile()
        end
    end)
    Ui.buttons.enabled_toggle = createButton("NuziVehiclesEnabledToggle", window, "Pause", 312, 24, 62, 24, function()
        if Ui.actions ~= nil and Ui.actions.toggle_enabled ~= nil then
            Ui.actions.toggle_enabled()
        end
    end)
    Ui.buttons.speed_toggle = createButton("NuziVehiclesSpeedToggle", window, "Speed", 254, 64, 118, 22, function()
        if Ui.actions ~= nil and Ui.actions.toggle_speed ~= nil then
            Ui.actions.toggle_speed()
        end
    end)
    Ui.buttons.compass_toggle = createButton("NuziVehiclesCompassToggle", window, "Compass", 254, 90, 118, 22, function()
        if Ui.actions ~= nil and Ui.actions.toggle_compass ~= nil then
            Ui.actions.toggle_compass()
        end
    end)
    Ui.buttons.helm_toggle = createButton("NuziVehiclesHelmToggle", window, "Helm", 254, 116, 118, 22, function()
        if Ui.actions ~= nil and Ui.actions.toggle_helm ~= nil then
            Ui.actions.toggle_helm()
        end
    end)
    if Ui.sliders.toggle_size ~= nil and Ui.sliders.toggle_size.SetHandler ~= nil then
        Ui.sliders.toggle_size:SetHandler("OnSliderChanged", function(_, value)
            local numeric = math.floor((tonumber(value) or Constants.DEFAULT_SETTINGS.button_size or 48) + 0.5)
            safeSetText(Ui.labels.toggle_size_value, tostring(numeric))
            applyToggleWindowLayout(numeric)
            if Ui.actions ~= nil and Ui.actions.set_button_size ~= nil then
                Ui.actions.set_button_size(numeric)
            end
        end)
    end

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
        Ui.buttons.enabled_toggle,
        Ui.buttons.speed_toggle,
        Ui.buttons.compass_toggle,
        Ui.buttons.helm_toggle
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

local function createHelmWindow()
    local window = createWindow(Constants.HELM_WINDOW_ID)
    if window == nil then
        return nil
    end
    safeSetExtent(window, 236, 110)
    createBackground(window)
    local dragBar = createLabel(window, "NuziVehiclesHelmDragBar", 0, 0, 236, 20, 12, { 1, 1, 1, 0 }, getAlignLeft())
    safeSetText(dragBar, "")
    attachDrag(window, dragBar, "helm")

    Ui.helm.title = createLabel(window, "NuziVehiclesHelmTitle", 10, 6, 150, 16, 13, { 1, 1, 1, 1 }, getAlignLeft())
    Ui.helm.close = createButton("NuziVehiclesHelmClose", window, "X", 204, 4, 22, 20, function()
        if Ui.actions ~= nil and Ui.actions.toggle_helm ~= nil then
            Ui.actions.toggle_helm()
        end
    end)
    Ui.helm.profile = createLabel(window, "NuziVehiclesHelmProfile", 10, 24, 216, 16, 12, { 0.92, 0.86, 0.58, 1 }, getAlignLeft())
    Ui.helm.speed = createLabel(window, "NuziVehiclesHelmSpeed", 10, 42, 88, 20, 18, { 0.95, 0.95, 0.95, 1 }, getAlignLeft())
    Ui.helm.turn_hint = createLabel(window, "NuziVehiclesHelmTurnHint", 102, 44, 124, 18, 13, { 0.95, 0.88, 0.58, 1 }, getAlignLeft())
    Ui.helm.axis = createLabel(window, "NuziVehiclesHelmAxis", 10, 64, 216, 14, 11, { 0.82, 0.9, 0.96, 1 }, getAlignLeft())
    Ui.helm.efficiency = createLabel(window, "NuziVehiclesHelmEfficiency", 10, 78, 216, 14, 11, { 0.88, 0.88, 0.72, 1 }, getAlignLeft())
    Ui.helm.heading = createLabel(window, "NuziVehiclesHelmHeading", 10, 92, 216, 14, 11, { 0.84, 0.9, 0.96, 1 }, getAlignLeft())

    attachDragTargets(window, "helm", {
        Ui.helm.title,
        Ui.helm.close,
        Ui.helm.profile,
        Ui.helm.speed,
        Ui.helm.turn_hint,
        Ui.helm.axis,
        Ui.helm.efficiency
        ,
        Ui.helm.heading
    })
    return window
end

function Ui.Init(actions)
    Ui.actions = actions
    Ui.toggle_window = createToggleWindow()
    Ui.window = createMainWindow()
    Ui.speed_window = createSpeedWindow()
    Ui.compass_window = createCompassWindow()
    Ui.helm_window = createHelmWindow()
    safeShow(Ui.toggle_window, true)
    safeShow(Ui.window, true)
    safeShow(Ui.speed_window, true)
    safeShow(Ui.compass_window, true)
    safeShow(Ui.helm_window, true)
end

function Ui.Destroy()
    for _, window in ipairs({ Ui.window, Ui.speed_window, Ui.compass_window, Ui.helm_window, Ui.toggle_window }) do
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
    Ui.helm_window = nil
    Ui.toggle_window = nil
    Ui.actions = nil
    Ui.labels = {}
    Ui.buttons = {}
    Ui.sliders = {}
    Ui.compass_labels = {}
    Ui.speed = {}
    Ui.compass = {}
    Ui.helm = {}
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
    if Ui.helm_window ~= nil and Ui.helm_window.RemoveAllAnchors ~= nil and Ui.helm_window.AddAnchor ~= nil then
        safeCall(function()
            Ui.helm_window:RemoveAllAnchors()
            Ui.helm_window:AddAnchor("TOPLEFT", "UIParent", tonumber(settings.helm_x) or 860, tonumber(settings.helm_y) or 170)
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
        if window ~= nil then
            local x, y = nil, nil
            if window.GetEffectiveOffset ~= nil then
                x, y = safeCall(function()
                    return window:GetEffectiveOffset()
                end)
            end
            if (x == nil or y == nil) and window.GetOffset ~= nil then
                x, y = safeCall(function()
                    return window:GetOffset()
                end)
            end
            return tonumber(x), tonumber(y)
        end
        return nil, nil
    end

    positions.main_x, positions.main_y = readOffset(Ui.window)
    positions.speed_x, positions.speed_y = readOffset(Ui.speed_window)
    positions.compass_x, positions.compass_y = readOffset(Ui.compass_window)
    positions.helm_x, positions.helm_y = readOffset(Ui.helm_window)
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
        applyToggleWindowLayout(viewModel.toggle_button_size)
    end

    if viewModel.show_main_window then
        safeSetText(Ui.labels.title, Constants.ADDON_NAME)
        safeSetText(
            Ui.labels.profile,
            string.format(
                "%s | %s",
                tostring(viewModel.selected_profile_label or ""),
                viewModel.enabled and "Live" or "Paused"
            )
        )
        safeSetText(
            Ui.labels.heading,
            string.format(
                "Heading: %s",
                tostring(viewModel.world_heading_text or "--")
            )
        )
        safeSetText(
            Ui.labels.speed,
            string.format(
                "Speed: %.1f m/s | %s",
                tonumber(viewModel.current_speed) or 0,
                tostring(viewModel.speed_source or "Idle")
            )
        )
        safeSetText(Ui.labels.base, "Travel: " .. tostring(viewModel.travel_direction_text or "--"))
        safeSetText(
            Ui.labels.estimate,
            string.format(
                "Axis: %s | %s",
                tostring(viewModel.preferred_axis_text or "Unknown"),
                tostring(viewModel.current_axis_text or "Unknown")
            )
        )
        safeSetText(
            Ui.labels.sector,
            string.format(
                "Eff %.0f%% | Dev %.0f deg",
                tonumber(viewModel.estimated_efficiency_pct) or 0,
                tonumber(viewModel.deviation_deg) or 0
            )
        )
        safeSetText(Ui.labels.toggle_size, "Launcher")
        safeSetText(Ui.labels.toggle_size_value, tostring(math.floor((tonumber(viewModel.toggle_button_size) or 48) + 0.5)))
        safeSetSliderValue(Ui.sliders.toggle_size, tonumber(viewModel.toggle_button_size) or 48)
        safeSetText(Ui.buttons.enabled_toggle, viewModel.enabled and "Pause" or "Resume")
        safeSetText(Ui.buttons.speed_toggle, viewModel.show_speed_window and "Speed On" or "Speed Off")
        safeSetText(Ui.buttons.compass_toggle, viewModel.show_compass_window and "Compass On" or "Compass Off")
        if Ui.buttons.helm_toggle ~= nil then
            safeSetText(Ui.buttons.helm_toggle, viewModel.show_helm_window and "Helm On" or "Helm Off")
        end
    end

    safeShow(Ui.speed_window, viewModel.show_speed_window and true or false)
    if viewModel.show_speed_window then
        safeSetText(Ui.speed.title, viewModel.enabled and "Travel Speed" or "Travel Speed (Paused)")
        safeSetText(Ui.speed.value, string.format("%.1f m/s", tonumber(viewModel.current_speed) or 0))
        safeSetText(Ui.speed.modifier, tostring(viewModel.speed_source or "Idle"))
        safeSetBarMinMax(Ui.speed.bar, 0, tonumber(viewModel.speed_bar_max) or Constants.DEFAULT_SPEED_BAR_MAX)
        safeSetBarValue(Ui.speed.bar, math.abs(tonumber(viewModel.current_speed) or 0))
    end

    safeShow(Ui.compass_window, viewModel.show_compass_window and true or false)
    if viewModel.show_compass_window then
        safeSetText(Ui.compass.title, viewModel.enabled and "Nautical Compass" or "Nautical Compass (Paused)")
        safeSetText(
            Ui.compass.heading,
            string.format(
                "Heading [%s]: %s",
                tostring(viewModel.heading_source or "Idle"),
                tostring(viewModel.world_heading_text or "--")
            )
        )
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

    safeShow(Ui.helm_window, viewModel.show_helm_window and true or false)
    if viewModel.show_helm_window then
        safeSetText(Ui.helm.title, viewModel.enabled and "Helm" or "Helm (Paused)")
        safeSetText(Ui.helm.profile, tostring(viewModel.selected_profile_label or "No Profile"))
        safeSetText(Ui.helm.speed, string.format("%.1f m/s", tonumber(viewModel.current_speed) or 0))
        safeSetText(Ui.helm.heading, tostring(viewModel.world_heading_text or "--"))
        safeSetText(
            Ui.helm.axis,
            string.format(
                "Axis: %s | Source: %s",
                tostring(viewModel.preferred_axis_text or "Unknown"),
                tostring(viewModel.heading_source or "Idle")
            )
        )
        safeSetText(Ui.helm.turn_hint, tostring(viewModel.axis_turn_hint or "Turn: --"))
        safeSetText(
            Ui.helm.efficiency,
            string.format(
                "%s | %.0f deg off | Eff %.0f%%",
                viewModel.axis_boost_active and "Boost Held" or "Boost Lost",
                tonumber(viewModel.estimated_efficiency_pct) or 0,
                tonumber(viewModel.deviation_deg) or 0
            )
        )
    end
end

return Ui

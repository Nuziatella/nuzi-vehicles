local Constants = require("nuzi-vehicles/constants")
local Shared = require("nuzi-vehicles/shared")
local Profiles = require("nuzi-vehicles/profiles")
local Models = require("nuzi-vehicles/models")
local MathUtils = require("nuzi-vehicles/math_utils")
local Adapter = require("nuzi-vehicles/game_adapter")

local Controller = {
    state = {
        profiles = {},
        world_heading = nil,
        world_heading_label = "--",
        travel_heading = nil,
        travel_heading_label = "--",
        current_speed = 0,
        current_turn_speed = 0,
        speed_source = "Idle",
        heading_source = "Idle",
        preferred_axis = nil,
        current_axis = nil,
        axis_deviation = nil,
        axis_efficiency_pct = 0,
        axis_penalty_pct = 0,
        axis_state_label = "Unknown",
        axis_turn_hint = "Axis hold: --",
        axis_boost_active = false,
        speed_bar_max = Constants.DEFAULT_SPEED_BAR_MAX,
        last_world_position = nil,
        last_world_sample_ms = nil,
        last_travel_heading_ms = nil,
        last_heading_update_ms = nil,
        estimated_vehicle_heading = nil,
        estimated_vehicle_heading_label = "--",
        vehicle_turn_sign = 1,
        measured_travel_speed = 0,
        smoothed_travel_speed = 0,
        travel_speed_samples = {}
    }
}

local PROFILE_ALIASES = {
    moby = "fishing",
    warship = "cutter"
}

local function clamp(value, minValue, maxValue)
    local number = tonumber(value) or 0
    if number < minValue then
        return minValue
    end
    if number > maxValue then
        return maxValue
    end
    return number
end

local function blendHeading(previousHeading, nextHeading, weight)
    local previous = tonumber(previousHeading)
    local nextValue = tonumber(nextHeading)
    if previous == nil then
        return nextValue
    end
    if nextValue == nil then
        return previous
    end
    local ratio = clamp(weight, 0, 1)
    local delta = ((nextValue - previous + 540) % 360) - 180
    return MathUtils.NormalizeHeading(previous + (delta * ratio))
end

local function buildArrowColor(efficiencyPct)
    local ratio = clamp((tonumber(efficiencyPct) or 0) / 100, 0, 1)
    return {
        1 - ratio,
        0.35 + (0.65 * ratio),
        0.2,
        1
    }
end

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function resetTravelSamples()
    Controller.state.travel_speed_samples = {}
    Controller.state.measured_travel_speed = 0
    Controller.state.smoothed_travel_speed = 0
end

local function integrateHeading(baseHeading, turnSpeed, dtSeconds, sign)
    local base = tonumber(baseHeading)
    if base == nil then
        return nil
    end
    local rate = tonumber(turnSpeed) or 0
    local dt = math.max(0, tonumber(dtSeconds) or 0)
    local direction = tonumber(sign) or 1
    return MathUtils.NormalizeHeading(base + (rate * dt * direction))
end

local function trimTravelSamples(nowMs)
    local samples = Controller.state.travel_speed_samples
    while #samples > 0 do
        local sample = samples[1]
        local age = (tonumber(nowMs) or 0) - (tonumber(sample.sample_ms) or 0)
        if age <= Constants.TRAVEL_SPEED_WINDOW_MS then
            break
        end
        table.remove(samples, 1)
    end
end

local function getWindowedTravelSpeed()
    local totalDistance = 0
    local totalMs = 0
    for _, sample in ipairs(Controller.state.travel_speed_samples or {}) do
        totalDistance = totalDistance + (tonumber(sample.distance) or 0)
        totalMs = totalMs + (tonumber(sample.delta_ms) or 0)
    end
    if totalMs <= 0 then
        return 0
    end
    return totalDistance / (totalMs / 1000)
end

local function updateSmoothedTravelSpeed(targetSpeed)
    local current = tonumber(Controller.state.smoothed_travel_speed) or 0
    local target = math.max(0, tonumber(targetSpeed) or 0)
    local alpha = target >= current
        and Constants.TRAVEL_SPEED_RISE_SMOOTHING
        or Constants.TRAVEL_SPEED_FALL_SMOOTHING
    local nextSpeed = current + ((target - current) * alpha)
    if target <= Constants.MIN_TRAVEL_SPEED_DISPLAY and nextSpeed <= Constants.MIN_TRAVEL_SPEED_DISPLAY then
        nextSpeed = 0
    end
    Controller.state.smoothed_travel_speed = nextSpeed
end

local function loadProfiles()
    Controller.state.profiles = {}
    for _, profile in ipairs(Profiles.DATA or {}) do
        local normalized = Models.NormalizeProfile(profile)
        if normalized ~= nil and normalized.id ~= "" then
            Controller.state.profiles[#Controller.state.profiles + 1] = normalized
        end
    end
end

local function getSelectedProfileIndex()
    local settings = Shared.EnsureSettings()
    local selectedId = tostring(settings.selected_profile_id or "")
    if PROFILE_ALIASES[selectedId] ~= nil then
        selectedId = PROFILE_ALIASES[selectedId]
        settings.selected_profile_id = selectedId
        Shared.SaveSettings()
    end
    for index = 1, #Controller.state.profiles do
        if Controller.state.profiles[index].id == selectedId then
            return index
        end
    end
    return #Controller.state.profiles > 0 and 1 or nil
end

function Controller.GetSelectedProfile()
    local index = getSelectedProfileIndex()
    if index == nil then
        return nil, nil
    end
    return Controller.state.profiles[index], index
end

function Controller.SelectProfileByIndex(index)
    local profile = Controller.state.profiles[tonumber(index) or 0]
    if profile == nil then
        return false
    end
    local settings = Shared.EnsureSettings()
    settings.selected_profile_id = profile.id
    Shared.SaveSettings()
    return true
end

function Controller.SelectPreviousProfile()
    local currentIndex = getSelectedProfileIndex()
    if currentIndex == nil then
        return false
    end
    local nextIndex = currentIndex - 1
    if nextIndex < 1 then
        nextIndex = #Controller.state.profiles
    end
    return Controller.SelectProfileByIndex(nextIndex)
end

function Controller.SelectNextProfile()
    local currentIndex = getSelectedProfileIndex()
    if currentIndex == nil then
        return false
    end
    local nextIndex = currentIndex + 1
    if nextIndex > #Controller.state.profiles then
        nextIndex = 1
    end
    return Controller.SelectProfileByIndex(nextIndex)
end

local function updateMovementSample()
    local nowMs = Adapter.GetUiMsec()
    local x, z = Adapter.GetPlayerTravelPosition()
    if x == nil or z == nil then
        resetTravelSamples()
        Controller.state.last_world_position = nil
        Controller.state.last_world_sample_ms = nil
        return
    end

    local lastPosition = Controller.state.last_world_position
    local lastSampleMs = tonumber(Controller.state.last_world_sample_ms)
    if lastPosition ~= nil and lastSampleMs ~= nil and nowMs ~= nil and nowMs > lastSampleMs then
        local deltaMs = nowMs - lastSampleMs
        local dx = x - (tonumber(lastPosition.x) or x)
        local dz = z - (tonumber(lastPosition.z) or z)
        local distance = math.sqrt((dx * dx) + (dz * dz))
        local deltaSeconds = deltaMs / 1000
        if distance >= Constants.MIN_HEADING_DISTANCE then
            local rawHeading = MathUtils.AngleFromDelta(dx, dz)
            local travelHeading = blendHeading(
                Controller.state.travel_heading,
                rawHeading,
                Constants.HEADING_SMOOTHING
            )
            Controller.state.travel_heading = travelHeading
            Controller.state.travel_heading_label = MathUtils.HeadingLabel(travelHeading)
            Controller.state.last_travel_heading_ms = nowMs
        end

        if deltaMs > Constants.MAX_TRAVEL_SAMPLE_INTERVAL_MS or distance > Constants.MAX_TRAVEL_SAMPLE_DISTANCE then
            resetTravelSamples()
        elseif deltaMs >= Constants.MIN_TRAVEL_SAMPLE_INTERVAL_MS and deltaSeconds > 0 then
            local samples = Controller.state.travel_speed_samples
            samples[#samples + 1] = {
                distance = distance,
                delta_ms = deltaMs,
                sample_ms = nowMs
            }
            trimTravelSamples(nowMs)
            Controller.state.measured_travel_speed = getWindowedTravelSpeed()
            updateSmoothedTravelSpeed(Controller.state.measured_travel_speed)
        end
    end

    Controller.state.last_world_position = { x = x, z = z }
    Controller.state.last_world_sample_ms = nowMs
end

local function updateVehicleHeadingEstimate()
    local nowMs = Adapter.GetUiMsec()
    if nowMs == nil then
        return
    end

    local speed = math.abs(tonumber(Adapter.GetVehicleSpeed()) or 0)
    local turnSpeed = tonumber(Adapter.GetVehicleTurnSpeed()) or 0
    local lastUpdateMs = tonumber(Controller.state.last_heading_update_ms)
    Controller.state.last_heading_update_ms = nowMs

    if speed <= Constants.MIN_TRAVEL_SPEED_DISPLAY and math.abs(turnSpeed) <= Constants.VEHICLE_TURN_SPEED_THRESHOLD then
        return
    end

    local heading = tonumber(Controller.state.estimated_vehicle_heading)
        or tonumber(Controller.state.travel_heading)
        or tonumber(Controller.state.world_heading)
    if heading == nil then
        return
    end

    local dtSeconds = 0
    if lastUpdateMs ~= nil and nowMs > lastUpdateMs then
        dtSeconds = math.min((nowMs - lastUpdateMs) / 1000, 1)
    end

    if dtSeconds > 0 and math.abs(turnSpeed) > Constants.VEHICLE_TURN_SPEED_THRESHOLD then
        local sign = tonumber(Controller.state.vehicle_turn_sign) or 1
        if speed > Constants.MIN_TRAVEL_SPEED_DISPLAY and Controller.state.travel_heading ~= nil then
            local forwardCandidate = integrateHeading(heading, turnSpeed, dtSeconds, 1)
            local reverseCandidate = integrateHeading(heading, turnSpeed, dtSeconds, -1)
            local targetHeading = tonumber(Controller.state.travel_heading)
            local forwardDelta = MathUtils.AngleDelta(forwardCandidate, targetHeading)
            local reverseDelta = MathUtils.AngleDelta(reverseCandidate, targetHeading)
            if forwardDelta + 2 < reverseDelta then
                sign = 1
            elseif reverseDelta + 2 < forwardDelta then
                sign = -1
            end
            Controller.state.vehicle_turn_sign = sign
        end
        heading = integrateHeading(heading, turnSpeed, dtSeconds, sign)
    end

    if speed > Constants.MIN_TRAVEL_SPEED_DISPLAY and Controller.state.travel_heading ~= nil then
        local correction = math.abs(turnSpeed) > Constants.VEHICLE_TURN_SPEED_THRESHOLD and 0.08 or 0.18
        heading = blendHeading(heading, Controller.state.travel_heading, correction)
    end

    Controller.state.estimated_vehicle_heading = heading
    Controller.state.estimated_vehicle_heading_label = MathUtils.HeadingLabel(heading)
end

local function updateHeading()
    local nowMs = Adapter.GetUiMsec()
    local directHeading = Adapter.GetPlayerHeading()
    if directHeading ~= nil then
        Controller.state.world_heading = MathUtils.NormalizeHeading(directHeading)
        Controller.state.world_heading_label = MathUtils.HeadingLabel(Controller.state.world_heading)
        Controller.state.heading_source = "Direct"
        return
    end

    local vehicleSpeed = math.abs(tonumber(Adapter.GetVehicleSpeed()) or 0)
    local vehicleTurnSpeed = math.abs(tonumber(Adapter.GetVehicleTurnSpeed()) or 0)
    local hasVehicleHeading = vehicleSpeed > Constants.MIN_TRAVEL_SPEED_DISPLAY
        or vehicleTurnSpeed > Constants.VEHICLE_TURN_SPEED_THRESHOLD

    if hasVehicleHeading and Controller.state.estimated_vehicle_heading ~= nil then
        Controller.state.world_heading = Controller.state.estimated_vehicle_heading
        Controller.state.world_heading_label = Controller.state.estimated_vehicle_heading_label
        Controller.state.heading_source = "Estimate"

        local travelHeadingAge = nil
        if nowMs ~= nil and Controller.state.last_travel_heading_ms ~= nil then
            travelHeadingAge = nowMs - Controller.state.last_travel_heading_ms
        end
        if Controller.state.travel_heading == nil
            or travelHeadingAge == nil
            or travelHeadingAge > Constants.VEHICLE_HEADING_STALE_MS
        then
            Controller.state.travel_heading = Controller.state.estimated_vehicle_heading
            Controller.state.travel_heading_label = Controller.state.estimated_vehicle_heading_label
        end
        return
    end

    Controller.state.world_heading = Controller.state.travel_heading
    Controller.state.world_heading_label = Controller.state.travel_heading_label
    if Controller.state.travel_heading ~= nil then
        Controller.state.heading_source = "Travel"
    else
        Controller.state.heading_source = "Idle"
    end
end

local function updateSpeed()
    local vehicleSpeed = math.abs(Adapter.GetVehicleSpeed())
    if vehicleSpeed > 0.05 then
        Controller.state.current_speed = vehicleSpeed
        Controller.state.current_turn_speed = Adapter.GetVehicleTurnSpeed()
        Controller.state.speed_source = "Vehicle"
    else
        Controller.state.current_speed = math.abs(tonumber(Controller.state.smoothed_travel_speed) or 0)
        Controller.state.current_turn_speed = 0
        if Controller.state.current_speed > Constants.MIN_TRAVEL_SPEED_DISPLAY then
            Controller.state.speed_source = "Travel"
        else
            Controller.state.speed_source = "Idle"
        end
    end

    if Controller.state.current_speed > Controller.state.speed_bar_max then
        Controller.state.speed_bar_max = math.ceil(Controller.state.current_speed + 2)
    elseif Controller.state.current_speed < (Controller.state.speed_bar_max * 0.4)
        and Controller.state.speed_bar_max > Constants.DEFAULT_SPEED_BAR_MAX
    then
        Controller.state.speed_bar_max = math.max(Constants.DEFAULT_SPEED_BAR_MAX, math.ceil(Controller.state.current_speed + 4))
    end
end

local function updateAxisEvaluation(profile)
    local axisModel = profile ~= nil and profile.axis_model or nil
    Controller.state.preferred_axis = axisModel ~= nil and axisModel.preferred_axis or nil
    Controller.state.current_axis = nil
    Controller.state.axis_deviation = nil
    Controller.state.axis_efficiency_pct = 0
    Controller.state.axis_penalty_pct = 0
    Controller.state.axis_state_label = "Unknown"
    Controller.state.axis_turn_hint = "Turn: --"
    Controller.state.axis_boost_active = false

    if axisModel == nil or Controller.state.travel_heading == nil then
        return
    end

    local evaluation = MathUtils.EvaluateAxisDeviation(Controller.state.travel_heading, axisModel)
    if evaluation == nil then
        return
    end

    Controller.state.preferred_axis = evaluation.preferred_axis
    Controller.state.current_axis = evaluation.current_axis
    Controller.state.axis_deviation = evaluation.deviation_deg
    Controller.state.axis_efficiency_pct = evaluation.efficiency_pct
    Controller.state.axis_penalty_pct = evaluation.penalty_pct
    Controller.state.axis_state_label = evaluation.label
    Controller.state.axis_boost_active = (tonumber(evaluation.deviation_deg) or 999) <= Constants.AXIS_BOOST_MAX_DEVIATION

    local heading = tonumber(Controller.state.world_heading) or tonumber(Controller.state.travel_heading)
    if heading == nil then
        return
    end
    local bestTarget = nil
    local bestSignedDelta = nil
    for _, targetHeading in ipairs(axisModel.target_headings or {}) do
        local signedDelta = MathUtils.SignedAngleDelta(heading, targetHeading)
        if bestSignedDelta == nil or math.abs(signedDelta) < math.abs(bestSignedDelta) then
            bestSignedDelta = signedDelta
            bestTarget = MathUtils.NormalizeHeading(targetHeading)
        end
    end
    if bestSignedDelta == nil or bestTarget == nil then
        return
    end
    local magnitude = math.abs(bestSignedDelta)
    if magnitude <= 2 then
        Controller.state.axis_turn_hint = "Hold course"
    elseif bestSignedDelta > 0 then
        Controller.state.axis_turn_hint = string.format("Turn Right %.0f deg", magnitude)
    else
        Controller.state.axis_turn_hint = string.format("Turn Left %.0f deg", magnitude)
    end
end

function Controller.Update()
    local profile = Controller.GetSelectedProfile()
    updateMovementSample()
    updateSpeed()
    updateVehicleHeadingEstimate()
    updateHeading()
    updateAxisEvaluation(profile)
end

function Controller.BuildViewModel()
    local settings = Shared.EnsureSettings()
    local profile = Controller.GetSelectedProfile()
    local compassBands = {}
    local preferredBands = profile ~= nil
        and MathUtils.PreferredBandIndices(profile.axis_model.highlight_headings)
        or {}
    local currentBand = Controller.state.travel_heading ~= nil
        and MathUtils.BandIndex(Controller.state.travel_heading)
        or nil

    for index = 1, 8 do
        compassBands[index] = {
            text = MathUtils.BandLabel(index),
            is_current = currentBand == index,
            is_preferred = contains(preferredBands, index)
        }
    end

    return {
        enabled = settings.enabled and true or false,
        selected_profile_label = profile ~= nil and profile.label or "No Profile",
        world_heading_text = Controller.state.world_heading ~= nil
            and string.format("%.0f deg %s", Controller.state.world_heading, Controller.state.world_heading_label)
            or "--",
        travel_direction_text = Controller.state.travel_heading ~= nil
            and string.format("%.0f deg %s", Controller.state.travel_heading, Controller.state.travel_heading_label)
            or "--",
        current_speed = Controller.state.current_speed,
        current_turn_speed = Controller.state.current_turn_speed,
        speed_source = Controller.state.speed_source,
        heading_source = Controller.state.heading_source,
        base_speed = profile ~= nil and profile.base_speed or 0,
        preferred_axis_text = MathUtils.AxisLabel(Controller.state.preferred_axis),
        current_axis_text = MathUtils.AxisLabel(Controller.state.current_axis),
        estimated_efficiency_pct = Controller.state.axis_efficiency_pct,
        estimated_penalty_pct = Controller.state.axis_penalty_pct,
        deviation_deg = tonumber(Controller.state.axis_deviation) or 0,
        axis_state_label = Controller.state.axis_state_label,
        axis_turn_hint = Controller.state.axis_turn_hint,
        axis_boost_active = Controller.state.axis_boost_active,
        speed_bar_max = Controller.state.speed_bar_max,
        compass_bands = compassBands,
        arrow_text = Controller.state.travel_heading ~= nil and MathUtils.HeadingArrow(Controller.state.travel_heading) or "^",
        arrow_color = buildArrowColor(Controller.state.axis_efficiency_pct),
        toggle_button_size = tonumber(settings.button_size) or 48,
        show_main_window = settings.show_main_window and true or false,
        show_speed_window = settings.show_speed_window and true or false,
        show_compass_window = settings.show_compass_window and true or false,
        show_helm_window = settings.show_helm_window and true or false
    }
end

function Controller.Initialize()
    loadProfiles()
    local settings = Shared.EnsureSettings()
    if Shared.Trim(settings.selected_profile_id) == "" and #Controller.state.profiles > 0 then
        settings.selected_profile_id = Controller.state.profiles[1].id
        Shared.SaveSettings()
    end
    Controller.state.speed_bar_max = Constants.DEFAULT_SPEED_BAR_MAX
    resetTravelSamples()
end

function Controller.IsTelemetryActive()
    return (tonumber(Controller.state.current_speed) or 0) > Constants.MIN_TRAVEL_SPEED_DISPLAY
        or math.abs(tonumber(Controller.state.current_turn_speed) or 0) > Constants.VEHICLE_TURN_SPEED_THRESHOLD
        or Controller.state.world_heading ~= nil
        or Controller.state.travel_heading ~= nil
end

return Controller

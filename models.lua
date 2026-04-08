local Models = {}

local DEFAULT_AXIS_CURVE = {
    { max_deviation = 10, efficiency_pct = 100, penalty_pct = 0, label = "Optimal" },
    { max_deviation = 22.5, efficiency_pct = 92, penalty_pct = -4, label = "Strong" },
    { max_deviation = 45, efficiency_pct = 78, penalty_pct = -10, label = "Usable" },
    { max_deviation = 67.5, efficiency_pct = 58, penalty_pct = -18, label = "Off Axis" },
    { max_deviation = 90, efficiency_pct = 35, penalty_pct = -28, label = "Cross Axis" }
}

local DEFAULT_AXIS_TARGETS = {
    north_south = { 0, 180 },
    east_west = { 90, 270 }
}

local function copyNumberList(values)
    local out = {}
    for _, value in ipairs(values or {}) do
        out[#out + 1] = (tonumber(value) or 0) % 360
    end
    return out
end

local function sortCurve(curve)
    table.sort(curve, function(a, b)
        return (tonumber(a.max_deviation) or 0) < (tonumber(b.max_deviation) or 0)
    end)
end

function Models.NormalizeAxisCurveEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end
    return {
        max_deviation = tonumber(entry.max_deviation) or 90,
        efficiency_pct = tonumber(entry.efficiency_pct) or 0,
        penalty_pct = tonumber(entry.penalty_pct) or 0,
        label = tostring(entry.label or "")
    }
end

function Models.NormalizeAxisModel(axisModel)
    if type(axisModel) ~= "table" then
        axisModel = {}
    end

    local preferredAxis = tostring(axisModel.preferred_axis or "north_south")
    if preferredAxis ~= "east_west" then
        preferredAxis = "north_south"
    end

    local normalized = {
        preferred_axis = preferredAxis,
        target_headings = copyNumberList(axisModel.target_headings),
        highlight_headings = copyNumberList(axisModel.highlight_headings),
        deviation_curve = {}
    }

    if #normalized.target_headings == 0 then
        normalized.target_headings = copyNumberList(DEFAULT_AXIS_TARGETS[preferredAxis])
    end
    if #normalized.highlight_headings == 0 then
        normalized.highlight_headings = copyNumberList(normalized.target_headings)
    end

    for _, entry in ipairs(axisModel.deviation_curve or {}) do
        local normalizedEntry = Models.NormalizeAxisCurveEntry(entry)
        if normalizedEntry ~= nil then
            normalized.deviation_curve[#normalized.deviation_curve + 1] = normalizedEntry
        end
    end
    if #normalized.deviation_curve == 0 then
        for _, entry in ipairs(DEFAULT_AXIS_CURVE) do
            normalized.deviation_curve[#normalized.deviation_curve + 1] = Models.NormalizeAxisCurveEntry(entry)
        end
    end
    sortCurve(normalized.deviation_curve)

    return normalized
end

function Models.NormalizeProfile(profile)
    if type(profile) ~= "table" then
        return nil
    end
    return {
        id = tostring(profile.id or ""),
        label = tostring(profile.label or profile.id or "Boat"),
        base_speed = tonumber(profile.base_speed) or 0,
        axis_model = Models.NormalizeAxisModel(profile.axis_model)
    }
end

return Models

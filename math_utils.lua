local MathUtils = {}

local CARDINAL_LABELS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
local HEADING_ARROWS = { "^", "/", ">", "\\", "v", "/", "<", "\\" }
local AXIS_LABELS = {
    north_south = "North/South",
    east_west = "East/West"
}

function MathUtils.NormalizeHeading(degrees)
    local value = tonumber(degrees) or 0
    value = value % 360
    if value < 0 then
        value = value + 360
    end
    return value
end

function MathUtils.AngleFromDelta(dx, dz)
    return MathUtils.NormalizeHeading(math.deg(math.atan2(dx, dz)))
end

function MathUtils.AngleDelta(a, b)
    local delta = math.abs(MathUtils.NormalizeHeading(a) - MathUtils.NormalizeHeading(b))
    if delta > 180 then
        delta = 360 - delta
    end
    return delta
end

function MathUtils.HeadingLabel(degrees)
    local normalized = MathUtils.NormalizeHeading(degrees)
    local index = math.floor(((normalized + 22.5) % 360) / 45) + 1
    return CARDINAL_LABELS[index] or "N"
end

function MathUtils.HeadingArrow(degrees)
    local normalized = MathUtils.NormalizeHeading(degrees)
    local index = math.floor(((normalized + 22.5) % 360) / 45) + 1
    return HEADING_ARROWS[index] or "^"
end

function MathUtils.AxisLabel(axis)
    return AXIS_LABELS[tostring(axis or "")] or "Unknown"
end

function MathUtils.DominantAxis(heading)
    local normalized = MathUtils.NormalizeHeading(heading)
    local nsDeviation = math.min(
        MathUtils.AngleDelta(normalized, 0),
        MathUtils.AngleDelta(normalized, 180)
    )
    local ewDeviation = math.min(
        MathUtils.AngleDelta(normalized, 90),
        MathUtils.AngleDelta(normalized, 270)
    )
    if nsDeviation <= ewDeviation then
        return "north_south", nsDeviation
    end
    return "east_west", ewDeviation
end

function MathUtils.BandIndex(heading)
    local normalized = MathUtils.NormalizeHeading(heading)
    return math.floor(((normalized + 22.5) % 360) / 45) + 1
end

function MathUtils.BandHeading(index)
    return MathUtils.NormalizeHeading(((tonumber(index) or 1) - 1) * 45)
end

function MathUtils.BandLabel(index)
    return CARDINAL_LABELS[tonumber(index) or 1] or "N"
end

function MathUtils.PreferredBandIndices(headings)
    local seen = {}
    local out = {}
    for _, heading in ipairs(headings or {}) do
        local index = MathUtils.BandIndex(heading)
        if not seen[index] then
            seen[index] = true
            out[#out + 1] = index
        end
    end
    return out
end

function MathUtils.EvaluateAxisDeviation(heading, axisModel)
    if type(axisModel) ~= "table" then
        return nil
    end

    local normalized = MathUtils.NormalizeHeading(heading)
    local preferredDeviation = nil
    for _, targetHeading in ipairs(axisModel.target_headings or {}) do
        local deviation = MathUtils.AngleDelta(normalized, targetHeading)
        if preferredDeviation == nil or deviation < preferredDeviation then
            preferredDeviation = deviation
        end
    end
    if preferredDeviation == nil then
        preferredDeviation = 90
    end

    local currentAxis = MathUtils.DominantAxis(normalized)
    local curveEntry = nil
    for _, candidate in ipairs(axisModel.deviation_curve or {}) do
        curveEntry = candidate
        if preferredDeviation <= (tonumber(candidate.max_deviation) or 90) then
            break
        end
    end
    curveEntry = curveEntry or {}

    return {
        preferred_axis = tostring(axisModel.preferred_axis or "north_south"),
        current_axis = currentAxis,
        deviation_deg = preferredDeviation,
        efficiency_pct = tonumber(curveEntry.efficiency_pct) or 0,
        penalty_pct = tonumber(curveEntry.penalty_pct) or 0,
        label = tostring(curveEntry.label or "")
    }
end

return MathUtils

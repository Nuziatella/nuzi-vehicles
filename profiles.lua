local Profiles = {}

local DEFAULT_AXIS_CURVE = {
    { max_deviation = 10, efficiency_pct = 100, penalty_pct = 0, label = "Optimal" },
    { max_deviation = 22.5, efficiency_pct = 92, penalty_pct = -4, label = "Strong" },
    { max_deviation = 45, efficiency_pct = 78, penalty_pct = -10, label = "Usable" },
    { max_deviation = 67.5, efficiency_pct = 58, penalty_pct = -18, label = "Off Axis" },
    { max_deviation = 90, efficiency_pct = 35, penalty_pct = -28, label = "Cross Axis" }
}

local function makeAxisModel(preferredAxis, overrides)
    overrides = overrides or {}
    return {
        preferred_axis = preferredAxis,
        target_headings = overrides.target_headings,
        highlight_headings = overrides.highlight_headings,
        deviation_curve = overrides.deviation_curve or DEFAULT_AXIS_CURVE
    }
end

Profiles.DATA = {
    {
        id = "clipper",
        label = "Harpoon Clipper",
        base_speed = 9.8,
        axis_model = makeAxisModel("north_south")
    },
    {
        id = "merchant",
        label = "Merchant Schooner",
        base_speed = 8.4,
        axis_model = makeAxisModel("east_west")
    },
    {
        id = "cutter",
        label = "Eznan Cutter",
        base_speed = 10.2,
        axis_model = makeAxisModel("north_south")
    },
    {
        id = "galleon",
        label = "Galleon",
        base_speed = 10.2,
        axis_model = makeAxisModel("north_south")
    },
    {
        id = "fishing",
        label = "Fishing Boat / Moby Drake",
        base_speed = 8.8,
        axis_model = makeAxisModel("north_south")
    }
}

return Profiles

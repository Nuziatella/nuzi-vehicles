local Constants = {}

Constants.ADDON_ID = "nuzi_vehicles"
Constants.ADDON_NAME = "Nuzi Vehicles"
Constants.ADDON_AUTHOR = "Nuzi"
Constants.ADDON_VERSION = "1.0.0"
Constants.ADDON_DESC = "Vehicle compass and speed profiler"
Constants.SETTINGS_FILE_PATH = "nuzi-vehicles/settings.txt"

Constants.WINDOW_ID = "NuziVehiclesCompassMain"
Constants.SPEED_WINDOW_ID = "NuziVehiclesCompassSpeed"
Constants.COMPASS_WINDOW_ID = "NuziVehiclesCompassHeading"
Constants.TOGGLE_WINDOW_ID = "NuziVehiclesCompassToggle"

Constants.UPDATE_INTERVAL_MS = 120
Constants.MIN_HEADING_DELTA = 0.001
Constants.MIN_HEADING_DISTANCE = 0.15
Constants.HEADING_SMOOTHING = 0.35
Constants.DEFAULT_SPEED_BAR_MAX = 20
Constants.MIN_TRAVEL_SAMPLE_INTERVAL_MS = 80
Constants.MAX_TRAVEL_SAMPLE_INTERVAL_MS = 450
Constants.TRAVEL_SPEED_WINDOW_MS = 900
Constants.MAX_TRAVEL_SAMPLE_DISTANCE = 12
Constants.TRAVEL_SPEED_RISE_SMOOTHING = 0.28
Constants.TRAVEL_SPEED_FALL_SMOOTHING = 0.4
Constants.MIN_TRAVEL_SPEED_DISPLAY = 0.05
Constants.VEHICLE_TURN_SPEED_THRESHOLD = 0.01
Constants.VEHICLE_HEADING_STALE_MS = 900

Constants.DEFAULT_SETTINGS = {
    enabled = true,
    selected_profile_id = "clipper",
    x = 260,
    y = 260,
    speed_x = 260,
    speed_y = 170,
    compass_x = 560,
    compass_y = 170,
    button_x = 40,
    button_y = 220,
    show_main_window = true,
    show_speed_window = true,
    show_compass_window = true
}

return Constants

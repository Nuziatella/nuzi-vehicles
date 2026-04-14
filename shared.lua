local api = require("api")
local Constants = require("nuzi-vehicles/constants")

local Shared = {
    settings = nil
}

local ADDONS_BASE_PATH = nil
pcall(function()
    if type(api) == "table" and type(api.baseDir) == "string" and api.baseDir ~= "" then
        ADDONS_BASE_PATH = string.gsub(api.baseDir, "\\", "/")
        return
    end
    if type(debug) == "table" and type(debug.getinfo) == "function" then
        local info = debug.getinfo(1, "S")
        local src = type(info) == "table" and tostring(info.source or "") or ""
        if string.sub(src, 1, 1) == "@" then
            src = string.sub(src, 2)
        end
        src = string.gsub(src, "\\", "/")
        local dir = string.match(src, "^(.*)/[^/]+$")
        if dir ~= nil then
            local base = string.match(dir, "^(.*)/[^/]+$")
            if base ~= nil and base ~= "" then
                ADDONS_BASE_PATH = base
            end
        end
    end
end)

local function getFullPath(path)
    if ADDONS_BASE_PATH == nil or ADDONS_BASE_PATH == "" then
        return nil
    end
    local full = tostring(ADDONS_BASE_PATH) .. "/" .. tostring(path or "")
    return string.gsub(full, "/+", "/")
end

local function getFullPathCandidates(path)
    local rawPath = tostring(path or "")
    local candidates = {}
    local seen = {}

    local function add(candidate)
        if type(candidate) ~= "string" or candidate == "" then
            return
        end
        candidate = string.gsub(candidate, "/+", "/")
        if seen[candidate] then
            return
        end
        seen[candidate] = true
        table.insert(candidates, candidate)
    end

    add(getFullPath(rawPath))

    local addonDir = string.match(rawPath, "^([^/]+)/")
    if addonDir ~= nil and ADDONS_BASE_PATH ~= nil then
        local lowerBase = string.lower(tostring(ADDONS_BASE_PATH))
        local lowerAddonDir = "/" .. string.lower(addonDir)
        if string.sub(lowerBase, -string.len(lowerAddonDir)) == lowerAddonDir then
            local stripped = string.gsub(rawPath, "^" .. addonDir .. "/?", "")
            add(tostring(ADDONS_BASE_PATH) .. "/" .. stripped)
        end
    end

    return candidates
end

local function readTextFile(path)
    if type(io) ~= "table" or type(io.open) ~= "function" then
        return nil
    end
    for _, fullPath in ipairs(getFullPathCandidates(path)) do
        local file = nil
        local ok = pcall(function()
            file = io.open(fullPath, "rb")
        end)
        if ok and file ~= nil then
            local contents = nil
            pcall(function()
                contents = file:read("*a")
            end)
            pcall(function()
                file:close()
            end)
            if type(contents) == "string" and contents ~= "" then
                return contents
            end
        end
    end
    return nil
end

local function parseScalar(rawValue)
    local value = tostring(rawValue or "")
    value = string.match(value, "^%s*(.-)%s*$") or value
    if value == "" then
        return nil
    end
    if value == "true" then
        return true
    end
    if value == "false" then
        return false
    end
    local quoted = string.match(value, "^\"(.*)\"$")
    if quoted ~= nil then
        quoted = string.gsub(quoted, "\\\\", "\\")
        quoted = string.gsub(quoted, "\\\"", "\"")
        return quoted
    end
    return tonumber(value)
end

local function readFlatSettingsFile(path)
    local contents = readTextFile(path)
    if type(contents) ~= "string" then
        return nil
    end
    local out = {}
    for key, rawValue in string.gmatch(contents, "([%a_][%w_]*)%s*=%s*([^,\r\n}]+)") do
        local parsed = parseScalar(rawValue)
        if parsed ~= nil then
            out[key] = parsed
        end
    end
    if next(out) == nil then
        return nil
    end
    return out
end

local function encodeScalar(value)
    local valueType = type(value)
    if valueType == "boolean" then
        return value and "true" or "false"
    end
    if valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        local escaped = string.gsub(value, "\\", "\\\\")
        escaped = string.gsub(escaped, "\"", "\\\"")
        return "\"" .. escaped .. "\""
    end
    return nil
end

local function writeFlatSettingsFile(path, value)
    if type(value) ~= "table" or type(io) ~= "table" or type(io.open) ~= "function" then
        return false
    end
    local keys = {}
    for key, item in pairs(value) do
        if encodeScalar(item) ~= nil then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    local lines = { "{" }
    for _, key in ipairs(keys) do
        lines[#lines + 1] = "    " .. tostring(key) .. " = " .. encodeScalar(value[key]) .. ","
    end
    lines[#lines + 1] = "}"
    local payload = table.concat(lines, "\n")

    for _, fullPath in ipairs(getFullPathCandidates(path)) do
        local file = nil
        local ok = pcall(function()
            file = io.open(fullPath, "wb")
        end)
        if ok and file ~= nil then
            local writeOk = pcall(function()
                file:write(payload)
            end)
            pcall(function()
                file:close()
            end)
            if writeOk then
                return true
            end
        end
    end
    return false
end

local function readSerializedSettings(path)
    if api.File == nil or api.File.Read == nil then
        return nil
    end
    local ok, res = pcall(function()
        return api.File:Read(path)
    end)
    if ok and type(res) == "table" then
        return res
    end
    return nil
end

local function writeSerializedSettings(path, value)
    if api.File == nil or api.File.Write == nil then
        return false
    end
    local ok = pcall(function()
        api.File:Write(path, value)
    end)
    return ok and true or false
end

local function writeTableFile(path, value)
    if type(value) ~= "table" then
        return false
    end
    if writeFlatSettingsFile(path, value) then
        writeSerializedSettings(path, value)
        return true
    end
    if writeSerializedSettings(path, value) then
        return true
    end
    return false
end

local function hasTableFile(path)
    if type(readSerializedSettings(path)) == "table" then
        return true
    end
    if type(readFlatSettingsFile(path)) == "table" then
        return true
    end
    return false
end

local function copyDefaults(into, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(into[key]) ~= "table" then
                into[key] = {}
                changed = true
            end
            if copyDefaults(into[key], value) then
                changed = true
            end
        elseif into[key] == nil then
            into[key] = value
            changed = true
        end
    end
    return changed
end

function Shared.Trim(value)
    local text = tostring(value or "")
    return string.match(text, "^%s*(.-)%s*$") or text
end

function Shared.NormalizeDeltaMs(dt)
    local value = tonumber(dt) or 0
    if value < 0 then
        value = 0
    end
    if value > 0 and value < 5 then
        value = value * 1000
    end
    return value
end

function Shared.LoadSettings()
    local settings = nil
    local migrated = false
    local fileSettings = readSerializedSettings(Constants.SETTINGS_FILE_PATH)
    if type(fileSettings) ~= "table" then
        fileSettings = readFlatSettingsFile(Constants.SETTINGS_FILE_PATH)
    end
    if type(fileSettings) ~= "table" then
        fileSettings = readSerializedSettings(Constants.LEGACY_SETTINGS_FILE_PATH)
        if type(fileSettings) == "table" then
            migrated = true
        end
    end
    if type(fileSettings) ~= "table" then
        fileSettings = readFlatSettingsFile(Constants.LEGACY_SETTINGS_FILE_PATH)
        if type(fileSettings) == "table" then
            migrated = true
        end
    end
    if api.GetSettings ~= nil then
        settings = api.GetSettings(Constants.ADDON_ID)
    end
    if type(settings) ~= "table" then
        settings = {}
    end

    if type(fileSettings) == "table" then
        for key, value in pairs(fileSettings) do
            settings[key] = value
        end
    end

    Shared.settings = settings
    if copyDefaults(settings, Constants.DEFAULT_SETTINGS) or type(fileSettings) ~= "table" or migrated or not hasTableFile(Constants.SETTINGS_FILE_PATH) then
        Shared.SaveSettings()
    end
    return settings
end

function Shared.EnsureSettings()
    if Shared.settings == nil then
        return Shared.LoadSettings()
    end
    return Shared.settings
end

function Shared.SaveSettings()
    local settings = Shared.EnsureSettings()
    local saved = writeTableFile(Constants.SETTINGS_FILE_PATH, settings)
    local fallbackSaved = writeTableFile(Constants.LEGACY_SETTINGS_FILE_PATH, settings)
    if api.SaveSettings ~= nil then
        api.SaveSettings()
    end
    if not saved and not fallbackSaved and api.Log ~= nil and api.Log.Err ~= nil then
        pcall(function()
            api.Log:Err("Nuzi Vehicles failed to write settings file: " .. tostring(Constants.SETTINGS_FILE_PATH))
        end)
    end
    return saved or fallbackSaved
end

return Shared

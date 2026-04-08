local api = require("api")

local Adapter = {}

local function safeCall(fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return nil
end

-- Live game integration point:
-- Replace this if AA Classic exposes a more direct generic vehicle-speed API later.
function Adapter.GetVehicleSpeed()
    if api.SiegeWeapon == nil or api.SiegeWeapon.GetSiegeWeaponSpeed == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.SiegeWeapon:GetSiegeWeaponSpeed()
    end)) or 0
end

-- Live game integration point:
-- Replace this if a direct vehicle turn-rate or facing API appears later.
function Adapter.GetVehicleTurnSpeed()
    if api.SiegeWeapon == nil or api.SiegeWeapon.GetSiegeWeaponTurnSpeed == nil then
        return 0
    end
    return tonumber(safeCall(function()
        return api.SiegeWeapon:GetSiegeWeaponTurnSpeed()
    end)) or 0
end

-- Live game integration point:
-- Use player world position for generic running/mount/vehicle tracking.
function Adapter.GetPlayerWorldPosition()
    if api.Unit == nil or api.Unit.UnitWorldPosition == nil then
        return nil, nil, nil
    end
    local ok, x, y, z = pcall(function()
        return api.Unit:UnitWorldPosition("player")
    end)
    if not ok then
        return nil, nil, nil
    end
    return tonumber(x), tonumber(y), tonumber(z)
end

-- Live game integration point:
-- AA Classic world positions are exposed as x, y, z. For travel speed and
-- travel heading we want the horizontal plane. On this client that is x/y, and
-- using z introduces vertical jitter from terrain changes and jumping.
-- Fall back to x/z only if y is unavailable.
function Adapter.GetPlayerTravelPosition()
    local x, y, z = Adapter.GetPlayerWorldPosition()
    if x == nil then
        return nil, nil
    end
    if y ~= nil then
        return x, y
    end
    return x, z
end

-- Live game integration point:
-- Used to derive real movement speed from world-position deltas.
function Adapter.GetUiMsec()
    if api.Time == nil or api.Time.GetUiMsec == nil then
        return nil
    end
    return tonumber(safeCall(function()
        return api.Time:GetUiMsec()
    end))
end

-- Live game integration point:
-- AA Classic does not currently expose a reliable generic facing angle here,
-- so the controller falls back to travel direction when this returns nil.
function Adapter.GetPlayerHeading()
    if api.Unit ~= nil and api.Unit.GetUnitWorldPositionByTarget ~= nil then
        local playerAngle = safeCall(function()
            local _, _, _, angle = api.Unit:GetUnitWorldPositionByTarget("player", false)
            return angle
        end)
        if playerAngle ~= nil then
            return tonumber(playerAngle)
        end

        local slaveAngle = safeCall(function()
            local _, _, _, angle = api.Unit:GetUnitWorldPositionByTarget("slave", false)
            return angle
        end)
        if slaveAngle ~= nil then
            return tonumber(slaveAngle)
        end
    end
    return nil
end

function Adapter.GetCursorBagIndex()
    if api.Cursor == nil or api.Cursor.GetCursorPickedBagItemIndex == nil then
        return nil
    end
    return tonumber(safeCall(function()
        return api.Cursor:GetCursorPickedBagItemIndex()
    end))
end

function Adapter.GetBagItemInfo(index)
    if api.Bag == nil or api.Bag.GetBagItemInfo == nil then
        return nil
    end
    local info = safeCall(function()
        return api.Bag:GetBagItemInfo(1, tonumber(index) or 0)
    end)
    if type(info) ~= "table" then
        return nil
    end
    return info
end

function Adapter.UseBagItem(index)
    if api.Bag == nil or api.Bag.EquipBagItem == nil then
        return false
    end
    local ok = pcall(function()
        api.Bag:EquipBagItem(tonumber(index) or 0, false)
    end)
    return ok
end

function Adapter.ClearCursor()
    if api.Cursor ~= nil and api.Cursor.ClearCursor ~= nil then
        safeCall(function()
            api.Cursor:ClearCursor()
        end)
    end
end

return Adapter

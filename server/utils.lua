local utils = {}

function utils.InsideZone(playerCoords, zoneCoords, zoneRotation, zoneSize)
    ---@todo Consider adding targeted print to avoid config gaps
    if not playerCoords then
        return false
    end

    if not zoneCoords or not zoneRotation or not zoneSize then
        return false
    end

    local relative = playerCoords - zoneCoords
    local rad = math.rad(-zoneRotation)
    local cosH = math.cos(rad)
    local sinH = math.sin(rad)

    local localX = relative.x * cosH - relative.y * sinH
    local localY = relative.x * sinH + relative.y * cosH
    local localZ = relative.z

    local halfSize = zoneSize / 2

    return math.abs(localX) <= halfSize.x and math.abs(localY) <= halfSize.y and math.abs(localZ) <= halfSize.z
end

return utils
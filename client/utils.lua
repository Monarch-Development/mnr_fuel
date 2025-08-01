---@diagnostic disable: lowercase-global

local utils = {}

function utils.DeleteFuelEntities(nozzle, rope)
    DeleteObject(nozzle)
    RopeUnloadTextures()
    DeleteRope(rope)
end

function utils.InitFuelState(vehicle)
    local vehState = Entity(vehicle).state
    
    vehState:set("fuel", GetVehicleFuelLevel(vehicle), true)

    while not vehState.fuel do
        Wait(0)
    end
end

function utils.RotateOffset(offset, heading)
    local rad = math.rad(heading)
    local cosH = math.cos(rad)
    local sinH = math.sin(rad)

    local newX = offset.x * cosH - offset.y * sinH
    local newY = offset.x * sinH + offset.y * cosH

    return vec3(newX, newY, offset.z)
end

return utils
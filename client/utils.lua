---@diagnostic disable: lowercase-global

local utils = {}

function utils.InitFuelState(vehicle)
    local vehState = Entity(vehicle).state
    
    vehState:set('fuel', GetVehicleFuelLevel(vehicle), true)

    while not vehState.fuel do
        Wait(0)
    end
end

return utils
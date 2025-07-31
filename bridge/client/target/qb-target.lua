---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState("qb-target") ~= "started" then return end

local state = require "client.state"

target = {}

function target.AddGlobalVehicle()
    exports["qb-target"]:AddGlobalVehicle({
        options = {
            {
                label = locale("target.refuel-nozzle"),
                icon = "fas fa-gas-pump",
                canInteract = function()
                    return not state.refueling and (state.holding == "fv_nozzle" or state.holding == "ev_nozzle")
                end,
                action = function(entity)
                    TriggerEvent("mnr_fuel:client:RefuelVehicle", {entity = entity})
                end,
            },
            {
                label = locale("target.refuel-jerrycan"),
                icon = "fas fa-gas-pump",
                canInteract = function()
                    return not state.refueling and state.holding == "jerrycan"
                end,
                action = function(entity)
                    TriggerEvent("mnr_fuel:client:RefuelVehicleFromJerrycan", {entity = entity})
                end,
            },
        },
        distance = 1.5,
    })
end

function target.RemoveGlobalVehicle()
    exports["qb-target"]:RemoveGlobalVehicle(locale("target.insert-nozzle"))
end

function target.AddModel(model, isEV)
    exports["qb-target"]:AddTargetModel(model, {
        options = {
            {
                num = 1,
                label = locale(isEV and "target.take-charger" or "target.take-nozzle"),
                icon = isEV and "fas fa-bolt" or "fas fa-gas-pump",
                canInteract = function()
                    return not state.refueling and state.holding == "null"
                end,
                action = function(entity)
                    local pumpType = isEV and "ev" or "fv"
                    TriggerEvent("mnr_fuel:client:TakeNozzle", {entity = entity}, pumpType)
                end,
            },
            {
                num = 2,
                label = locale(isEV and "target.return-charger" or "target.return-nozzle"),
                icon = "fas fa-hand",
                canInteract = function()
                    return not state.refueling and (state.holding == "fv_nozzle" or state.holding == "ev_nozzle")
                end,
                action = function(entity)
                    local pumpType = isEV and "ev" or "fv"
                    TriggerEvent("mnr_fuel:client:ReturnNozzle", {entity = entity}, pumpType)
                end,
            },
            {
                num = 3,
                label = locale("target.buy-jerrycan"),
                icon = "fas fa-fire-flame-simple",
                canInteract = function()
                    return not state.refueling and (state.holding ~= "fv_nozzle" and state.holding ~= "ev_nozzle")
                end,
                action = function(entity)
                    TriggerEvent("mnr_fuel:client:BuyJerrycan", {entity = entity})
                end,
            },
        },
        distance = 3.0,
    })
end
---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState("ox_target") ~= "started" then return end

local state = require "client.state"

target = {}

function target.AddGlobalVehicle()
    exports.ox_target:addGlobalVehicle({
        {
            label = locale("target.refuel-nozzle"),
            name = "mnr_fuel:veh_option_1",
            icon = "fas fa-gas-pump",
            distance = 1.5,
            canInteract = function()
                return not state.refueling and (state.holding == "fv_nozzle" or state.holding == "ev_nozzle")
            end,
            event = "mnr_fuel:client:RefuelVehicle"
        },
        {
            label = locale("target.refuel-jerrycan"),
            name = "mnr_fuel:veh_option_2",
            icon = "fas fa-gas-pump",
            canInteract = function()
                return not state.refueling and state.holding == "jerrycan"
            end,
            event = "mnr_fuel:client:RefuelVehicleFromJerrycan"
        },
    })
end

function target.RemoveGlobalVehicle()
    exports.ox_target:removeGlobalVehicle("mnr_fuel:veh_option")
end

function target.AddModel(model, isEV)
    exports.ox_target:addModel(model, {
        {
            label = locale(isEV and "target.take-charger" or "target.take-nozzle"),
            name = "mnr_fuel:pump:option_1",
            icon = isEV and "fas fa-bolt" or "fas fa-gas-pump",
            distance = 3.0,
            canInteract = function()
                return not state.refueling and state.holding == "null"
            end,
            onSelect = function(data)
                local pumpType = isEV and "ev" or "fv"
                TriggerEvent("mnr_fuel:client:TakeNozzle", data, pumpType)
            end,
        },
        {
            label = locale(isEV and "target.return-charger" or "target.return-nozzle"),
            name = "mnr_fuel:pump:option_2",
            icon = "fas fa-hand",
            distance = 3.0,
            canInteract = function()
                return not state.refueling and (state.holding == "fv_nozzle" or state.holding == "ev_nozzle")
            end,
            onSelect = function(data)
                local pumpType = isEV and "ev" or "fv"
                TriggerEvent("mnr_fuel:client:ReturnNozzle", data, pumpType)
            end,
        },
        {
            label = locale("target.buy-jerrycan"),
            name = "mnr_fuel:pump:option_3",
            icon = "fas fa-fire-flame-simple",
            distance = 3.0,
            canInteract = function()
                return not state.refueling and (state.holding ~= "fv_nozzle" and state.holding ~= "ev_nozzle")
            end,
            onSelect = function(data)
                TriggerEvent("mnr_fuel:client:BuyJerrycan", data)
            end,
        },
    })
end
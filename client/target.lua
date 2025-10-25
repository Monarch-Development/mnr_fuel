local pumps = lib.load('config.pumps')

local state = require 'client.modules.state'

exports.ox_target:addGlobalVehicle({
    {
        label = locale('target.refuel'),
        name = 'mnr_fuel:vehicle:refuel',
        icon = 'fas fa-gas-pump',
        distance = 1.5,
        canInteract = function()
            return not state.refueling and state.holding ~= nil
        end,
		onSelect = function(data)
            TriggerEvent('mnr_fuel:client:RefuelVehicle', data)
        end,
    },
})

local function createTargetData(ev)
	return {
		{
    		label = locale(ev and 'target.take_charger' or 'target.take_nozzle'),
    		name = 'mnr_fuel:pump:option_1',
    		icon = ev and 'fas fa-bolt' or 'fas fa-gas-pump',
    		distance = 3.0,
    		canInteract = function()
    		    return not state.refueling and state.pump == 0 and not state:holdingItem('nozzle')
    		end,
    		onSelect = function(data)
    		    TriggerEvent('mnr_fuel:client:TakeNozzle', data, ev and 'ev' or 'fv')
    		end,
		},
		{
    		label = locale(ev and 'target.return_charger' or 'target.return_nozzle'),
    		name = 'mnr_fuel:pump:option_2',
    		icon = 'fas fa-hand',
    		distance = 3.0,
    		canInteract = function(entity)
    		    return not state.refueling and state.pump == entity and state:holdingItem('nozzle')
    		end,
    		onSelect = function(data)
    		    TriggerEvent('mnr_fuel:client:ReturnNozzle', data, ev and 'ev' or 'fv')
    		end,
		},
		{
		    label = locale('target.buy_jerrycan'),
		    name = 'mnr_fuel:pump:option_3',
		    icon = 'fas fa-fire-flame-simple',
		    distance = 3.0,
		    canInteract = function()
		        return not state.refueling and not state:holdingItem('nozzle')
		    end,
		    onSelect = function(data)
                TriggerEvent('mnr_fuel:client:BuyJerrican', data)
            end,
		},
	}
end

for model, data in pairs(pumps) do
	local targetData = createTargetData(data.cat == 'ev')
	exports.ox_target:addModel(model, targetData)
end
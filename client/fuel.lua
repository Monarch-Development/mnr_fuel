-- code by (https://github.com/overextended/ox_fuel)
-- with a little but unwanted simplification (https://github.com/overextended/ox_fuel/pull/110)

local utils = require 'client.modules.utils'

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(10.0)

local function setFuel(vehState, vehicle, amount, replicate)
    if not DoesEntityExist(vehicle) then return end

	SetVehicleFuelLevel(vehicle, amount)
	vehState:set('fuel', amount, replicate)
end

local function startFuelConsumption()
	local vehicle = cache.vehicle

	if not DoesVehicleUseFuel(vehicle) then return end

	local vehState = Entity(vehicle).state
	if not vehState.fuel then
		utils.initFuelState(vehicle)
	end

	SetVehicleFuelLevel(vehicle, vehState.fuel)

	local fuelTick = 0

	while cache.seat == -1 do
		if GetIsVehicleEngineRunning(vehicle) then
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(10.0)

			local fuelAmount = tonumber(vehState.fuel)
			local newFuel = GetVehicleFuelLevel(vehicle)
			if fuelAmount > 0 then
				if GetVehiclePetrolTankHealth(vehicle) < 700 then
					newFuel -= math.random(10, 20) * 0.01
				end

				if fuelAmount ~= newFuel then
					setFuel(vehState, vehicle, newFuel, fuelTick % 15 == 0)
					fuelTick = (fuelTick + 1) % 15
				end
			end
		else
			if not DoesEntityExist(vehicle) then return end
			SetFuelConsumptionRateMultiplier(0.0)
		end
		Wait(1000)
	end
	setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startFuelConsumption) end

lib.onCache('seat', function(seat)
    if seat == -1 then
        SetTimeout(0, startFuelConsumption)
    end
end)
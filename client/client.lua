local config = lib.load('config.config')
local utils = require 'client.utils'

local refueling = false
local holding = false
local FuelEntities = { nozzle = nil, rope = nil }

local function isHolding()
    return holding and type(holding) == 'table'
end

local function isHoldingNozzle()
    return isHolding() and holding.item == 'nozzle'
end

local function nozzleCat()
    return isHoldingNozzle() and holding.cat or nil
end

local function isHoldingJerrycan()
    return isHolding() and holding.item == 'jerrycan'
end

local function ropeLoop()
	local playerCoords = GetEntityCoords(cache.ped)
	while isHoldingNozzle() do
		local currentcoords = GetEntityCoords(cache.ped)
		local dist = #(playerCoords - currentcoords)
		if dist > 7.5 then
			holding = false
			utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)
		end
		Wait(1000)
	end
end

local function takeNozzle(data, pumpType)
	if not DoesEntityExist(data.entity) then return end
	if refueling or isHolding() then return end
	if not lib.callback.await('mnr_fuel:server:InStation') then return end

	lib.requestAnimDict('anim@am_hold_up@male', 300)
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, 'mnr_take_fv_nozzle', data.entity, 'mnr_fuel', true, 0)
	TaskPlayAnim(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	Wait(300)
	StopAnimTask(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 1.0)
	RemoveAnimDict('anim@am_hold_up@male')

	local pump = GetEntityModel(data.entity)
    local pumpCoords = GetEntityCoords(data.entity)
	local nozzleModel = config.nozzleType[pumpType].hash
	local handOffset = config.nozzleType[pumpType].offsets.hand
	local lefthand = GetPedBoneIndex(cache.ped, 18905)
	FuelEntities.nozzle = CreateObject(nozzleModel, 1.0, 1.0, 1.0, true, true, false)
	AttachEntityToEntity(FuelEntities.nozzle, cache.ped, lefthand, handOffset[1], handOffset[2], handOffset[3], handOffset[4], handOffset[5], handOffset[6], false, true, false, true, 0, true)

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
        RopeLoadTextures()
    end
	FuelEntities.rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, config.ropeType['fv'], 8.0, 0.0, 1.0, false, false, false, 1.0, true)
	while not FuelEntities.rope do
		Wait(0)
	end
	ActivatePhysics(FuelEntities.rope)
	Wait(100)

	local nozzlePos = GetEntityCoords(FuelEntities.nozzle)
	local nozzleOffset = config.nozzleType[pumpType].offsets.rope
	nozzlePos = GetOffsetFromEntityInWorldCoords(FuelEntities.nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z)
	local pumpHeading = GetEntityHeading(data.entity)
	local rotatedPumpOffset = utils.RotateOffset(config.pumps[pump].offset, pumpHeading)
	local newPumpCoords = pumpCoords + rotatedPumpOffset
	AttachEntitiesToRope(FuelEntities.rope, data.entity, FuelEntities.nozzle, newPumpCoords.x, newPumpCoords.y, newPumpCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

	holding = { item = 'nozzle', cat = pumpType }

	CreateThread(ropeLoop)
end

local function returnNozzle(data, pumpType)
	if refueling and not isHoldingNozzle() then return end

	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, ('mnr_return_%s_nozzle'):format(pumpType), data.entity, 'mnr_fuel', true, 0)
	holding = false
	Wait(250)
	utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)
end

local function inputDialog(jerrycan, bankMoney, cashMoney, fuel)
	local rows = {}

	rows[1] = {
		type = 'number',
		label = 'Price',
		default = jerrycan and config.jerrycanPrice or config.fuelPrice,
		icon = 'dollar-sign',
		disabled = true
	}
	rows[2] = {
		type = 'select',
		label = 'Select Payment Method',
		options = {
			{ value = 'bank', label = ('Bank (%d$)'):format(bankMoney) },
			{ value = 'cash', label = ('Cash (%d$)'):format(cashMoney) },
		},
	}

	if not jerrycan then
		rows[3] = {
			type = 'slider',
			label = locale('input.select-amount'),
			default = fuel,
			min = fuel,
			max = 100,
		}
	end

	return lib.inputDialog(locale('input.select-amount'), rows)
end

local function refuelVehicle(data)
    if not data.entity or refueling then return end

    local vehicle = data.entity
    if not DoesEntityExist(vehicle) then return end

    local vehState = Entity(vehicle).state
    if not vehState.fuel then
        utils.InitFuelState(vehicle)
    end

    if isHoldingJerrycan() then
        local netId = NetworkGetEntityIsNetworked(vehicle) and VehToNet(vehicle)
        TriggerServerEvent('mnr_fuel:server:RefuelVehicle', netId)
        return
    end

    if not lib.callback.await('mnr_fuel:server:InStation') then return end

    if refueling and not isHoldingNozzle() then return end

    local electric = GetIsVehicleElectric(GetEntityModel(vehicle))
    if not electric and nozzleCat() ~= 'fv' then
		client.Notify(locale('notify.not-ev'), 'error')
        return
    elseif electric and nozzleCat() ~= 'ev' then
        client.Notify(locale('notify.not-fv'), 'error')
        return
    end

    local fuel = math.ceil(vehState.fuel)

	local cashMoney, bankMoney = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
    local input = inputDialog(false, bankMoney, cashMoney, fuel)
    if not input then
		return
	end

	local method = input[2]
    local amount = tonumber(input[3]) - fuel
    if not amount or amount <= 0 then
		return
	end

	local netId = NetworkGetEntityIsNetworked(vehicle) and VehToNet(vehicle)
	TriggerServerEvent('mnr_fuel:server:ElaborateAction', 'fuel', method, amount, netId)
end

local function buyJerrycan(data)
	if not data.entity or refueling and not (holding ~= 'fv_nozzle' and holding ~= 'ev_nozzle') then
		return
	end

	if not lib.callback.await('mnr_fuel:server:InStation') then
		return
	end

	local cashMoney, bankMoney = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
	local input = inputDialog(true, bankMoney, cashMoney)
	if not input then
		return
	end

	local method = input[2]
	TriggerServerEvent('mnr_fuel:server:ElaborateAction', 'jerrycan', method)
end

RegisterNetEvent('mnr_fuel:client:PlayRefuelAnim', function(data, isPump)
	if isPump and not isHoldingNozzle() then return end
	if not isPump and not isHoldingJerrycan() then return end

	local vehicle = NetToVeh(data.netId)

	TaskTurnPedToFaceEntity(cache.ped, vehicle, 500)
	Wait(500)

	refueling = true

	local refuelTime = data.amount * 2000
	local pumpType = nozzleCat()
	local soundId = GetSoundId()
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(soundId, ('mnr_%s_start'):format(pumpType), FuelEntities.nozzle, 'mnr_fuel', true, 0)

	if lib.progressCircle({
		duration = refuelTime,
		label = locale('progress.refueling-vehicle'),
		position = 'bottom',
		useWhileDead = false,
		canCancel = false,
		anim = {
			dict = isPump and 'timetable@gardener@filling_can' or 'weapon@w_sp_jerrycan',
			clip = isPump and 'gar_ig_5_filling_can' or 'fire',
		},
		disable = {move = true, car = true, combat = true},
	}) then
		StopSound(soundId)
		ReleaseSoundId(soundId)
		PlaySoundFromEntity(-1, ('mnr_%s_stop'):format(pumpType), FuelEntities.nozzle, 'mnr_fuel', true, 0)
		refueling = false
		client.Notify(locale('notify.refuel-success'), 'success')
	end
end)

lib.onCache('weapon', function(weapon)
    if weapon ~= `WEAPON_PETROLCAN` and holding ~= false then
        holding = false
    elseif weapon == `WEAPON_PETROLCAN` then
        holding = { item = 'jerrycan' }
    end
end)

local function createTargetData(ev)
	return {
		{
    		label = locale(ev and 'target.take-charger' or 'target.take-nozzle'),
    		name = 'mnr_fuel:pump:option_1',
    		icon = ev and 'fas fa-bolt' or 'fas fa-gas-pump',
    		distance = 3.0,
    		canInteract = function()
    		    return not refueling and not isHoldingNozzle()
    		end,
    		onSelect = function(data)
    		    takeNozzle(data, ev and 'ev' or 'fv')
    		end,
		},
		{
    		label = locale(ev and 'target.return-charger' or 'target.return-nozzle'),
    		name = 'mnr_fuel:pump:option_2',
    		icon = 'fas fa-hand',
    		distance = 3.0,
    		canInteract = function()
    		    return not refueling and isHoldingNozzle()
    		end,
    		onSelect = function(data)
    		    returnNozzle(data, ev and 'ev' or 'fv')
    		end,
		},
		{
		    label = locale('target.buy-jerrycan'),
		    name = 'mnr_fuel:pump:option_3',
		    icon = 'fas fa-fire-flame-simple',
		    distance = 3.0,
		    canInteract = function()
		        return not refueling and not isHoldingNozzle()
		    end,
		    onSelect = buyJerrycan,
		},
	}
end

exports.ox_target:addGlobalVehicle({
    {
        label = locale('target.refuel'),
        name = 'mnr_fuel:vehicle:refuel',
        icon = 'fas fa-gas-pump',
        distance = 1.5,
        canInteract = function()
            return not refueling and holding ~= false
        end,
		onSelect = refuelVehicle,
    },
})

for model, data in pairs(config.pumps) do
	local targetData = createTargetData(data.type == 'ev')

	exports.ox_target:addModel(model, targetData)
end

AddEventHandler('onResourceStop', function(resourceName)
	local scriptName = cache.resource or GetCurrentResourceName()
	if resourceName ~= scriptName then return end

	utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)

	exports.ox_target:removeGlobalVehicle('mnr_fuel:vehicle:refuel')
end)
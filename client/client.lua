local config = lib.load('config.config')
local utils = require 'client.utils'

local refueling = false
local holding = false
local Entities = { nozzle = nil, rope = nil }

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
			utils.DeleteFuelEntities(Entities.nozzle, Entities.rope)
		end
		Wait(1000)
	end
end

---@param cat <string> Category of the pump/nozzle
local function takeNozzle(data, cat)
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

	local hand = config.nozzleType[cat].offsets.hand
	local bone = GetPedBoneIndex(cache.ped, 18905)
	Entities.nozzle = CreateObject(config.nozzleType[cat].nozzle, 1.0, 1.0, 1.0, true, true, false)
	AttachEntityToEntity(Entities.nozzle, cache.ped, bone, hand[1], hand[2], hand[3], hand[4], hand[5], hand[6], false, true, false, true, 0, true)

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
        RopeLoadTextures()
    end

	local pumpCoords = GetEntityCoords(data.entity)
	Entities.rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, config.ropeType['fv'], 8.0, 0.0, 1.0, false, false, false, 1.0, true)

	while not Entities.rope do
		Wait(0)
	end
	ActivatePhysics(Entities.rope)
	Wait(100)

	local nozzleOffset = config.nozzleType[cat].offsets.rope
	local nozzlePos = GetOffsetFromEntityInWorldCoords(Entities.nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z)
	
	local heading = GetEntityHeading(data.entity)
	local hash = GetEntityModel(data.entity)
	local rotatedPumpOffset = utils.RotateOffset(config.pumps[hash].offset, heading)
	local coords = pumpCoords + rotatedPumpOffset
	AttachEntitiesToRope(Entities.rope, data.entity, Entities.nozzle, coords.x, coords.y, coords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

	holding = { item = 'nozzle', cat = cat }

	CreateThread(ropeLoop)
end

local function returnNozzle(data, cat)
	if refueling and not isHoldingNozzle() then return end

	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, ('mnr_return_%s_nozzle'):format(cat), data.entity, 'mnr_fuel', true, 0)
	holding = false
	Wait(250)
	utils.DeleteFuelEntities(Entities.nozzle, Entities.rope)
end

local function inputDialog(jerrycan, bankMoney, cashMoney, fuel)
	local rows = {}

	rows[1] = {
		type = 'number',
		label = locale('input.price'),
		default = jerrycan and config.jerrycanPrice or config.fuelPrice,
		icon = 'dollar-sign',
		disabled = true
	}
	rows[2] = {
		type = 'select',
		label = locale('input.payment_method'),
		options = {
			{ value = 'bank', label = locale('input.bank', bankMoney) },
			{ value = 'cash', label = locale('input.cash', cashMoney) },
		},
	}

	if not jerrycan then
		rows[3] = {
			type = 'slider',
			label = locale('input.select_amount'),
			default = fuel,
			min = fuel,
			max = 100,
		}
	end

	return lib.inputDialog(locale('input.title'), rows)
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
	if not DoesEntityExist(data.entity) then return end
	if refueling or isHoldingNozzle() then return end

	if not lib.callback.await('mnr_fuel:server:InStation') then return end

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
	local cat = nozzleCat()
	local soundId = GetSoundId()
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(soundId, ('mnr_%s_start'):format(cat), Entities.nozzle, 'mnr_fuel', true, 0)

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
		PlaySoundFromEntity(-1, ('mnr_%s_stop'):format(cat), Entities.nozzle, 'mnr_fuel', true, 0)
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

	utils.DeleteFuelEntities(Entities.nozzle, Entities.rope)

	exports.ox_target:removeGlobalVehicle('mnr_fuel:vehicle:refuel')
end)
local config = lib.load('config.config')
local nozzles = require 'config.nozzles'
local pumps = require 'config.pumps'
local utils = require 'client.utils'

local refueling = false
local holding = { item = nil, cat = nil }
local Entities = { nozzle = nil }
local RopesRegistry = {}

local function holdingItem(item)
    return type(holding) == 'table' and holding.item == item
end

local function nozzleCat()
    return holdingItem('nozzle') and holding.cat or nil
end

local function rotateOffset(offset, heading)
    local rad = math.rad(heading)
    local cosH = math.cos(rad)
    local sinH = math.sin(rad)

    local newX = offset.x * cosH - offset.y * sinH
    local newY = offset.x * sinH + offset.y * cosH

    return vec3(newX, newY, offset.z)
end

local function deleteEntities(nozzle)
    DeleteObject(nozzle)
end

AddStateBagChangeHandler('used', nil, function(bagName, _, value, _, replicated)
	if not replicated then return end

    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) then return end

    if value == nil and RopesRegistry[entity] and DoesRopeExist(RopesRegistry[entity]) then
		DeleteRope(RopesRegistry[entity])
		RopeUnloadTextures()
        RopesRegistry[entity] = nil
		return
    end

	if not RopeAreTexturesLoaded() then
		RopeLoadTextures()
		while not RopeAreTexturesLoaded() do
			Wait(0)
		end
	end

	Wait(100)

	local pumpCoords = GetEntityCoords(entity)
	local rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, 1, 8.0, 0.0, 1.0, false, false, false, 1.0, true)

	while not DoesRopeExist(rope) do
		Wait(0)
	end

	RopesRegistry[entity] = rope
	ActivatePhysics(rope)

	local hash = GetEntityModel(entity)
	local cat = pumps[hash].cat
	local pumpOffset = pumps[hash].offset
	local nozzle = NetworkGetEntityFromNetworkId(value)
	local offset = nozzles[cat].offsets.rope
	local nozzleCoords = GetOffsetFromEntityInWorldCoords(nozzle, offset.x, offset.y, offset.z)
	local heading = GetEntityHeading(entity)
	local rotatedPumpOffset = rotateOffset(pumpOffset, heading)
	local coords = pumpCoords + rotatedPumpOffset

	AttachEntitiesToRope(rope, entity, nozzle, coords.x, coords.y, coords.z, nozzleCoords.x, nozzleCoords.y, nozzleCoords.z, 8.0, false, false, nil, nil)
end)

local function takeNozzle(data, cat)
	if not DoesEntityExist(data.entity) then return end
	if refueling or holdingItem('nozzle') or holdingItem('jerrycan') then return end
	if not lib.callback.await('mnr_fuel:server:InStation') then return end

	if Entity(data.entity).state.used then return end

	lib.requestAnimDict('anim@am_hold_up@male', 300)
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, 'mnr_take_fv_nozzle', data.entity, 'mnr_fuel', true, 0)
	TaskPlayAnim(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, false, false, false)
	Wait(300)
	StopAnimTask(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 1.0)
	RemoveAnimDict('anim@am_hold_up@male')

	local hand = nozzles[cat].offsets.hand
	local bone = GetPedBoneIndex(cache.ped, 18905)
	Entities.nozzle = CreateObject(nozzles[cat].nozzle, 1.0, 1.0, 1.0, true, true, false)
	NetworkRegisterEntityAsNetworked(Entities.nozzle)

	AttachEntityToEntity(Entities.nozzle, cache.ped, bone, hand[1], hand[2], hand[3], hand[4], hand[5], hand[6], false, true, false, true, 0, true)

	if NetworkGetEntityIsLocal(data.entity) then
		NetworkRegisterEntityAsNetworked(data.entity)
	end

	local nozzle = NetworkGetEntityIsNetworked(Entities.nozzle) and NetworkGetNetworkIdFromEntity(Entities.nozzle)
	Entity(data.entity).state:set('used', nozzle, true)

	holding = { item = 'nozzle', cat = cat }

	CreateThread(function()
		local playerCoords = GetEntityCoords(cache.ped)
		while holdingItem('nozzle') do
			local currentcoords = GetEntityCoords(cache.ped)
			local distance = #(playerCoords - currentcoords)
			if distance > 7.5 then
				Entity(data.entity).state:set('used', nil, true)
				holding = { item = nil, cat = nil }
				deleteEntities(Entities.nozzle)
				NetworkUnregisterNetworkedEntity(data.entity)
			end
			Wait(1000)
		end
	end)
end

local function returnNozzle(data, cat)
	if refueling and not holdingItem('nozzle') then return end

	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, ('mnr_return_%s_nozzle'):format(cat), data.entity, 'mnr_fuel', true, 0)

	Entity(data.entity).state:set('used', nil, true)
	holding = { item = nil, cat = nil }
	deleteEntities(Entities.nozzle)
	NetworkUnregisterNetworkedEntity(data.entity)
end

local function inputDialog(jerrycan, cash, bank, fuel)
	local rows = {
		{
			type = 'number',
			label = locale('input.price'),
			default = jerrycan and config.jerrycanPrice or config.fuelPrice,
			icon = 'dollar-sign',
			disabled = true
		},
		{
			type = 'select',
			label = locale('input.payment_method'),
			options = {
				{ value = 'bank', label = locale('input.bank', bank) },
				{ value = 'cash', label = locale('input.cash', cash) },
			},
			required = true,
			default = 'bank',
		},
	}

	if not jerrycan then
		rows[#rows + 1] = {
			type = 'slider',
			label = locale('input.select_amount'),
			required = true,
			default = fuel,
			min = fuel,
			max = 100,
		}
	end

	return lib.inputDialog(locale('input.title'), rows)
end

local function playAnim(data)
	if data.action == 'fuel' and not holdingItem('nozzle') then return end
	if data.action == 'jerrycan' and not holdingItem('jerrycan') then return end

	TaskTurnPedToFaceEntity(cache.ped, data.vehicle, 500)
	Wait(500)

	refueling = true

	local cat = nozzleCat()
	local soundId = GetSoundId()
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(soundId, ('mnr_%s_start'):format(cat), Entities.nozzle, 'mnr_fuel', true, 0)

	local function stopAnim()
		StopSound(soundId)
		ReleaseSoundId(soundId)
		PlaySoundFromEntity(-1, ('mnr_%s_stop'):format(cat), Entities.nozzle, 'mnr_fuel', true, 0)
		refueling = false
		client.Notify(locale('notify.refuel_success'), 'success')
	end

	local animDict = data.action == 'fuel' and 'timetable@gardener@filling_can' or data.action == 'jerrycan' and 'weapon@w_sp_jerrycan'
	local animClip = data.action == 'fuel' and 'gar_ig_5_filling_can' or data.action == 'jerrycan' and 'fire'

	local netId = NetworkGetEntityIsNetworked(data.vehicle) and VehToNet(data.vehicle)

	if lib.progressCircle({
		duration = (data.amount or 30) * config.refuelTime,
		label = locale('progress.refueling_vehicle'),
		position = 'bottom',
		useWhileDead = false,
		canCancel = true,
		anim = { dict = animDict, clip = animClip },
		disable = { move = true, car = true, combat = true },
	}) then
		stopAnim()
		TriggerServerEvent('mnr_fuel:server:RefuelVehicle', data.action, netId, { amount = data.amount, method = data.method })
	else
		stopAnim()
		TriggerServerEvent('mnr_fuel:server:RefuelVehicle', data.action, netId, { amount = data.amount, method = data.method })
	end
end

local function refuelVehicle(data)
    local vehicle = data.entity
    if not DoesEntityExist(vehicle) or refueling then return end

    local vehState = Entity(vehicle).state
    if not vehState.fuel then
        utils.InitFuelState(vehicle)
    end

	if holdingItem('jerrycan') then
		playAnim({ action = 'jerrycan', vehicle = vehicle, amount = amount })
		return
	end

    if not lib.callback.await('mnr_fuel:server:InStation') then return end
    if refueling and not holdingItem('nozzle') then return end

    local electric = GetIsVehicleElectric(GetEntityModel(vehicle))
	if (electric and nozzleCat() ~= 'ev') or (not electric and nozzleCat() ~= 'fv') then
		client.Notify(electric and locale('notify.not_fv') or locale('notify.not_ev'), 'error')
		return
	end

    local fuel = math.ceil(vehState.fuel)

	local cash, bank = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
    local input = inputDialog(false, cash, bank, fuel)
    if not input then return end

	local method = input[2]
    local amount = tonumber(input[3]) - fuel
    if not amount or amount <= 0 then return end

	playAnim({ action = 'fuel', vehicle = vehicle, method = method, amount = amount })
end

lib.onCache('weapon', function(weapon)
    if weapon ~= `WEAPON_PETROLCAN` and holding ~= false then
        holding = { item = nil, cat = nil }
    elseif weapon == `WEAPON_PETROLCAN` then
        holding = { item = 'jerrycan' }
    end
end)

local function buyJerrycan(data)
	if not DoesEntityExist(data.entity) then return end
	if refueling or holdingItem('nozzle') then return end
	if not lib.callback.await('mnr_fuel:server:InStation') then return end

	local cash, bank = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
	local input = inputDialog(true, cash, bank)
	if not input then return end

	local method = input[2]
	TriggerServerEvent('mnr_fuel:server:JerrycanPurchase', method)
end

local function createTargetData(ev)
	return {
		{
    		label = locale(ev and 'target.take_charger' or 'target.take_nozzle'),
    		name = 'mnr_fuel:pump:option_1',
    		icon = ev and 'fas fa-bolt' or 'fas fa-gas-pump',
    		distance = 3.0,
    		canInteract = function()
    		    return not refueling and not holdingItem('nozzle')
    		end,
    		onSelect = function(data)
    		    takeNozzle(data, ev and 'ev' or 'fv')
    		end,
		},
		{
    		label = locale(ev and 'target.return_charger' or 'target.return_nozzle'),
    		name = 'mnr_fuel:pump:option_2',
    		icon = 'fas fa-hand',
    		distance = 3.0,
    		canInteract = function()
    		    return not refueling and holdingItem('nozzle')
    		end,
    		onSelect = function(data)
    		    returnNozzle(data, ev and 'ev' or 'fv')
    		end,
		},
		{
		    label = locale('target.buy_jerrycan'),
		    name = 'mnr_fuel:pump:option_3',
		    icon = 'fas fa-fire-flame-simple',
		    distance = 3.0,
		    canInteract = function()
		        return not refueling and not holdingItem('nozzle')
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

	deleteEntities(Entities.nozzle)

	exports.ox_target:removeGlobalVehicle('mnr_fuel:vehicle:refuel')
end)
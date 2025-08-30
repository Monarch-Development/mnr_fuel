local config = lib.load('config.config')
local utils = require 'client.utils'

---@description ENTITIES (INTERACTION)
local refueling = false
local holding = false
local Entities = { nozzle = nil, rope = nil }

---@description HELPERS (INTERACTION)
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

local function rotateOffset(offset, heading)
    local rad = math.rad(heading)
    local cosH = math.cos(rad)
    local sinH = math.sin(rad)

    local newX = offset.x * cosH - offset.y * sinH
    local newY = offset.x * sinH + offset.y * cosH

    return vec3(newX, newY, offset.z)
end

local function deleteEntities(nozzle, rope)
    DeleteObject(nozzle)
    RopeUnloadTextures()
    DeleteRope(rope)
end

---@description SECURE ROPE UNLOAD LOOP (INTERACTION)
local function ropeLoop()
	local playerCoords = GetEntityCoords(cache.ped)
	while isHoldingNozzle() do
		local currentcoords = GetEntityCoords(cache.ped)
		local dist = #(playerCoords - currentcoords)
		if dist > 7.5 then
			holding = false
			deleteEntities(Entities.nozzle, Entities.rope)
		end
		Wait(1000)
	end
end

---@description TARGET FUNCTIONS (INTERACTION)
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

	local pump = GetEntityCoords(data.entity)
	Entities.rope = AddRope(pump.x, pump.y, pump.z, 0.0, 0.0, 0.0, 3.0, config.ropeType['fv'], 8.0, 0.0, 1.0, false, false, false, 1.0, true)

	while not Entities.rope do
		Wait(0)
	end
	ActivatePhysics(Entities.rope)
	Wait(100)

	local offset = config.nozzleType[cat].offsets.rope
	local nozzle = GetOffsetFromEntityInWorldCoords(Entities.nozzle, offset.x, offset.y, offset.z)
	
	local heading = GetEntityHeading(data.entity)
	local hash = GetEntityModel(data.entity)
	local rotatedPumpOffset = rotateOffset(config.pumps[hash].offset, heading)
	local coords = pump + rotatedPumpOffset
	AttachEntitiesToRope(Entities.rope, data.entity, Entities.nozzle, coords.x, coords.y, coords.z, nozzle.x, nozzle.y, nozzle.z, length, false, false, nil, nil)

	holding = { item = 'nozzle', cat = cat }

	CreateThread(ropeLoop)
end

local function returnNozzle(data, cat)
	if refueling and not isHoldingNozzle() then return end

	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(-1, ('mnr_return_%s_nozzle'):format(cat), data.entity, 'mnr_fuel', true, 0)
	holding = false
	Wait(250)
	deleteEntities(Entities.nozzle, Entities.rope)
end

local function inputDialog(jerrycan, cash, bank, fuel)
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
			{ value = 'bank', label = locale('input.bank', bank) },
			{ value = 'cash', label = locale('input.cash', cash) },
		},
		required = true,
	}

	if not jerrycan then
		rows[3] = {
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
	if data.action == 'fuel' and not isHoldingNozzle() then return end
	if data.action == 'jerrycan' and not isHoldingJerrycan() then return end

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

	if isHoldingJerrycan() then
		playAnim({ action = 'jerrycan', vehicle = vehicle, amount = amount })
		return
	end

    if not lib.callback.await('mnr_fuel:server:InStation') then return end

    if refueling and not isHoldingNozzle() then return end

    local electric = GetIsVehicleElectric(GetEntityModel(vehicle))
    if not electric and nozzleCat() ~= 'fv' then
		client.Notify(locale('notify.not_ev'), 'error')
        return
    elseif electric and nozzleCat() ~= 'ev' then
        client.Notify(locale('notify.not_fv'), 'error')
        return
    end

    local fuel = math.ceil(vehState.fuel)

	local cash, bank = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
    local input = inputDialog(false, cash, bank, fuel)
    if not input then return end

	local method = input[2]
    local amount = tonumber(input[3]) - fuel
    if not amount or amount <= 0 then
		return
	end

	playAnim({ action = 'fuel', vehicle = vehicle, method = method, amount = amount })
end

lib.onCache('weapon', function(weapon)
    if weapon ~= `WEAPON_PETROLCAN` and holding ~= false then
        holding = false
    elseif weapon == `WEAPON_PETROLCAN` then
        holding = { item = 'jerrycan' }
    end
end)

local function buyJerrycan(data)
	if not DoesEntityExist(data.entity) then
		return
	end

	if refueling or isHoldingNozzle() then
		return
	end

	if not lib.callback.await('mnr_fuel:server:InStation') then
		return
	end

	local cash, bank = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
	local input = inputDialog(true, cash, bank)
	
	if not input then
		return
	end

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
    		    return not refueling and not isHoldingNozzle()
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
    		    return not refueling and isHoldingNozzle()
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

	deleteEntities(Entities.nozzle, Entities.rope)

	exports.ox_target:removeGlobalVehicle('mnr_fuel:vehicle:refuel')
end)
---@description Config loading
local config = require 'config.config'
local nozzles = require 'config.nozzles'
local pumps = require 'config.pumps'

---@description Utilities loading
local state = require 'client.modules.state'
local utils = require 'client.modules.utils'

---@description Memory variables
local Nozzle = 0
local Rope = 0

lib.requestAudioBank('audiodirectory/mnr_fuel')

AddEventHandler('mnr_fuel:client:TakeNozzle', function(data, cat)
	if not DoesEntityExist(data.entity) then return end
	if state.refueling or state:holdingItem('nozzle') or state:holdingItem('jerrycan') then return end
	if not lib.callback.await('mnr_fuel:server:InStation') then return end

	state:set('pump', data.entity)

	lib.requestAnimDict('anim@am_hold_up@male', 300)

	PlaySoundFromEntity(-1, 'mnr_take_fv_nozzle', data.entity, 'mnr_fuel', true, 0)
	TaskPlayAnim(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 2.0, 8.0, -1, 50, 0, false, false, false)
	Wait(300)
	StopAnimTask(cache.ped, 'anim@am_hold_up@male', 'shoplift_high', 1.0)

	RemoveAnimDict('anim@am_hold_up@male')

	local hash = nozzles[cat].nozzle
	local hand = nozzles[cat].offsets.hand
	local bone = GetPedBoneIndex(cache.ped, 18905)

	local nozzle = CreateObject(hash, 1.0, 1.0, 1.0, true, true, false)
	AttachEntityToEntity(nozzle, cache.ped, bone, hand[1], hand[2], hand[3], hand[4], hand[5], hand[6], false, true, false, true, 0, true)

	Nozzle = nozzle

    RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
        Wait(0)
        RopeLoadTextures()
    end

	local pumpCoords = GetEntityCoords(data.entity)
	local rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, 1, 8.0, 0.0, 1.0, false, false, false, 1.0, true)

	while not rope do
		Wait(0)
	end

	Rope = rope

	ActivatePhysics(rope)
	Wait(100)

	local nozzleOffset = nozzles[cat].offsets.rope
	local nozzlePos = GetOffsetFromEntityInWorldCoords(nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z)
	local pumpHeading = GetEntityHeading(data.entity)
	local pump = GetEntityModel(data.entity)
	local rotatedPumpOffset = utils.rotateOffset(pumps[pump].offset, pumpHeading)
	local coords = pumpCoords + rotatedPumpOffset
	AttachEntitiesToRope(rope, data.entity, nozzle, coords.x, coords.y, coords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

	state:set('holding', { item = 'nozzle', cat = cat })

	CreateThread(function()
		while state:holdingItem('nozzle') do
			local currentCoords = GetEntityCoords(cache.ped)
			local distance = #(pumpCoords - currentCoords)
			if distance > 7.5 then
				DeleteEntity(nozzle)
				Nozzle = 0

				DeleteRope(rope)
				RopeUnloadTextures()
				Rope = 0

				state:set('pump', 0)
				state:set('holding', nil)
			end
			Wait(1000)
		end
	end)
end)

AddEventHandler('mnr_fuel:client:ReturnNozzle', function(data, cat)
	if state.refueling and not state:holdingItem('nozzle') then return end

	PlaySoundFromEntity(-1, ('mnr_return_%s_nozzle'):format(cat), data.entity, 'mnr_fuel', true, 0)

	Wait(250)

	DeleteEntity(Nozzle)
	Nozzle = 0
	DeleteRope(Rope)
	RopeUnloadTextures()
	Rope = 0

	state:set('pump', 0)
	state:set('holding', nil)
end)

local function inputDialog(jerrycan, cash, bank, fuel)
	local rows = {
		{
			type = 'number',
			label = locale('input_price'),
			default = jerrycan and config.jerrycanPrice or config.fuelPrice,
			icon = 'dollar-sign',
			disabled = true
		},
		{
			type = 'select',
			label = locale('input_method'),
			options = {
				{ value = 'bank', label = locale('input_bank', bank) },
				{ value = 'cash', label = locale('input_cash', cash) },
			},
			required = true,
			default = 'bank',
		},
	}

	if not jerrycan then
		rows[#rows + 1] = {
			type = 'slider',
			label = locale('input_amount'),
			required = true,
			default = fuel,
			min = fuel,
			max = 100,
		}
	end

	return lib.inputDialog(locale('input_title'), rows)
end

local function playAnim(data)
	if data.action == 'fuel' and not state:holdingItem('nozzle') then return end
	if data.action == 'jerrycan' and not state:holdingItem('jerrycan') then return end

	TaskTurnPedToFaceEntity(cache.ped, data.vehicle, 500)
	Wait(500)

	state:set('refueling', true)

	local cat = state:nozzleCat()
	local soundId = GetSoundId()
	lib.requestAudioBank('audiodirectory/mnr_fuel')
	PlaySoundFromEntity(soundId, ('mnr_%s_start'):format(cat), cache.ped, 'mnr_fuel', true, 0)

	local function stopAnim()
		StopSound(soundId)
		ReleaseSoundId(soundId)
		PlaySoundFromEntity(-1, ('mnr_%s_stop'):format(cat), cache.ped, 'mnr_fuel', true, 0)
		state:set('refueling', false)
		framework.Notify(locale('notify_refuel_success'), 'success')
	end

	local animDict = data.action == 'fuel' and 'timetable@gardener@filling_can' or data.action == 'jerrycan' and 'weapon@w_sp_jerrycan'
	local animClip = data.action == 'fuel' and 'gar_ig_5_filling_can' or data.action == 'jerrycan' and 'fire'

	local netId = NetworkGetEntityIsNetworked(data.vehicle) and VehToNet(data.vehicle)

	if lib.progressCircle({
		duration = (data.amount or 30) * config.refuelTime,
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

AddEventHandler('mnr_fuel:client:RefuelVehicle', function(data)
    local vehicle = data.entity
    if not DoesEntityExist(vehicle) or state.refueling then return end

    local vehState = Entity(vehicle).state
    if not vehState.fuel then
        utils.initFuelState(vehicle)
    end

	if state:holdingItem('jerrycan') then
		playAnim({ action = 'jerrycan', vehicle = vehicle, amount = amount })
		return
	end

    if not lib.callback.await('mnr_fuel:server:InStation') then return end
    if state.refueling and not state:holdingItem('nozzle') then return end

    local electric = GetIsVehicleElectric(GetEntityModel(vehicle))
	if (electric and state:nozzleCat() ~= 'ev') or (not electric and state:nozzleCat() ~= 'fv') then
		framework.Notify(electric and locale('notify_not_fv') or locale('notify_not_ev'), 'error')
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
end)

AddEventHandler('mnr_fuel:client:BuyJerrican', function(data)
	if not DoesEntityExist(data.entity) then return end
	if state.refueling or state:holdingItem('nozzle') then return end
	if not lib.callback.await('mnr_fuel:server:InStation') then return end

	local cash, bank = lib.callback.await('mnr_fuel:server:GetPlayerMoney', false)
	local input = inputDialog(true, cash, bank)
	if not input then return end

	local method = input[2]
	TriggerServerEvent('mnr_fuel:server:JerrycanPurchase', method)
end)

---@description DYNAMIC FEATURES
lib.onCache('weapon', function(weapon)
    if weapon ~= `WEAPON_PETROLCAN` and state.holding ~= nil then
        state:set('holding', nil)
    elseif weapon == `WEAPON_PETROLCAN` then
        state:set('holding', { item = 'jerrycan' })
    end
end)

---@description INITIALIZATION
state:init()

AddEventHandler('onResourceStop', function(name)
    if name ~= cache.resource then return end

	if DoesEntityExist(Nozzle) then
		DeleteEntity(Nozzle)
	end

	if DoesRopeExist(Rope) then
		DeleteRope(Rope)
		RopeUnloadTextures()
	end

	ReleaseScriptAudioBank()

    exports.ox_target:removeGlobalVehicle('mnr_fuel:vehicle:refuel')
end)
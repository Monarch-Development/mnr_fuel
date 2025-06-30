local config = lib.load("config.config")
local stations = lib.load("config.stations")
local utils = require "client.utils"
local state = require "client.state"

local Blips = {}
local FuelEntities = {nozzle = nil, rope = nil}

---@description TARGET EVENTS
RegisterNetEvent("mnr_fuel:client:TakeNozzle", function(data, pumpType)
	if not data.entity or state.refueling and not state.holding == "null" then return end
	if not lib.callback.await("mnr_fuel:server:InStation") then return end

	lib.requestAnimDict("anim@am_hold_up@male", 300)
	lib.requestAudioBank("audiodirectory/mnr_fuel")
	PlaySoundFromEntity(-1, "mnr_take_fv_nozzle", data.entity, "mnr_fuel", true, 0)
	TaskPlayAnim(cache.ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	Wait(300)
	StopAnimTask(cache.ped, "anim@am_hold_up@male", "shoplift_high", 1.0)
	RemoveAnimDict("anim@am_hold_up@male")

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
	FuelEntities.rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, config.ropeType["fv"], 8.0 --[[ DON'T SET TO 0.0!!! GAME CRASH!]], 0.0, 1.0, false, false, false, 1.0, true)
	while not FuelEntities.rope do
		Wait(0)
	end
	ActivatePhysics(FuelEntities.rope)
	Wait(100)

	local playerCoords = GetEntityCoords(cache.ped)
	local nozzlePos = GetEntityCoords(FuelEntities.nozzle)
	local nozzleOffset = config.nozzleType[pumpType].offsets.rope
	nozzlePos = GetOffsetFromEntityInWorldCoords(FuelEntities.nozzle, nozzleOffset.x, nozzleOffset.y, nozzleOffset.z)
	local pumpHeading = GetEntityHeading(data.entity)
	local rotatedPumpOffset = utils.RotateOffset(config.pumps[pump].offset, pumpHeading)
	local newPumpCoords = pumpCoords + rotatedPumpOffset
	AttachEntitiesToRope(FuelEntities.rope, data.entity, FuelEntities.nozzle, newPumpCoords.x, newPumpCoords.y, newPumpCoords.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, length, false, false, nil, nil)

	state:set("holding", ("%s_nozzle"):format(pumpType))
	CreateThread(function()
		local nozzleName = ("%s_nozzle"):format(pumpType)
		while state.holding == nozzleName do
			local currentcoords = GetEntityCoords(cache.ped)
			local dist = #(playerCoords - currentcoords)
			if dist > 7.5 then
				state:set("holding", "null")
				utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)
			end
			Wait(2500)
		end
	end)
end)

RegisterNetEvent("mnr_fuel:client:ReturnNozzle", function(data, pumpType)
	if state.refueling and not (state.holding == "fv_nozzle" or state.holding == "ev_nozzle") then return end
	
	lib.requestAudioBank("audiodirectory/mnr_fuel")
	PlaySoundFromEntity(-1, ("mnr_return_%s_nozzle"):format(pumpType), data.entity, "mnr_fuel", true, 0)
	state:set("holding", "null")
	Wait(250)
	utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)
end)

local function SecondaryMenu(purchase, vehicle, amount)
	if not lib.callback.await("mnr_fuel:server:InStation") then return end
	local totalCost = (purchase == "fuel") and math.ceil(amount * GlobalState.fuelPrice) or config.jerrycanPrice
	local vehNetID = (purchase == "fuel") and NetworkGetEntityIsNetworked(vehicle) and VehToNet(vehicle)
	local cashMoney, bankMoney = lib.callback.await("mnr_fuel:server:GetPlayerMoney", false)

	lib.registerContext({
		id = "mnr_fuel:menu:payment",
		title = locale("menu.payment-title"):format(totalCost),
		options = {
			{
				title = locale("menu.payment-bank"),
				description = locale("menu.payment-bank-desc"):format(bankMoney),
				icon = "building-columns",
				onSelect = function()
					TriggerServerEvent("mnr_fuel:server:ElaborateAction", purchase, "bank", totalCost, amount, vehNetID)
				end,
			},
			{
				title = locale("menu.payment-cash"),
				description = locale("menu.payment-cash-desc"):format(cashMoney),
				icon = "money-bill",
				onSelect = function()
					TriggerServerEvent("mnr_fuel:server:ElaborateAction", purchase, "cash", totalCost, amount, vehNetID)
				end,
			},
		},
	})

	lib.registerContext({
		id = "mnr_fuel:menu:confirm",
		title = locale("menu.confirm-title"):format(totalCost),
		options = {
			{
				title = locale("menu.confirm-choice-title"),
				menu = "mnr_fuel:menu:payment",
				icon = "circle-check",
				iconColor = "#4CAF50",
			},
			{
				title = locale("menu.cancel-choice-title"),
				icon = "circle-xmark",
				iconColor = "#FF0000",
				onSelect = function()
					lib.hideContext()
				end,
			},
		},
	})

	lib.showContext("mnr_fuel:menu:confirm")
end

RegisterNetEvent("mnr_fuel:client:RefuelVehicle", function(data)
	if not data.entity or state.refueling and not (state.holding == "fv_nozzle" or state.holding == "ev_nozzle") then return end
	if not lib.callback.await("mnr_fuel:server:InStation") then return end

	local isElectric = GetIsVehicleElectric(GetEntityModel(data.entity))
	if state.holding == "ev_nozzle" and not isElectric then return client.Notify(locale("notify.not-ev"), "error") end
	if state.holding == "fv_nozzle" and isElectric then return client.Notify(locale("notify.not-fv"), "error") end

	local vehicleState = Entity(data.entity).state
	local currentFuel = math.ceil(vehicleState.fuel or GetVehicleFuelLevel(data.entity))

	local input = lib.inputDialog(locale("input.select-amount"), {
		{type = "slider", label = locale("input.select-amount"), default = currentFuel, min = currentFuel, max = 100},
	})
	if not input then return end

	local inputFuel = tonumber(input[1])
	local fuelAmount = inputFuel - currentFuel
	if not fuelAmount or fuelAmount <= 0 then client.Notify(locale("notify.vehicle-full"), "error") return end

	SecondaryMenu("fuel", data.entity, fuelAmount)
end)

RegisterNetEvent("mnr_fuel:client:BuyJerrycan", function(data)
	if not data.entity or state.refueling and not (state.holding ~= "fv_nozzle" and state.holding ~= "ev_nozzle") then return end
	if not lib.callback.await("mnr_fuel:server:InStation") then return end

	SecondaryMenu("jerrycan")
end)

RegisterNetEvent("mnr_fuel:client:PlayRefuelAnim", function(data, isPump)
	if isPump and not (state.holding == "fv_nozzle" or state.holding == "ev_nozzle") then return end
	if not isPump and not state.holding == "jerrycan" then return end

	local vehicle = NetToVeh(data.netId)

	TaskTurnPedToFaceEntity(cache.ped, vehicle, 500)
	Wait(500)

	local refuelTime = data.Amount * 2000
	state:set("refueling", true)
	local pumpType = state.holding == "fv_nozzle" and "fv" or state.holding == "ev_nozzle" and "ev"
	local soundId = GetSoundId()
	lib.requestAudioBank("audiodirectory/mnr_fuel")
	PlaySoundFromEntity(soundId, ("mnr_%s_start"):format(pumpType), FuelEntities.nozzle, "mnr_fuel", true, 0)
	
	if lib.progressCircle({
		duration = refuelTime,
		label = locale("progress.refueling-vehicle"),
		position = "bottom",
		useWhileDead = false,
		canCancel = false,
		anim = {
			dict = isPump and "timetable@gardener@filling_can" or "weapon@w_sp_jerrycan",
			clip = isPump and "gar_ig_5_filling_can" or "fire",
		},
		disable = {move = true, car = true, combat = true},
	}) then
		StopSound(soundId)
		ReleaseSoundId(soundId)
		PlaySoundFromEntity(-1, ("mnr_%s_stop"):format(pumpType), FuelEntities.nozzle, "mnr_fuel", true, 0)
		state:set("refueling", false)
		client.Notify(locale("notify.refuel-success"), "success")
	end
end)

---@description DYNAMIC FEATURES
lib.onCache("weapon", function(weapon)
    if weapon ~= `WEAPON_PETROLCAN` and state.holding ~= "null" then
        state:set("holding", "null")
    elseif weapon == `WEAPON_PETROLCAN` then
        state:set("holding", "jerrycan")
    end
end)

---@description RESOURCE STOP
AddEventHandler("onResourceStop", function(resourceName)
	local scriptName = cache.resource or GetCurrentResourceName()
	if resourceName ~= scriptName then return end

	utils.DeleteFuelEntities(FuelEntities.nozzle, FuelEntities.rope)

	target.RemoveGlobalVehicle()

	for _, blip in pairs(Blips) do
		RemoveBlip(blip)
	end
end)

---@description INITIALIZATION FUNCTIONS
local function CreateStation(name, data)
	lib.zones.sphere({
		coords = data.coords,
		radius = data.radius,
		onEnter = function(self)
			TriggerServerEvent("mnr_fuel:server:EnterStation", name)
		end,
		onExit = function(self)
			TriggerServerEvent("mnr_fuel:server:ExitStation")
		end,
		debug = data.debug,
	})

	Blips[name] = utils.CreateBlip(data.coords, data.type == "ev")
end

---@description INITIALIZATION
state:init()

for name, data in pairs(stations) do
	CreateStation(name, data)
end

target.AddGlobalVehicle()

for model, data in pairs(config.pumps) do
	target.AddModel(model, data.type == "ev")
end
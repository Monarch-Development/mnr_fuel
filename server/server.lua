---@description Dependency ensuring
assert(GetResourceState('ox_lib') == 'started', 'ox_lib not found or not started before this script, install or start before ox_lib')

---@description Name/Update Checker
local correctName = GetResourceMetadata(GetCurrentResourceName(), 'name')

AddEventHandler('onResourceStart', function(name)
    if GetCurrentResourceName() ~= name then return end

    assert(GetCurrentResourceName() == correctName, ('The resource name is incorrect. Please set it to %s.^0'):format(correctName))
end)

lib.versionCheck(('Monarch-Development/%s'):format(correctName))

---@description Config loading
local config = lib.load('config.config')
local zones = lib.load('config.zones')

---@description Utilities loading
local utils = require 'server.modules.utils'

local InStation = {}

---@description Event to check and register when a player enters or exits a fuel station zone
RegisterNetEvent('mnr_fuel:server:RegisterEntry', function(name)
	local src = source
	local zone = zones[name]
	if type(name) ~= 'string' or not zone then
		return
	end

	local playerPed = GetPlayerPed(src)
	local playerCoords = GetEntityCoords(playerPed)
	local inside = utils.InsideZone(playerCoords, zone.coords, zone.rotation, zone.size)

	if not inside and InStation[src] == name then
		InStation[src] = nil
		return
	end

	if inside and InStation[src] == nil then
		InStation[src] = name
		return
	end

	if not inside and InStation[src] == nil then
		---@description if here, or is an error or bro is using an executor
		print(('^3[WARNING] mnr_fuel: suspicious event trigger, player [%s] trying to register in zone [%s]^0'):format(src, name))
		return
	end
end)

---@description Helper function that checks the register to avoid calculation function execution every check
local function inStation(source)
	local src = source
	return InStation[src] ~= nil
end

lib.callback.register('mnr_fuel:server:InStation', inStation)

lib.callback.register('mnr_fuel:server:GetPlayerMoney', function(source)
	local src = source
	local cash, bank = framework.GetPlayerMoney(src)

	return cash, bank
end)

local function setFuel(vehicle, amount)
	local vehState = Entity(vehicle)?.state
	local fuelLevel = vehState.fuel

	local fuel = math.min(fuelLevel + amount, 100)

	vehState:set('fuel', fuel, true)
end

local function stationRefuel(src, vehicle, data)
	if not inStation(src) then
		return
	end

	local price = math.ceil(data.amount * config.fuelPrice)
	local money = framework.GetPlayerMoney(src, data.method)

	if money < price then
		framework.Notify(src, locale('notify.not_enough_money'), 'error')
		return
	end

	if not framework.PayMoney(src, data.method, price) then
		return
	end

	local fuel = math.floor(data.amount)
	setFuel(vehicle, fuel)
end

local function jerrycanRefuel(src, vehicle)
	local vehState = Entity(vehicle)?.state
	local fuelLevel = math.ceil(vehState.fuel)
	local requiredFuel = 100 - fuelLevel
	if requiredFuel <= 0 then
		framework.Notify(src, locale('notify.vehicle_full'), 'error')
		return
	end

	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	if not weapon or weapon.name ~= 'WEAPON_PETROLCAN' then
		return
	end

	if weapon.metadata.durability <= 0 then
		return
	end

	local value = math.floor(weapon.metadata.durability - requiredFuel)
	exports.ox_inventory:SetMetadata(src, weapon.slot, { durability = value, ammo = value })

	setFuel(vehicle, requiredFuel)
end

RegisterNetEvent('mnr_fuel:server:RefuelVehicle', function(action, netId, data)
	local src = source

	local vehicle = NetworkGetEntityFromNetworkId(netId)
	if not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
		return
	end

	if action == 'fuel' then
		stationRefuel(src, vehicle, data)
	elseif action == 'jerrycan' then
		jerrycanRefuel(src, vehicle)
	end
end)

RegisterNetEvent('mnr_fuel:server:JerrycanPurchase', function(method)
	local src = source
	if not inStation(src) then
		return
	end

	local price = config.jerrycanPrice
	local money = framework.GetPlayerMoney(src, method)

	if money < price then
		framework.Notify(src, locale('notify.not_enough_money'), 'error')
		return
	end

	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	if weapon and weapon.name == 'WEAPON_PETROLCAN' then
		if weapon.metadata.durability > 0 then
		    framework.Notify(src, locale('notify.jerrycan_not_empty'), 'error')
		    return
		end

		if not framework.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:SetMetadata(src, weapon.slot, { durability = 100, ammo = 100 })
	else
		if not exports.ox_inventory:CanCarryItem(src, 'WEAPON_PETROLCAN', 1, { weight = 4000 + 15000 }) then
			framework.Notify(src, locale('notify.not_enough_space'), 'error')
			return
		end

		if not framework.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:AddItem(src, 'WEAPON_PETROLCAN', 1, { durability = 100, ammo = 100 })
	end
end)
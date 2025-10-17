local config = lib.load('config.config')
local nozzles = require 'config.nozzles'
local zones = lib.load('config.zones')

local utils = require 'server.utils'

local InStation = {}
local NozzlesRegistry = {}
local PumpsRegistry = {}

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
	local cash, bank = server.GetPlayerMoney(src)

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
	local money = server.GetPlayerMoney(src, data.method)

	if money < price then
		server.Notify(src, locale('notify.not_enough_money'), 'error')
		return
	end

	if not server.PayMoney(src, data.method, price) then
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
		server.Notify(src, locale('notify.vehicle_full'), 'error')
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
	local money = server.GetPlayerMoney(src, method)

	if money < price then
		server.Notify(src, locale('notify.not_enough_money'), 'error')
		return
	end
	
	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	if weapon and weapon.name == 'WEAPON_PETROLCAN' then
		local weapon = exports.ox_inventory:GetCurrentWeapon(src)
		if not weapon or weapon.name ~= 'WEAPON_PETROLCAN' then
		    return
		end

		if weapon.metadata.durability > 0 then
		    server.Notify(src, locale('notify.jerrycan_not_empty'), 'error')
		    return
		end

		if not server.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:SetMetadata(src, weapon.slot, { durability = 100, ammo = 100 })
	else
		if not exports.ox_inventory:CanCarryItem(src, 'WEAPON_PETROLCAN', 1, { weight = 4000 + 15000 }) then
			server.Notify(src, locale('notify.not_enough_space'), 'error')
			return
		end

		if not server.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:AddItem(src, 'WEAPON_PETROLCAN', 1, { durability = 100, ammo = 100 })
	end
end)

lib.callback.register('mnr_fuel:server:RequestNozzle', function(source, cat, netId)
	local playerId = source
	if not inStation(playerId) then return end

	local pump = NetworkGetEntityFromNetworkId(netId)
	local coords = GetEntityCoords(pump)
    local entity = CreateObject(nozzles[cat].nozzle, coords.x, coords.y, coords.z - 2.0, true, false, false)
	Wait(200) 			-- mandatory for entity creation
    local nozzleNetId = NetworkGetNetworkIdFromEntity(entity)

	NozzlesRegistry[playerId] = nozzleNetId
	PumpsRegistry[playerId] = netId

	Entity(pump).state:set('used', nozzleNetId, true)

    return nozzleNetId
end)

RegisterNetEvent('mnr_fuel:server:RequestDeletion', function()
	local playerId = source
	if not inStation(playerId) then return end

	if not NozzlesRegistry[playerId] or not PumpsRegistry[playerId] then return end

	local pump = NetworkGetEntityFromNetworkId(PumpsRegistry[playerId])
	local nozzle = NetworkGetEntityFromNetworkId(NozzlesRegistry[playerId])

	Entity(pump).state:set('used', nil, true)
	DeleteEntity(nozzle)

	PumpsRegistry[playerId] = nil
	NozzlesRegistry[playerId] = nil
end)

AddEventHandler('playerDropped', function()
	local playerId = source
	if not NozzlesRegistry[playerId] or not PumpsRegistry[playerId] then return end

	local pump = NetworkGetEntityFromNetworkId(PumpsRegistry[playerId])
	local nozzle = NetworkGetEntityFromNetworkId(NozzlesRegistry[playerId])

	Entity(pump).state:set('used', nil, true)
	DeleteEntity(nozzle)

	NozzlesRegistry[playerId] = nil
end)

AddEventHandler('onResourceStop', function(name)
	if name ~= GetCurrentResourceName() then return end

	for _, pumpNetId in pairs(PumpsRegistry) do
		local pump = NetworkGetEntityFromNetworkId(pumpNetId)
		Entity(pump).state:set('used', nil, true)
	end

	for _, nozzleNetId in pairs(NozzlesRegistry) do
		local nozzle = NetworkGetEntityFromNetworkId(nozzleNetId)
		DeleteEntity(nozzle)
	end
end)
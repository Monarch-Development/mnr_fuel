local config = lib.load('config.config')
---@description Nozzle Model Loader Placeholder (Fix strict mode entity lockdown)
local nozzles = require 'config.nozzles'
local zones = lib.load('config.zones')

local InStation = {}

lib.callback.register('mnr_fuel:server:GetPlayerMoney', function(source)
	local src = source
	local cash, bank = server.GetPlayerMoney(src)

	return cash, bank
end)

local function inside(coords, name)
    local zone = zones[name]
    if not zone then
        return false
    end

    local relative = coords - zone.coords
    local heading = zone.rotation or 0.0

    local rad = math.rad(-heading)
    local cosH = math.cos(rad)
    local sinH = math.sin(rad)

    local localX = relative.x * cosH - relative.y * sinH
    local localY = relative.x * sinH + relative.y * cosH
    local localZ = relative.z

    local halfSize = zone.size / 2

    return math.abs(localX) <= halfSize.x and math.abs(localY) <= halfSize.y and math.abs(localZ) <= halfSize.z
end

RegisterNetEvent('mnr_fuel:server:RegisterEntry', function(name)
	local src = source

	if not type(name) == 'string' or not zones[name] then return end

	if InStation[src] == name then
		InStation[src] = nil
		return
	end

	local playerPed = GetPlayerPed(src)
	local playerCoords = GetEntityCoords(playerPed)
	local isInside = inside(playerCoords, name)

	if not isInside then return end

    InStation[src] = name
end)

local function inStation(source)
	local src = source
	return InStation[src] ~= nil
end

lib.callback.register('mnr_fuel:server:InStation', inStation)

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

---@description Entity Request Placeholder (Fix Strict mode Entity Lockdown)
lib.callback.register('mnr_fuel:server:RequestNozzle', function(source, cat, netId)
	local playerId = source
	if not inStation(playerId) then return end

	local pump = NetworkGetEntityFromNetworkId(netId)
	local coords = GetEntityCoords(pump)
    local entity = CreateObject(nozzles[cat].nozzle, coords.x, coords.y, coords.z - 2.0, true, false, false)
    local nozzleNetId = NetworkGetNetworkIdFromEntity(entity)

	Entity(pump)state:set('used', nozzleNetId, true)

    return nozzleNetId
end)
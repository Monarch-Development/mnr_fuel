local config = lib.load('config.config')
local zones = lib.load('config.zones')

local InStation = {}
GlobalState:set('fuelPrice', config.fuelPrice, true)

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

---@description DATA FOR CLIENT REQUESTS
lib.callback.register('mnr_fuel:server:GetPlayerMoney', function(source)
	local src = source
	local cashMoney, bankMoney = server.GetPlayerMoney(src)

	return cashMoney, bankMoney
end)

---@description REFUEL HANDLING
local function setFuel(netId, fuelAmount)
	local vehicle = NetworkGetEntityFromNetworkId(netId)
	if not vehicle or vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local vehicleState = Entity(vehicle)?.state
	local fuelLevel = vehicleState.fuel

	local fuel = math.min(fuelLevel + fuelAmount, 100)

	vehicleState:set('fuel', fuel, true)
end

local function purchaseJerrycan(src, method, price)
	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	if weapon and weapon.name == 'WEAPON_PETROLCAN' then
    	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
		if not weapon or weapon.name ~= 'WEAPON_PETROLCAN' then
		    return
		end

		if weapon.metadata.durability > 0 then
		    server.Notify(src, locale('notify.jerrycan-not-empty'), 'error')
		    return
		end

		if not server.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:SetMetadata(src, weapon.slot, { durability = 100, ammo = 100 })
	else
    	if not exports.ox_inventory:CanCarryItem(src, 'WEAPON_PETROLCAN', 1, { weight = 4000 + 15000 }) then
    		server.Notify(src, locale('notify.not-enough-space'), 'error')
    		return
		end

		if not server.PayMoney(src, method, price) then
		    return
		end

		exports.ox_inventory:AddItem(src, 'WEAPON_PETROLCAN', 1, { durability = 100, ammo = 100 })
	end
end

RegisterNetEvent('mnr_fuel:server:ElaborateAction', function(purchase, method, amount, netId)
	local src = source
	if not inStation(src) then return end

	local price = purchase == 'fuel' and math.ceil(amount * GlobalState.fuelPrice) or config.jerrycanPrice
	local playerMoney = server.GetPlayerMoney(src, method)

	if playerMoney < price then
		return server.Notify(src, locale('notify.not-enough-money'), 'error')
	end

	if purchase == 'fuel' then
		if not server.PayMoney(src, method, price) then return end

		local fuelAmount = math.floor(amount)
		setFuel(netId, fuelAmount)

		TriggerClientEvent('mnr_fuel:client:PlayRefuelAnim', src, {netId = netId, amount = fuelAmount}, true)
	elseif purchase == 'jerrycan' then
		purchaseJerrycan(src, method, price)
	end
end)

RegisterNetEvent('mnr_fuel:server:RefuelVehicle', function(netId)
	local src = source

	local vehicle = NetworkGetEntityFromNetworkId(netId)
	if not vehicle or vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local vehState = Entity(vehicle)?.state
	local fuelLevel = math.ceil(vehState.fuel)
	local requiredFuel = 100 - fuelLevel
	if requiredFuel <= 0 then
		server.Notify(src, locale('notify.vehicle-full'), 'error')
		return
	end

	local weapon = exports.ox_inventory:GetCurrentWeapon(src)
	if not weapon or weapon.name ~= 'WEAPON_PETROLCAN' then
		return
	end

	if weapon.metadata.durability <= 0 then
		return
	end

	local newDurability = math.floor(weapon.metadata.durability - requiredFuel)
	exports.ox_inventory:SetMetadata(src, item.slot, {durability = newDurability, ammo = newDurability})

	setFuel(netId, requiredFuel)
	TriggerClientEvent('mnr_fuel:client:PlayRefuelAnim', src, {netId = netId, amount = requiredFuel}, false)
end)
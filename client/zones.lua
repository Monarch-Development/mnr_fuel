local zones = lib.load('config.zones')

local function registerEntry(self)
    TriggerServerEvent('mnr_fuel:server:RegisterEntry', self.name)
end

local function createStation(name, data)
    lib.zones.box({
        name = name,
	    coords = data.coords,
        size = data.size,
	    rotation = data.rotation,
        debug = data.debug,
	    onEnter = registerEntry,
	    onExit = registerEntry,
    })

    local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
    SetBlipAlpha(blip, 255)
    SetBlipSprite(blip, data.type == 'ev' and 354 or 361)
    SetBlipColour(blip, data.type == 'ev' and 5 or 1)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(locale(data.type == 'ev' and 'blips.name_ev' or 'blips.name_fuel'))
    EndTextCommandSetBlipName(blip)
    SetBlipDisplay(blip, 2)
    SetBlipScale(blip, data.type == 'ev' and 1.0 or 0.6)
end

for name, data in pairs(zones) do
    createStation(name, data)
end
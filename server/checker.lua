---@diagnostic disable
---@description UPDATE-RENAME-DEPENDENCIES CHECKER (DON'T DELETE)
--- If you are here means you had an error called from here, install the dependencies or
--- rename the script with the correct name to avoid the error and use the script

assert(GetResourceState('ox_lib') == 'started', 'ox_lib not found or not started before this script, install or start before ox_lib')

local expectedName = GetResourceMetadata(GetCurrentResourceName(), 'name')

lib.versionCheck(('Monarch-Development/%s'):format(expectedName))

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    assert(GetCurrentResourceName() == expectedName, ('The resource name is incorrect. Please set it to %s.^0'):format(expectedName))
end)
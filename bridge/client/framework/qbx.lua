---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qbx_core') ~= 'started' then return end

framework = {}

function framework.Notify(msg, type)
    lib.notify({
        description = msg,
        position = 'top',
        type = type or 'inform',
    })
end
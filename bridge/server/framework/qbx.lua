---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qbx_core') ~= 'started' then return end

server = {}

function server.Notify(source, msg, type)
    local src = source
    TriggerClientEvent('ox_lib:notify', src, {
        description = msg,
        position = 'top',
        type = type or 'inform',
    })
end

function server.GetPlayerMoney(source, account)
    local cash = exports.qbx_core:GetMoney(source, 'cash')
    local bank = exports.qbx_core:GetMoney(source, 'bank')

    if not account then
        return cash, bank
    end

    if account == 'cash' then
        return cash
    elseif account == 'bank' then
        return bank
    end
end

function server.PayMoney(source, method, amount)
    local success = exports.qbx_core:RemoveMoney(source, method, amount)

    return success
end
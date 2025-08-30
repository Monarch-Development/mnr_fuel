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
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local cash = player.PlayerData.money['cash']
    local bank = player.PlayerData.money['bank']

    if account == 'bank' then
        return bank
    elseif account == 'cash' then
        return cash
    else
        return cash, bank
    end
end

function server.PayMoney(source, paymentMethod, amount)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local paymentSuccess = player.Functions.RemoveMoney(paymentMethod, amount)

    return paymentSuccess
end
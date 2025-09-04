---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('es_extended') ~= 'started' then return end

local ESX = exports['es_extended']:getSharedObject()

server = {}

function server.Notify(source, msg, type)
    local src = source
    TriggerClientEvent('esx:showNotification', src, msg, type)
end

function server.GetPlayerMoney(source, account)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    local cash = xPlayer.getAccount('money').money
    local bank = xPlayer.getAccount('bank').money
    
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
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if method == 'cash' then
        method = 'money'
    end

    xPlayer.removeAccountMoney(method, amount)

    return true
end
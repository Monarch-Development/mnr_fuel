---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('es_extended') ~= 'started' then return end

local ESX = exports['es_extended']:getSharedObject()

server = {}

function server.Notify(source, msg, type)
    local src = source
    TriggerClientEvent('esx:showNotification', src, msg, type)
end

function server.GetPlayerMoney(source, account)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local cashMoney = nil
    local bankMoney = nil
    for _, data in pairs(xPlayer.accounts) do
        if data.name == account then
            return data.money
        elseif data.name == 'money' then
            cashMoney = data.money
        elseif data.name == 'bank' then
            bankMoney = data.money
        end
    end
    return cashMoney, bankMoney
end

function server.PayMoney(source, paymentMethod, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if paymentMethod == 'cash' then
        paymentMethod = 'money'
    end
    xPlayer.removeAccountMoney(paymentMethod, amount)

    return true
end
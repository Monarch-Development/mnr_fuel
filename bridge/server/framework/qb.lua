---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qb-core') ~= 'started' then return end

local QBCore = exports['qb-core']:GetCoreObject()

framework = {}

function framework.Notify(source, msg, type)
    local src = source
    TriggerClientEvent('QBCore:Notify', src, msg, type)
end

function framework.GetPlayerMoney(source, account)
    local Player = QBCore.Functions.GetPlayer(source)

    local cash = Player.Functions.GetMoney('cash')
    local bank = Player.Functions.GetMoney('bank')

    if not account then
        return cash, bank
    end

    if account == 'cash' then
        return cash
    elseif account == 'bank' then
        return bank
    end
end

function framework.PayMoney(source, method, amount)
    local Player = QBCore.Functions.GetPlayer(source)

    local paymentSuccess = Player.Functions.RemoveMoney(method, amount)

    return paymentSuccess
end
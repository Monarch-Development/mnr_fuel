---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qb-core') ~= 'started' then return end

local QBCore = exports['qb-core']:GetCoreObject()

server = {}

function server.Notify(source, msg, type)
    local src = source
    TriggerClientEvent('QBCore:Notify', src, msg, type)
end

function server.GetPlayerMoney(source, account)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    local cash = Player.Functions.GetMoney('cash')
    local bank = Player.Functions.GetMoney('bank')

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
    local Player = QBCore.Functions.GetPlayer(src)
    local paymentSuccess = Player.Functions.RemoveMoney(paymentMethod, amount)

    return paymentSuccess
end
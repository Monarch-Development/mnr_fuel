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

    local cashMoney = Player.Functions.GetMoney('cash')
    local bankMoney = Player.Functions.GetMoney('bank')

    if account == 'bank' then
        return bankMoney
    elseif account == 'cash' then
        return cashMoney
    else
        return cashMoney, bankMoney
    end
end

function server.PayMoney(source, paymentMethod, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local paymentSuccess = Player.Functions.RemoveMoney(paymentMethod, amount)

    return paymentSuccess
end
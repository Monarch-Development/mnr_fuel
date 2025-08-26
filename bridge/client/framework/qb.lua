---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qb-core') ~= 'started' then return end

local QBCore = exports['qb-core']:GetCoreObject()

client = {}

function client.Notify(msg, type)
    QBCore.Functions.Notify(msg, type)
end
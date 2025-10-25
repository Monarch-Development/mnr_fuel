---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('qb-core') ~= 'started' then return end

local QBCore = exports['qb-core']:GetCoreObject()

framework = {}

function framework.Notify(msg, type)
    QBCore.Functions.Notify(msg, type)
end
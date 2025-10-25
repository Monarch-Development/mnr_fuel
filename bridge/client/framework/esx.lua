---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('es_extended') ~= 'started' then return end

local ESX = exports['es_extended']:getSharedObject()

framework = {}

function framework.Notify(msg, type)
    ESX.ShowNotification(msg, type)
end
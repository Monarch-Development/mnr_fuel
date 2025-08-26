---@diagnostic disable: duplicate-set-field, lowercase-global

if GetResourceState('es_extended') ~= 'started' then return end

local ESX = exports['es_extended']:getSharedObject()

client = {}

function client.Notify(msg, type)
    ESX.ShowNotification(msg, type)
end
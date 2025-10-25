local state = {}
state.__index = state

function state:init()
    self.refueling = false
    self.holding = nil
    self.pump = 0
end

function state:set(key, value)
    self[key] = value
end

function state:holdingItem(item)
    return self.holding ~= nil and self.holding.item == item
end

function state:nozzleCat()
    return self:holdingItem('nozzle') and self.holding.cat or false
end

return state
local jerrycan = {}

function jerrycan.refill(source, method, price)
    local src = source

    local weapon = exports.ox_inventory:GetCurrentWeapon(src)
    if not weapon or weapon.name ~= 'WEAPON_PETROLCAN' then
        return
    end

    if weapon.metadata.durability > 0 then
        server.Notify(src, locale("notify.jerrycan-not-empty"), "error")
        return
    end

    if not server.PayMoney(src, method, price) then
        return
    end

    exports.ox_inventory:SetMetadata(src, weapon.slot, {durability = 100, ammo = 100})
end

function jerrycan.buy(source, method, price)
    local src = source
    if not inventory.CanCarry(src, "WEAPON_PETROLCAN") then
        return server.Notify(src, locale("notify.not-enough-space"), "error")
    end

    if not server.PayMoney(src, method, price) then return end

    inventory.AddItem(src, "WEAPON_PETROLCAN", 1)
end

function jerrycan.purchase(source, method, price)
    local src = source

    local weapon = exports.ox_inventory:GetCurrentWeapon(src)
    if weapon and weapon.name == 'WEAPON_PETROLCAN' then
        return jerrycan.refill(src, method, price)
    else
        return jerrycan.buy(src, method, price)
    end
end

return jerrycan
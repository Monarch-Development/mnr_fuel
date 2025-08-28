return {
    fuelPrice = 2,
    jerrycanPrice = 500,
    nozzleType = {
        ['fv'] = { nozzle = `prop_cs_fuel_nozle`,
            offsets = {
                hand = { 0.13, 0.04, 0.01, -42.0, -115.0, -63.42 },
                rope = vec3(0.0, -0.033, -0.195),
            },
        },
    },
    ropeType = { -- Options: 1-2-3-4-5; 1: Khaki Color, Kind of Thick, 2: Very Thick Khaki Rope, 3: Very Thick Black Rope, 4: Very Thin Black Rope, 5: Same as 3
        ['fv'] = 1,
        ['ev'] = 1,
    },
    pumps = {
        [`prop_gas_pump_1a`] = { type = 'fv', offset = vec3(-0.37, 0.28, 1.8) },
        [`prop_gas_pump_1b`] = { type = 'fv', offset = vec3(0.34, -0.23, 2.2) },
        [`prop_gas_pump_1c`] = { type = 'fv', offset = vec3(0.34, -0.23, 2.17) },
        [`prop_gas_pump_1d`] = { type = 'fv', offset = vec3(0.34, -0.23, 2.1) },
        [`prop_gas_pump_old2`] = { type = 'fv', offset = vec3(0.41, 0.0, 0.6) },
        [`prop_gas_pump_old3`] = { type = 'fv', offset = vec3(-0.41, 0.0, 0.6) },
        [`prop_vintage_pump`] = { type = 'fv', offset = vec3(-0.27, 0.05, 1.21) },
    },
}
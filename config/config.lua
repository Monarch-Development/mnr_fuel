return {
    fuelPrice = 2,
    jerrycanPrice = 500,
    refuelTime = 2000,              --- Time in ms required for each liter of fuel during refuel animation
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
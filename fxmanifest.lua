fx_version "cerulean"
game "gta5"
lua54 "yes"

name "mnr_fuel"
description "Fuel System for FiveM"
author "IlMelons"
version "1.2.0"
repository "https://www.github.com/Monarch-Development/mnr_fuel"

ox_lib "locale"

shared_scripts {
    "@ox_lib/init.lua",
    "config/*.lua",
}

client_scripts {
    "bridge/client/**/*.lua",
    "client/*.lua",
}

server_scripts {
    "bridge/server/**/*.lua",
    "server/*.lua",
}

files {
    "data/mnr_fuel_sounds.dat54.rel",
    "audiodirectory/mnr_fuel.awc",
    "locales/*.json",
}

data_file "AUDIO_WAVEPACK"  "audiodirectory"
data_file "AUDIO_SOUNDDATA" "data/mnr_fuel_sounds.dat"

provide "ox_fuel"

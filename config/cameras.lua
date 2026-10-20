--[[
    Camera list. The order is the order in the UI and when switching with [Q]/[E].

    id        Unique id (for exports.SetCameraOnline etc.)
    label     Name shown in the UI
    category  An id from config.lua -> Categories
    coords    Camera position
    rot       vec3(pitch, 0.0, yaw) starting angle. pitch: negative = down | yaw: GTA heading (turning left is positive)
    fov       (optional) Starting field of view, defaults to Defaults.fov
    limits    (optional) { yaw = 80.0, pitchMin = -80.0, pitchMax = 10.0, minFov = 7.0, maxFov = 70.0 }
    online    (optional) false = offline when the server starts

    To place a camera, set Debug = true in config.lua, aim the camera with WASD
    and press [C]: the coords/rot/fov line is copied to your clipboard.
]]

return {
    -- Banks
    { id = "pacific_lobby",     label = "Pacific Standard - Lobby",          category = "bank", coords = vec3(257.45, 210.07, 109.08),       rot = vec3(-25.0, 0.0, 28.05) },
    { id = "pacific_entrance",  label = "Pacific Standard - Entrance",       category = "bank", coords = vec3(232.86, 221.46, 107.83),       rot = vec3(-25.0, 0.0, -140.91) },
    { id = "pacific_vault",     label = "Pacific Standard - Vault Corridor", category = "bank", coords = vec3(252.27, 225.52, 103.99),       rot = vec3(-35.0, 0.0, -74.87) },
    { id = "fleeca_legion",     label = "Fleeca - Legion Square",            category = "bank", coords = vec3(144.871, -1043.044, 31.017),   rot = vec3(-35.0, 0.0, -143.98) },
    { id = "fleeca_hawick",     label = "Fleeca - Hawick Ave",               category = "bank", coords = vec3(309.341, -281.439, 55.88),     rot = vec3(-35.0, 0.0, -146.16) },
    { id = "fleeca_burton",     label = "Fleeca - Burton",                   category = "bank", coords = vec3(-355.764, -52.506, 50.746),    rot = vec3(-35.0, 0.0, -143.87) },
    { id = "fleeca_delperro",   label = "Fleeca - Del Perro Blvd",           category = "bank", coords = vec3(-1214.226, -335.86, 39.515),   rot = vec3(-35.0, 0.0, -97.86) },
    { id = "fleeca_greatocean", label = "Fleeca - Great Ocean Hwy",          category = "bank", coords = vec3(-2958.885, 478.983, 17.406),   rot = vec3(-35.0, 0.0, -34.70) },
    { id = "fleeca_route68",    label = "Fleeca - Route 68",                 category = "bank", coords = vec3(1178.84, 2710.65, 39.80),      rot = vec3(-35.0, 0.0, 57.80) },
    { id = "paleto_bank",       label = "Blaine County Savings - Paleto",    category = "bank", coords = vec3(-102.939, 6467.668, 33.424),   rot = vec3(-35.0, 0.0, 24.66) },

    -- 24/7 Stores
    { id = "247_innocence",     label = "24/7 - Innocence Blvd",             category = "store", coords = vec3(23.885, -1342.441, 31.672),   rot = vec3(-35.0, 0.0, -142.92) },
    { id = "247_clinton",       label = "24/7 - Clinton Ave",                category = "store", coords = vec3(383.402, 328.915, 105.541),   rot = vec3(-35.0, 0.0, 118.59) },
    { id = "247_palomino",      label = "24/7 - Palomino Fwy",               category = "store", coords = vec3(2552.45, 380.13, 110.79),     rot = vec3(-35.0, 0.0, -57.90) },
    { id = "247_ineseno",       label = "24/7 - Ineseno Road",               category = "store", coords = vec3(-3046.749, 592.491, 9.808),   rot = vec3(-35.0, 0.0, -116.67) },
    { id = "247_barbareno",     label = "24/7 - Barbareno Rd",               category = "store", coords = vec3(-3246.489, 1010.408, 14.705), rot = vec3(-35.0, 0.0, -135.22) },
    { id = "247_route68",       label = "24/7 - Route 68",                   category = "store", coords = vec3(539.773, 2664.904, 44.056),   rot = vec3(-35.0, 0.0, -42.95) },
    { id = "247_senora",        label = "24/7 - Senora Fwy",                 category = "store", coords = vec3(2673.579, 3281.265, 57.541),  rot = vec3(-35.0, 0.0, -80.24) },
    { id = "247_sandy",         label = "24/7 - Alhambra Dr",                category = "store", coords = vec3(1966.24, 3749.545, 34.143),   rot = vec3(-35.0, 0.0, 163.07) },
    { id = "247_paleto",        label = "24/7 - Paleto Senora Fwy",          category = "store", coords = vec3(1729.522, 6419.87, 37.262),   rot = vec3(-35.0, 0.0, -160.09) },
    { id = "dons_country_1",    label = "Don's Country Store - Counter",     category = "store", coords = vec3(166.42, 6634.4, 33.69),       rot = vec3(-35.0, 0.0, 32.0) },
    { id = "dons_country_2",    label = "Don's Country Store - Entrance",    category = "store", coords = vec3(163.74, 6644.34, 33.69),      rot = vec3(-35.0, 0.0, 168.0) },
    { id = "dons_country_3",    label = "Don's Country Store - Aisles",      category = "store", coords = vec3(169.54, 6640.89, 33.69),      rot = vec3(-35.0, 0.0, 5.78) },

    -- LTD Gasoline
    { id = "ltd_grove",         label = "LTD - Grove Street",                category = "ltd", coords = vec3(-53.143, -1746.714, 31.546),    rot = vec3(-35.0, 0.0, -168.92) },
    { id = "ltd_littleseoul",   label = "LTD - Little Seoul",                category = "ltd", coords = vec3(-718.153, -909.211, 21.49),     rot = vec3(-35.0, 0.0, -137.14) },
    { id = "ltd_mirrorpark",    label = "LTD - Mirror Park",                 category = "ltd", coords = vec3(1151.93, -320.389, 71.33),      rot = vec3(-35.0, 0.0, -119.45) },
    { id = "ltd_richman",       label = "LTD - Banham Canyon",               category = "ltd", coords = vec3(-1832.057, 789.389, 140.436),   rot = vec3(-35.0, 0.0, -91.48) },
    { id = "ltd_grapeseed",     label = "LTD - Grapeseed",                   category = "ltd", coords = vec3(1708.34, 4930.69, 44.18),       rot = vec3(-35.0, 0.0, 105.10) },

    -- Liquor stores
    { id = "robs_prosperity",   label = "Rob's Liquor - Prosperity St",      category = "liquor", coords = vec3(-1482.9, -380.463, 42.363),  rot = vec3(-35.0, 0.0, 79.53) },
    { id = "robs_sanandreas",   label = "Rob's Liquor - San Andreas Ave",    category = "liquor", coords = vec3(-1224.874, -911.094, 14.401), rot = vec3(-35.0, 0.0, -6.78) },
    { id = "robs_elrancho",     label = "Rob's Liquor - El Rancho Blvd",     category = "liquor", coords = vec3(1133.024, -978.712, 48.515), rot = vec3(-35.0, 0.0, -137.30) },
    { id = "robs_greatocean",   label = "Rob's Liquor - Great Ocean Hwy",    category = "liquor", coords = vec3(-2966.15, 387.067, 17.393),  rot = vec3(-35.0, 0.0, 32.92) },
    { id = "robs_route68",      label = "Rob's Liquor - Route 68",           category = "liquor", coords = vec3(1169.855, 2711.493, 40.432), rot = vec3(-35.0, 0.0, 127.17) },
    { id = "delvecchio_paleto", label = "Del Vecchio Liquor - Paleto",       category = "liquor", coords = vec3(-163.75, 6323.45, 33.424),   rot = vec3(-35.0, 0.0, -100.0) },

    -- Jewelry stores
    { id = "vangelico_1",       label = "Vangelico - Entrance",              category = "jewelry", coords = vec3(-627.54, -239.74, 40.33),   rot = vec3(-35.0, 0.0, 5.78) },
    { id = "vangelico_2",       label = "Vangelico - West Displays",         category = "jewelry", coords = vec3(-627.51, -229.51, 40.24),   rot = vec3(-35.0, 0.0, -95.78) },
    { id = "vangelico_3",       label = "Vangelico - North Displays",        category = "jewelry", coords = vec3(-620.3, -224.31, 40.23),    rot = vec3(-35.0, 0.0, 165.78) },
    { id = "vangelico_4",       label = "Vangelico - Sales Floor",           category = "jewelry", coords = vec3(-622.57, -236.3, 40.31),    rot = vec3(-35.0, 0.0, 5.78) },
}

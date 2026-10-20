fx_version 'cerulean'
game {'gta5'}

author 'vezironi'
description 'Hype Camera is a CCTV system for FiveM servers. Authorized players watch security cameras placed in banks, stores and shops, steer them with WASD, zoom with the mouse wheel and identify unmasked players through face recognition.'

scriptname 'hype-camera'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*.lua',
    'frameworks/main.lua',
    'modules/main.lua',
}

client_scripts {
    'frameworks/**/cl-main.lua',
    'modules/notify/cl-main.lua',
    'modules/target/**/cl-*.lua',
    'client/*.lua',
}

server_scripts {
    'frameworks/**/sv-main.lua',
    'modules/notify/sv-main.lua',
    'server/*.lua',
}

escrow_ignore {
    'config/*.lua',
    'shared/*.lua',
    'frameworks/**/*.lua',
    'frameworks/main.lua',
    'modules/**/**.lua',
    'modules/main.lua',
    'client/*.lua',
    'server/*.lua',
}

files {
    'config/*.lua',
    'web/build/*.*',
    'web/build/**/*.*',
    'locales/*.json',
}

ui_page 'web/build/index.html'

lua54 'yes'
use_experimental_fxv2_oal 'yes'

fx_version 'cerulean'
game 'gta5'

name 'vem-opkaldsliste'
author 'vem-opkaldsliste'
version '1.0.0'
description 'Opkaldsliste med GTA V kort (ESX Legacy)'

lua54 'yes'

shared_script 'config.lua'

client_script 'client/client.lua'
server_scripts {
    'server/server.lua',
    'server/export.lua',
}

ui_page 'ui/dist/index.html'

files {
    'ui/dist/index.html',
    'ui/dist/**/*',
}

dependency 'es_extended'

server_exports {
    'AddCall',
    'AddAnonymousCall',
}

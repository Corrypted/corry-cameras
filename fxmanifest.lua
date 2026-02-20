fx_version 'cerulean'
game 'gta5'

author 'Corry'
description 'corry_boosting - QBCore boosting resource'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config/config.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- remove if not using oxmysql
    'server/*.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

escrow_ignore {
    'config.lua'
}

-- Optional: ignore files from FiveM escrow
-- escrow_ignore {
--     'config.lua'
-- }
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_jobs'
author 'Mazus / MZ Framework'
description 'Server-authoritative job offers and executions foundation for MZ Framework'
version '0.1.0'

server_only 'yes'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/locale.lua',
  'shared/contracts.lua'
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/state.lua',
  'server/adapters/core.lua',
  'server/adapters/economy.lua',
  'server/adapters/inventory.lua',
  'server/repository.lua',
  'server/policy.lua',
  'server/service.lua',
  'server/reconciliation.lua',
  'server/main.lua'
}

files {
  'locales/*.json'
}

dependencies {
  'ox_lib',
  'oxmysql',
  'mz_core'
}

local crud = require('crud')
local log = require('log')
local uuid = require('uuid')
local shared_api = require 'app.roles.shared_api'

local exported_functions = {
}

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write,execute',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    for name, func in pairs(exported_functions) do
        rawset(_G, name, func)
    end

    return true
end

return {
    role_name = 'app.roles.smev_message_to_iis_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}

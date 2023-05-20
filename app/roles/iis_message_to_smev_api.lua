local crud = require('crud')
local log = require('log')
local uuid = require('uuid')
local shared_api = require 'app.roles.shared_api'

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_request_xml_guid записывается saveSMEVRequest
local function saveSMEVRequest(data)
    --local msg, err = crud.select('iis_message_to_smev', {{'=', 'message_id', data['message_id']}})
    --if err ~= nil then
    --    log.info(err)
    --end
    --msg = crud.unflatten_rows(msg.rows, msg.metadata)
    local _, err = crud.update('iis_message_to_smev', data['message_id'], {
        {'=', 'smev_request_xml_guid', data['smev_request_xml_guid']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("saveSMEVRequest()")
end

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_send_error записывается xml
local function faultErrorSMEVSending(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'], {
        {'=', 'smev_send_error', data['smev_send_error']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("faultErrorSMEVSending()")
end

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_send_error записывается error
local function httpErrorSMEVSending(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'], {
        {'=', 'smev_send_error', data['smev_send_error']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("httpErrorSMEVSending()")
end

-- В iis_message_to_smev для сообщения где
-- messageId = message_id в smev_response_xml_guid
-- записывается xmlRef, в end_send_date записывается текущее дата и время,
-- значение smev_send_error обнуляется
local function endSMEVSending(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'], {
        {'=', 'smev_response_xml_guid', data['smev_response_xml_guid']},
        {'=', 'end_send_date', shared_api.get_date()},
        {'=', 'smev_send_error', ""},})
    if err ~= nil then
        log.info(err)
    end
    log.info("endSMEVSending()")
end

local function endSMEVMessageProcessing(data)
    local id = uuid():str()

    -- В таблицу smev_message_to_iis добавляются записи: id = генерируется идентификатор,
    -- parent_message_id = messageId, smev_namespace = smevNamespace, iis_xml_guid = iisXmlGuid
    local _, err = crud.insert('smev_message_to_iis',
        {
            -- Идентификатор сообщения
            id,
            -- Идентификатор или идентификаторы родительских сообщений полученных из ИИС
            data['message_id'],
            -- СМЭВ namespace
            data['smev_namespace'],
            -- Идентификатор в ЭА XML сообщения для отправки в ИИС
            data['iis_xml_guid'],
            -- Дата начала обработки сообщения
            nil,
            -- Тело запроса при отправке сообщения
            nil,
            -- Тело ответа
            nil,
            -- ?
            nil,
            -- Дата окончания обработки сообщения
            nil,
        })
    if err ~= nil then
        log.info(err)
    end

    -- В топик bft_smev_adapter_iis_router_service отправляется сообщение в JSON со значениями из smev_message_to_iis созданной записи:
    --{id: id, messageId: parent_message_id, smevNamespace: smev_namespace, iisXmlGuid: iis_xml_guid }
    shared_api.send_kafka_bft_smev_adapter_iis_router_service(id)

    -- В таблицу smev_message_to_iis для созданной записи в start_send_date устанавливается текущая дата
    local _, err = crud.update('smev_message_to_iis', id, {{'=', 'start_send_date', shared_api.get_date()}})
    if err ~= nil then
        log.info(err)
    end

    -- В таблицу smev_message_recived установить end_processing_date = текущая дата, для всех message_id которые есть в массиве data['message_id']
    for i, v in ipairs(data['message_id']) do
        local _, err = crud.update('smev_message_recived', v, {{'=', 'end_processing_date', shared_api.get_date()}})
        if err ~= nil then
            log.info(err)
        end
    end
    log.info("endSMEVMessageProcessing()")
end

local exported_functions = {
    saveSMEVRequest = saveSMEVRequest,
    faultErrorSMEVSending = faultErrorSMEVSending,
    httpErrorSMEVSending = httpErrorSMEVSending,
    endSMEVSending = endSMEVSending,
    endSMEVMessageProcessing = endSMEVMessageProcessing,
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
    role_name = 'app.roles.iis_message_to_smev_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}

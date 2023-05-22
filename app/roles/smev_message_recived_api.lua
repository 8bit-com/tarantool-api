local crud = require('crud')
local log = require('log')
local datetime = require('datetime')
local shared_api = require 'app.roles.shared_api'

local function get_all_smev_message_recived()
    local SMEVMessages, err = crud.select('smev_message_recived', nil, {fullscan = true})
    if err ~= nil then
        log.info(err)
    end
    SMEVMessages = crud.unflatten_rows(SMEVMessages.rows, SMEVMessages.metadata)
    for _, SMEVmessage in ipairs(SMEVMessages) do
        SMEVmessage['create_date'] = shared_api.map_date(SMEVmessage['create_date'])
        SMEVmessage['smev_message_date'] = shared_api.map_date(SMEVmessage['smev_message_date'])
        SMEVmessage['start_processing_date'] = shared_api.map_date(SMEVmessage['start_processing_date'])
        SMEVmessage['end_processing_date'] = shared_api.map_date(SMEVmessage['end_processing_date'])
        SMEVmessage['start_ack_send_date'] = shared_api.map_date(SMEVmessage['start_ack_send_date'])
        SMEVmessage['end_ack_send_date'] = shared_api.map_date(SMEVmessage['end_ack_send_date'])
    end
    log.info("findAll()!!!")
    return SMEVMessages
end

-- Вернуть true если в smev_message_recived найдено сообщение
-- в где message_id = messageId, иначе false.
-- Если сообщение найдено, то в smev_message_recived для message_id = messageId значение ack_priority увеличивается на 1
-- В топик bft_smev_adapter_ack_service отправляется сообщения в JSON со значениями из
-- smev_message_recived для строки где message_id = messageId:
-- { messageId = message_id, ack_priority = ack_priority }
local function checkExistSMEVMessage(data)
    local msg = crud.get('smev_message_recived', data['message_id'])
    log.info("checkExistSMEVMessage()")
    if msg ~= nil then
        local msg, err = crud.select('smev_message_recived', {{'=', 'message_id', data['message_id']}})
        if err ~= nil then
            log.info(err)
        end
        msg = crud.unflatten_rows(msg.rows, msg.metadata)
        local priority = msg[1].ack_priority + 1
        local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'ack_priority', priority}})
        if err ~= nil then
            log.info(err)
        end
        shared_api.send_kafka_bft_smev(data['message_id'])
        return true
    else
        return false
    end
end

local function saveSMEVMessage(data)
    -- В smev_message_recived вставляются данные:
    -- message_id = messageId, smev_namespace = smevNamespace,
    -- smev_xml_guid = smevXmlGuid, attachment_guids = attachmentGuids,
    -- create_date устанавливается текущая дата, smev_message_date = deliveryTimeStamp,
    -- processing_topic_name = processingTopicName, значение ack_priority устанавливается 1
    local _, err = crud.insert('smev_message_recived',
        {
            -- message_id -- Идентификатор сообщения полученного из СМЭВ
            data['message_id'],
            -- smev_namespace -- namespace сообщения из СМЭВ
            data['smev_namespace'],
            -- smev_xml_guid -- Идентификатор XML файла конверта в ЭА полученного из СМЭВ
            data['smev_xml_guid'],
            -- attachment_guids -- Массив идентификаторов вложений
            data['attachment_guids'],
            -- create_date -- Дата получения сообщения
            shared_api.get_date(),
            -- smev_message_date -- ?
            datetime.parse(data['smev_message_date']),
            -- processing_topic_name -- ?
            data['processing_topic_name'],
            -- smev_message_type -- Тип СМЭВ сообщения 1 - Request, 2 - Response
            data['smev_message_type'],
            -- original_message_id -- Заполняется из элемента OriginalMessageId XML СЭМВ для smev_message_type = 2
            data['original_message_id'],
            -- start_processing_date -- Дата начала обработки сообщения
            nil,
            -- processing_context -- ?
            nil,
            -- processing_error -- Текст ошибки
            nil,
            -- end_processing_date -- Дата окончания обработки сообщения
            nil,
            -- start_ack_send_date -- Дата начала отправки ack
            nil,
            -- ack_request_xml_guid -- Идентификатор в ЭА XML запроса
            nil,
            -- ack_response_xml_guid -- Идентификатор в ЭА XML ответа
            nil,
            -- ack_priority -- Приоритет
            1,
            -- ack_send_error -- Текст ошибки
            nil,
            -- end_ack_send_date -- Дата окончания отправки
            nil,
        })
    if err ~= nil then
        log.info(err)
    end

    -- В топик bft_smev_adapter_ack_service отправляется сообщения в JSON
    -- со значениями из smev_message_recived для строки где message_id = messageId:
    -- { messageId = message_id, ack_priority = ack_priority }
    shared_api.send_kafka_bft_smev(data['message_id'])

    local date = shared_api.get_date()

    -- В smev_message_recived для сообщения где messageId = message_Id в
    -- start_ack_send_date записывается текущее датавремя
    local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'start_ack_send_date', date}})
    if err ~= nil then
        log.info(err)
    end

    -- В топик из smev_message_recived. processing_topic_name где
    -- messageId = message_Id, отправляется сообщение в JSON со следующими атрибутами
    -- из smev_message_recived:
    -- { messageId = message_id, smevNamespace = smev_namespace,
    -- smevXmlGuid = smev_xml_guid, attachmentGuids = attachment_guids }
    shared_api.send_kafka_processing(data['message_id'])

    -- В smev_message_recived для сообщения где messageId = message_Id
    -- в start_processing_date записывается текущее датавремя
    local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'start_processing_date', date}})
    if err ~= nil then
        log.info(err)
    end
    log.info("saveSMEVMessage()")
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_request_xml_guid записывается текущее xmlRef
local function saveAckRequest(data)
    local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'ack_request_xml_guid', data['ack_request_xml_guid']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("saveAckRequest()")
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_send_error записывается xml
local function faultErrorAckSending(data)
    local _, err = crud.update('smev_message_recived', data['message_id'], {
        {'=', 'ack_send_error', data['ack_send_error']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("faultErrorAckSending(%s,%s)", data['message_id'], data['ack_send_error'])
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_send_error записывается error
local function httpErrorAckSending(data)
    local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'ack_send_error', data['ack_send_error']}})
    if err ~= nil then
        log.info(err)
    end
    log.info("httpErrorAckSending(%s,%s)", data['message_id'], data['ack_send_error'])
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_response_xml_guid записывается xmlRef, в end_ack_send_date
-- записывается текущее дата и время, значение ack_send_error обнуляется
local function endAckSending(data)
    local date = shared_api.get_date()
    local _, err = crud.update('smev_message_recived', data['message_id'], {
        {'=', 'ack_response_xml_guid', data['ack_response_xml_guid']},
        {'=', 'end_ack_send_date', date},
        {'=', 'ack_send_error', ""}})
    if err ~= nil then
        log.info(err)
    end
    log.info("endAckSending()")
end

local exported_functions = {
    checkExistSMEVMessage = checkExistSMEVMessage,
    saveSMEVMessage = saveSMEVMessage,
    saveAckRequest = saveAckRequest,
    faultErrorAckSending = faultErrorAckSending,
    httpErrorAckSending = httpErrorAckSending,
    endAckSending = endAckSending,
    get_all_smev_message_recived = get_all_smev_message_recived,
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
    role_name = 'app.roles.smev_message_recived_api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}

local cartridge = require('cartridge')
local crud = require('crud')
local log = require('log')
local os = require('os')
local tnt_kafka = require('kafka')
local json = require('json')
local datetime = require('datetime')
local fiber = require 'fiber'

-- Вернуть true если в smev_message_recived найдено сообщение
-- в где message_id = messageId, иначе false
local function checkExistSMEVMessage(messageId)
    local msg = crud.get('smev_message_recived', messageId)
    if msg ~= nil then
        return true
    else
        return false
    end
end

local function saveSMEVMessage(data)
    local cluster_config = cartridge.config_get_deepcopy()
    local hello_section = cluster_config['api']
    local kafka_port = hello_section['kafka_port']
    local producer, err = tnt_kafka.Producer.create({ brokers = kafka_port })
    if err ~= nil then
        log.info(err)
        os.exit(1)
    end

    log.info(data)

    -- В smev_message_recived вставляются данные:
    -- message_id = messageId, smev_namespace = smevNamespace,
    -- smev_xml_guid = smevXmlGuid, attachment_guids = attachmentGuids,
    -- create_date устанавливается текущая дата, smev_message_date = deliveryTimeStamp,
    -- processing_topic_name = processingTopicName, значение ack_priority увеличивается на 1,
    -- если было пусто то устанавливается 1
    local _, err = crud.insert('smev_message_recived',
        {
            -- Идентификатор сообщения полученного из СМЭВ
            data['message_id'],
            -- namespace сообщения из СМЭВ
            data['smev_namespace'],
            -- Идентификатор XML файла конверта в ЭА полученного из СМЭВ
            data['smev_xml_guid'],
            -- Массив идентификаторов вложений
            data['attachment_guids'],
            -- Дата получения сообщения
            datetime.parse(os.date("!%Y-%m-%dT%H:%M:%SZ", fiber.time())),
            -- ?
            datetime.parse(data['smev_message_date']),
            -- ?
            data['processing_topic_name'],
            -- Дата начала обработки сообщения
            nil,
            -- ?
            nil,
            -- Текст ошибки
            nil,
            -- Дата окончания обработки сообщения
            nil,
            -- Дата начала отправки ack
            nil,
            -- Идентификатор в ЭА XML запроса
            nil,
            -- Идентификатор в ЭА XML ответа
            nil,
            -- Приоритет
            1,
            -- Текст ошибки
            nil,
            -- Дата окончания отправки
            nil,
        })
    if err ~= nil then
        log.info(err)
    end

    -- В топик bft_smev_adapter_ack_service отправляется сообщения в JSON
    -- со значениями из smev_message_recived для строки где message_id = messageId:
    -- { messageId = message_id, ack_priority = ack_priority }
    local msg, err = crud.select('smev_message_recived', {{'=', 'message_id', data['message_id']}})
    if err ~= nil then
        log.info(err)
    end
    msg = crud.unflatten_rows(msg.rows, msg.metadata)
    log.info(msg)
    local msg = { messageId = msg[1].message_id, ack_priority = msg[1].ack_priority }
    msg = json.encode(msg)
    local err = producer:produce_async({
        topic = "bft_smev_adapter_ack_service",
        value = msg
    })
    if err ~= nil then
        log.info(string.format("got error '%s' while sending value '%s'", err, msg))
    else
        log.info("successfully sent value '%s'", msg)
    end

    local date = datetime.parse(os.date("!%Y-%m-%dT%H:%M:%SZ", fiber.time()))

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
    local msg, err = crud.select('smev_message_recived',
        {{'=', 'message_id', data['message_id']}})
    if err ~= nil then
        log.info(err)
    end
    msg = crud.unflatten_rows(msg.rows, msg.metadata)
    local msg = { messageId = msg[1].message_id, smevNamespace = msg[1].smev_namespace,
                  smevXmlGuid = msg[1].smev_xml_guid, attachmentGuids = msg[1].attachment_guids }
    msg = json.encode(msg)
    local err = producer:produce_async({
        topic = "processing_topic_name",
        value = msg
    })
    if err ~= nil then
        log.info(string.format("got error '%s' while sending value '%s'", err, msg))
    else
        log.info(string.format("successfully sent value '%s'", msg))
    end

    local date = datetime.parse(os.date("!%Y-%m-%dT%H:%M:%SZ", fiber.time()))

    -- В smev_message_recived для сообщения где messageId = message_Id
    -- в start_processing_date записывается текущее датавремя
    local _, err = crud.update('smev_message_recived', data['message_id'], {{'=', 'start_processing_date', date}})

    if err ~= nil then
        log.info(err)
    end
end

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_request_xml_guid записывается saveSMEVRequest
local function saveSMEVRequest(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'],
        {{'=', 'smev_request_xml_guid', data['xmlRef']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_send_error записывается xml
local function faultErrorSMEVSending(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'],
        {{'=', 'smev_send_error', data['xml']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В iis_message_to_smev для сообщения где messageId = message_id
-- в smev_send_error записывается error
local function httpErrorSMEVSending(data)
    local _, err = crud.update('iis_message_to_smev', data['message_id'],
        {{'=', 'smev_send_error', data['error']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В iis_message_to_smev для сообщения где
-- messageId = message_id в smev_response_xml_guid
-- записывается xmlRef, в end_send_date записывается текущее дата и время,
-- значение smev_send_error обнуляется
local function endSMEVSending(data)
    local date = datetime.parse(os.date("!%Y-%m-%dT%H:%M:%SZ", fiber.time()))
    local _, err = crud.update('iis_message_to_smev', data['message_id'],
        {{'=', 'smev_response_xml_guid', data['xmlRef']},
         {'=', 'end_send_date', date},
         {'=', 'smev_send_error', nil},})
    if err ~= nil then
        log.info(err)
    end
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_request_xml_guid записывается текущее xmlRef
local function saveAckRequest(data)
    local _, err = crud.update('smev_message_recived', data['message_id'],
        {{'=', 'ack_request_xml_guid', data['xmlRef']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_send_error записывается xml
local function faultErrorAckSending(data)
    local _, err = crud.update('smev_message_recived', data['message_id'],
        {{'=', 'ack_send_error', data['xml']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_send_error записывается error
local function httpErrorAckSending(data)
    local _, err = crud.update('smev_message_recived', data['message_id'],
        {{'=', 'ack_send_error', data['error']}})
    if err ~= nil then
        log.info(err)
    end
end

-- В smev_message_recived для сообщения где messageId = message_Id
-- в ack_response_xml_guid записывается xmlRef, в end_ack_send_date
-- записывается текущее дата и время, значение ack_send_error обнуляется
local function endAckSending(data)
    local date = datetime.parse(os.date("!%Y-%m-%dT%H:%M:%SZ", fiber.time()))
    local _, err = crud.update('smev_message_recived', data['message_id'],
        {{'=', 'ack_response_xml_guid', data['xmlRef']},
         {'=', 'end_ack_send_date', date},
         {'=', 'ack_send_error', nil},})
    if err ~= nil then
        log.info(err)
    end
end


local exported_functions = {
    checkExistSMEVMessage = checkExistSMEVMessage,
    saveSMEVMessage = saveSMEVMessage,
    saveSMEVRequest = saveSMEVRequest,
    faultErrorSMEVSending = faultErrorSMEVSending,
    httpErrorSMEVSending = httpErrorSMEVSending,
    endSMEVSending = endSMEVSending,
    saveAckRequest = saveAckRequest,
    faultErrorAckSending = faultErrorAckSending,
    httpErrorAckSending = httpErrorAckSending,
    endAckSending = endAckSending,
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
    role_name = 'app.roles.api',
    init = init,
    dependencies = {'cartridge.roles.crud-router'},
}

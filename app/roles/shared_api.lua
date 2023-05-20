local crud = require('crud')
local log = require('log')
local tnt_kafka = require('kafka')
local json = require('json')
local datetime = require('datetime')
local string = require('string')

local producer = tnt_kafka.Producer.create({ brokers = "localhost:9092" })

local function map_date(date)
    if date ~= nil then
        local Date = string.rstrip(date:format(), '00')
        Date = Date .. ':00'
        return Date
    else
        return nil
    end
end

local function get_date()
    local fiber = require 'fiber'
    local dt = datetime.new {
        timestamp = fiber.time()+25200,
        tzoffset  = 420
    }
    return dt
end

local function send_kafka_bft_smev(message_id)
    local msg, err = crud.select('smev_message_recived', {{'=', 'message_id', message_id}})
    if err ~= nil then
        log.info(err)
    end
    msg = crud.unflatten_rows(msg.rows, msg.metadata)
    local msg = { messageId = msg[1].message_id, ack_priority = msg[1].ack_priority }
    msg = json.encode(msg)
    local err = producer:produce_async({
        topic = "bft_smev_adapter_ack_service",
        value = msg
    })
    if err ~= nil then
        log.info("got error '%s' while sending value", err)
    else
        log.info("successfully sent value to kafka")
    end
end

local function send_kafka_processing(message_id)
    local msg, err = crud.select('smev_message_recived', {{'=', 'message_id', message_id}})
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
        log.info("got error '%s' while sending value", err)
    else
        log.info("successfully sent to kafka")
    end
end

local function send_kafka_bft_smev_adapter_iis_router_service(id)
    local msg, err = crud.select('smev_message_to_iis', {{'=', 'id', id}})
    if err ~= nil then
        log.info(err)
    end
    msg = crud.unflatten_rows(msg.rows, msg.metadata)
    local msg = { messageId = msg[1].parent_message_id, smevNamespace = msg[1].smev_namespace,
                  iisXmlGuid = msg[1].iis_xml_guid }
    msg = json.encode(msg)
    local err = producer:produce_async({
        topic = "bft_smev_adapter_iis_router_service",
        value = msg
    })
    if err ~= nil then
        log.info("got error '%s' while sending value", err)
    else
        log.info("successfully sent to kafka")
    end
end

local function init(opts)
    if opts.is_master then
        box.schema.user.grant('guest',
            'read,write,execute',
            'universe',
            nil, { if_not_exists = true }
        )
    end

    return true
end

return {
    role_name = 'app.roles.shared_api',
    init = init,
    map_date = map_date,
    get_date = get_date,
    send_kafka_bft_smev = send_kafka_bft_smev,
    send_kafka_processing = send_kafka_processing,
    send_kafka_bft_smev_adapter_iis_router_service = send_kafka_bft_smev_adapter_iis_router_service,
    dependencies = {'cartridge.roles.crud-router'},
}

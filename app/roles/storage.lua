local function init_spaces()
    -- smev_message_recived
    local smev_message_recived = box.schema.space.create(
        'smev_message_recived',
        {
            format = {
                -- Идентификатор сообщения полученного из СМЭВ
                {name = 'message_id', type = 'string', is_nullable=false},
                -- namespace сообщения из СМЭВ
                {name = 'smev_namespace', type = 'string', is_nullable=false},
                -- Идентификатор XML файла конверта в ЭА полученного из СМЭВ
                {name = 'smev_xml_guid', type = 'string', is_nullable=false},
                -- Массив идентификаторов вложений
                {name = 'attachment_guids', type = 'array', is_nullable=false},
                -- Дата получения сообщения
                {name = 'create_date', type = 'datetime', is_nullable=false},
                -- ?
                {name = 'smev_message_date', type = 'datetime', is_nullable=false},
                -- ?
                {name = 'processing_topic_name', type = 'string', is_nullable=false},
                -- Дата начала обработки сообщения
                {name = 'start_processing_date', type = 'datetime', is_nullable=true},
                -- ?
                {name = 'processing_context', type = 'varbinary', is_nullable=true},
                -- Текст ошибки
                {name = 'processing_error', type = 'string', is_nullable=true},
                -- Дата окончания обработки сообщения
                {name = 'end_processing_date', type = 'datetime', is_nullable=true},
                -- Дата начала отправки ack
                {name = 'start_ack_send_date', type = 'datetime', is_nullable=true},
                -- Идентификатор в ЭА XML запроса
                {name = 'ack_request_xml_guid', type = 'string', is_nullable=true},
                -- Идентификатор в ЭА XML ответа
                {name = 'ack_response_xml_guid', type = 'string', is_nullable=true},
                -- Приоритет
                {name = 'ack_priority', type = 'integer', is_nullable=true},
                -- Текст ошибки
                {name = 'ack_send_error', type = 'string', is_nullable=true},
                -- Дата окончания отправки
                {name = 'end_ack_send_date', type = 'datetime', is_nullable=true},
                -- bucket_id
                {name = 'bucket_id', type = 'unsigned'},
            },
            if_not_exists = true,
        }
    )
    smev_message_recived:create_index('message_id', {
        parts = {{field = 'message_id'}},
        if_not_exists = true,
    })
    smev_message_recived:create_index('bucket_id', {
        parts = {{field = 'bucket_id'}},
        if_not_exists = true, unique= false,
    })

    -- smev_message_to_iis
    local smev_message_to_iis = box.schema.space.create(
        'smev_message_to_iis',
        {
            format = {
                -- Идентификатор сообщения
                {name = 'id', type = 'string', is_nullable=false},
                -- Идентификатор или идентификаторы родительских сообщений полученных из СМЭВ
                {name = 'parent_message_id', type = 'array', is_nullable=false},
                -- 	СМЭВ namespace
                {name = 'smev_namespace', type = 'string', is_nullable=false},
                -- Тело сообщения после обработки
                {name = 'body', type = 'varbinary', is_nullable=false},
                -- Дата начала обработки сообщения
                {name = 'start_send_date', type = 'datetime', is_nullable=true},
                -- Тело запроса при отправке сообщения
                {name = 'iis_request_xml_guid', type = 'string', is_nullable=true},
                -- Тело ответа
                {name = 'iis_response_xml_guid', type = 'string', is_nullable=true},
                -- ?
                {name = 'iis_sending_error', type = 'string', is_nullable=true},
                -- Дата окончания обработки сообщения
                {name = 'end_send_date', type = 'datetime', is_nullable=true},
                -- bucket_id
                {name = 'bucket_id', type = 'unsigned'},
            },
            if_not_exists = true,
        }
    )
    smev_message_to_iis:create_index('id', {
        parts = {{field = 'id'}},
        if_not_exists = true,
    })
    smev_message_to_iis:create_index('bucket_id', {
        parts = {{field = 'bucket_id'}},
        if_not_exists = true, unique= false,
    })

    -- iis_message_recived
    local iis_message_recived = box.schema.space.create(
        'iis_message_recived',
        {
            format = {
                -- 	Идентификатор сообщения полученного из СМЭВ
                {name = 'message_id', type = 'string', is_nullable=false},
                -- СМЭВ namespace
                {name = 'smev_namespace', type = 'string', is_nullable=false},
                -- Идентификатор XML файла конверта в ЭА полученного из ИИС
                {name = 'iis_xml_guid', type = 'string', is_nullable=false},
                -- 	Дата получения сообщения
                {name = 'create_date', type = 'datetime', is_nullable=false},
                -- Дата начала обработки сообщения
                {name = 'start_processing_date', type = 'datetime', is_nullable=true},
                -- ?
                {name = 'processing_context', type = 'varbinary', is_nullable=true},
                -- ?
                {name = 'processing_error', type = 'string', is_nullable=true},
                -- Дата окончания обработки сообщения
                {name = 'end_processing_date', type = 'datetime', is_nullable=true},
                -- bucket_id
                {name = 'bucket_id', type = 'unsigned'},
            },
            if_not_exists = true,
        }
    )
    iis_message_recived:create_index('message_id', {
        parts = {{field = 'message_id'}},
        if_not_exists = true,
    })
    iis_message_recived:create_index('bucket_id', {
        parts = {{field = 'bucket_id'}},
        if_not_exists = true, unique= false,
    })

    -- iis_message_to_smev
    local iis_message_to_smev = box.schema.space.create(
        'iis_message_to_smev',
        {
            format = {
                -- Идентификатор сообщения
                {name = 'id', type = 'string', is_nullable=false},
                -- Идентификатор или идентификаторы родительских сообщений полученных из ИИС
                {name = 'message_id', type = 'array', is_nullable=false},
                -- СМЭВ namespace
                {name = 'smev_namespace', type = 'string', is_nullable=false},
                -- ?
                {name = 'body', type = 'varbinary', is_nullable=false},
                -- Дата начала обработки сообщения
                {name = 'start_send_date', type = 'datetime', is_nullable=true},
                -- Тело запроса при отправке сообщения
                {name = 'smev_request_xml_guid', type = 'string', is_nullable=true},
                -- Тело ответа
                {name = 'smev_response_xml_guid', type = 'string', is_nullable=true},
                -- ?
                {name = 'smev_send_error', type = 'string', is_nullable=true},
                -- Дата окончания обработки сообщения
                {name = 'end_send_date', type = 'datetime', is_nullable=true},
                -- ?
                {name = 'reply_to_xml', type = 'string', is_nullable=true},
                -- ?
                {name = 'reply_to_message_id', type = 'string', is_nullable=true},
                -- bucket_id
                {name = 'bucket_id', type = 'unsigned'},
            },
            if_not_exists = true,
        }
    )
    iis_message_to_smev:create_index('id', {
        parts = {{field = 'id'}},
        if_not_exists = true,
    })
    iis_message_to_smev:create_index('bucket_id', {
        parts = {{field = 'bucket_id'}},
        if_not_exists = true, unique= false,
    })
end

local function init(opts)
    if opts.is_master then
        init_spaces()
    end
    rawset(_G, "ddl", { get_schema = require("ddl").get_schema })
    return true
end

return {
    role_name = 'app.roles.storage',
    init = init,
    dependencies = {
        'cartridge.roles.crud-storage',
    },
}

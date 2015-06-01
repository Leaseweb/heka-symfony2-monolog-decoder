-- https://github.com/Seldaek/monolog/blob/master/doc/usage.md
--
-- context is filled like this: $logger->addInfo('Adding a new user', array('username' => 'Seldaek'));
-- extra is filled using monolog processor plugins
--
--
-- [2015-06-01 21:32:25] app.WARNING: My message logged with monolog [] {"token":"5568804fb7570"}
--
--  +------------------  +-- ------+  -----------------------------+ -+ ------------------------+
--  |                    |         |                               |  |                         |
--  +- date              |         |                               |  |                         |
--                       |         |                               |  |                         |
--                       |         +- the monolog log level        |  |                         |
--                       |                                         |  |                         |
--                       +- the monolog channel                    |  |                         |
--                                                                 |  |                         |
--                         the actual message logged with monolog -+  |                         |
--                                                                    |                         |
--                the monolog `context` field is a valid json object -+                         |
--                                                                                              |
--                                                  the monolog `extra` is a valid json object -+
require "string"
require "cjson"

local msg = {
    Timestamp = nil,
    Hostname  = nil,
    Payload   = nil,
    Pid       = nil,
    Severity  = nil,
    Fields    = {}
}

function table_concat(...)
    local t = {}

    for i = 1, arg.n do
        local array = arg[i]
        if (type(array) == "table") then
            for key, val in next, array do
                if key then t[key] = val end
            end
        end
    end

    return t
end

function process_message ()
    local log = read_message("Payload")

    if not log then return -1 end

    -- Parse symfony2 style monolog messages.
    local regex = "^%[([^%]]+)%] (%a+)%.(%a+): (.+) ([{%[].*[}%]]) ([{%[].*[}%]])"
    _, _, date, msg.Fields.channel, msg.Fields.levelname, msg.Payload, context, extra = string.find(log, regex)

    -- context and extra are valid json datastructures.
    local json_context = cjson.decode(context)
    local json_extra = cjson.decode(extra)

    -- Merge the key/value pairs into the message fields.
    msg.Fields = table_concat(msg.Fields, json_extra, json_context)

    if not pcall(inject_message, msg) then return -1 end

    return 0
end

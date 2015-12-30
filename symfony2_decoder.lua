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
local dt = require "date_time"
local grammar = dt.build_strftime_grammar("%Y-%m-%d %H:%M:%S")

local monolog_pattern = "^%[([^%]]+)%] (%a+)%.(%a+): (.-) ([{%[].*[}%]]) ([{%[].*[}%]])"
local date_pattern = '^(%d+-%d+-%d+) (%d+:%d+:%d+)'

local severity_map = {
    DEBUG = 7,
    INFO = 6,
    NOTICE = 5,
    WARNING = 4,
    ERROR = 3,
    CRITICAL = 2,
    ALERT = 1,
    EMERGENCY = 0
}

function recursively_find_datastructure(message)
    local _, _, payload2, context = string.find(message, "^(.-) ([{%[].*[}%]])")

    local success, json_context = pcall(cjson.decode, context);
    if (not success) then
        return recursively_find_datastructure(string.sub(context, 2))
    end

    return context
end

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

    if not log then
        return -1
    end

    -- Parse symfony2 style monolog messages.
    local _, _, date, channel, levelname, payload, context_maybe, extra = string.find(log, monolog_pattern)

    -- try to decode the first json datastructure
    local success, json_context = pcall(cjson.decode, context_maybe);
    if (not success) then
        -- the first decode attempt failed, this means the above regex was not greedy enough
        -- recursively find the datastructure
        local context = recursively_find_datastructure(context_maybe)
        payload = payload .. ' ' .. string.sub(context_maybe, 1, string.len(context_maybe) - string.len(context) - 1)
        json_context = cjson.decode(context)
    end

    local json_extra = cjson.decode(extra)

    local msg = {
        Timestamp = nil,
        Payload   = nil,
        Severity  = nil,
        Fields    = {}
    }

    local d = grammar:match(date)
    if d then
        msg.Timestamp = dt.time_to_ns(d)
    end

    msg.Severity = severity_map[levelname]
    msg.Payload = payload
    msg.Fields.channel = channel
    msg.Fields.levelname = levelname

    -- Merge the key/value pairs into the message fields.
    msg.Fields = table_concat(msg.Fields, json_extra, json_context)

    if not pcall(inject_message, msg) then return -1 end

    return 0
end


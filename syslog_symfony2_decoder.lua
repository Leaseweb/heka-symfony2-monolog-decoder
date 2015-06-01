-- http://rsyslog-5-8-6-doc.neocities.org/rsyslog_conf_templates.html
-- https://github.com/Seldaek/monolog/blob/master/doc/usage.md
--
-- context is filled like this: $logger->addInfo('Adding a new user', array('username' => 'Seldaek'));
--
-- extra is filled using monolog processor plugins
--
--
-- syslog part                                   monolog part
-- --------------------------------------- ------------------------------------------------------------------------
--
-- May 29 17:05:51 app-myapi myapi[22771]: app.WARNING: My message logged with monolog [] {"token":"5568804fb7570"}
--
-- +-------------- +-------- +---- +----   +-- ------+  -----------------------------+ -+ ------------------------+
-- |               |         |     |       |         |                               |  |                         |
-- |               |         |     |       |         +- the monolog log level        |  |                         |
-- |               |         |     |       |                                         |  |                         |
-- |               |         |     |       +- the monolog channel                    |  |                         |
-- |               |         |     |                                                 |  |                         |
-- |               |         |     +- the pid of the process that logged             |  |                         |
-- |               |         |                                                       |  |                         |
-- |               |         +- the name of the process that logged                  |  |                         |
-- |               |                                                                 |  |                         |
-- |               +- the hostname of the machine that logged                        |  |                         |
-- |                                                                                 |  |                         |
-- +- the date of the log message                                                    |  |                         |
--                                                                                   |  |                         |
--                                           the actual message logged with monolog -+  |                         |
--                                                                                      |                         |
--                                  the monolog `context` field is a valid json object -+                         |
--                                                                                                                |
--                                                                    the monolog `extra` is a valid json object -+
require "string"
require "cjson"

local syslog = require "syslog"

local template = read_config("template")
local msg_type = read_config("type")
local hostname_keep = read_config("hostname_keep")

local msg = {
    Timestamp = nil,
    Type      = msg_type,
    Hostname  = nil,
    Payload   = nil,
    Pid       = nil,
    Severity  = nil,
    Fields    = nil
}

local grammar = syslog.build_rsyslog_grammar(template)

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
    local fields = grammar:match(log)
    if not fields then return -1 end

    if fields.timestamp then
        msg.Timestamp = fields.timestamp
        fields.timestamp = nil
    end

    if fields.pri then
        msg.Severity = fields.pri.severity
        fields.syslogfacility = fields.pri.facility
        fields.pri = nil
    else
        msg.Severity = fields.syslogseverity or fields["syslogseverity-text"]
        or fields.syslogpriority or fields["syslogpriority-text"]

        fields.syslogseverity = nil
        fields["syslogseverity-text"] = nil
        fields.syslogpriority = nil
        fields["syslogpriority-text"] = nil
    end

    if fields.syslogtag then
        fields.programname = fields.syslogtag.programname
        msg.Pid = fields.syslogtag.pid
        fields.syslogtag = nil
    end

    if not hostname_keep then
        msg.Hostname = fields.hostname or fields.source
        fields.hostname = nil
        fields.source = nil
    end

    -- Parse symfony2 style monolog messages.
    local regex = "^(%a+)%.(%a+): (.+) ([{%[].*[}%]]) ([{%[].*[}%]])$"
    _, _, fields.channel, fields.levelname, msg.Payload, context, extra = string.find(fields.msg, regex)

    fields.msg = nil

    -- context and extra are valid json datastructures.
    local json_context = cjson.decode(context)
    local json_extra = cjson.decode(extra)

    -- Merge the key/value pairs into the message fields.
    msg.Fields = table_concat(fields, json_extra, json_context)

    if not pcall(inject_message, msg) then return -1 end

    return 0
end

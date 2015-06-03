# heka-symfony2-monolog-decoder

A heka decode written in lua for parsing symfony2 formatted monolog messages


## installation

You can place the `lua` decoders anywhere as long as `heka` can read them.


## usage

There are two decoders available. One for decoding log messages in your
`app/logs` directory and another one that decodes monolog messages that were
logged to syslog (useful if you configured your Symfony 2 application to log
to syslog).


### usage: monolog decoder

To use the plain `Symfony2 Monolog Decoder` put the following in your
`/etc/hekad.toml`:

    $ cat /etc/hekad.toml
    [Symfony2MonologFileInput]
    type = "LogstreamerInput"
    log_directory = "/var/www/app/logs"
    file_match = 'prod\.log'
    decoder = "Symfony2MonologDecoder"

    [Symfony2MonologDecoder]
    type = "SandboxDecoder"
    filename = "/etc/symfony2_decoder.lua"


Adjust `log_directory` and `filename` according to your setup.


### usage: syslog monolog decoder

To use the `Syslog Symfony2 Monolog Decoder` you need to configure your
symfony2 application to log to syslog by changing `config_prod.yml`:

    $ cat app/config/config_prod.yml
    # ...
    monolog:
        handlers:
            main:
                type: syslog
                ident: myapplication
    # ...


And configure `rsyslog` to send all logs with application name `myapplication`
to a seperate file:

    $ cat /etc/rsyslog.d/90-myapplication.conf
    if $programname == 'myapplication' then /var/log/myapi.log


Where `programname` and `ident` are the same string.

Now you can configure `heka` to watch this file:

    $ cat /etc/hekad.toml
    [SyslogSymfony2MonologFileInput]
    type = "LogstreamerInput"
    log_directory = "/var/log"
    file_match = 'bmpapi\.log'
    decoder = "SyslogSymfony2MonologDecoder"

    [SyslogSymfony2MonologDecoder]
    type = "SandboxDecoder"
    filename = "/etc/syslog_symfony2_decoder.lua"

    [SyslogSymfony2MonologDecoder.config]
    type = "RSYSLOG_TraditionalForwardFormat"
    template = '%TIMESTAMP% %HOSTNAME% %syslogtag:1:32%%msg:::sp-if-no-1st-sp%%msg%'
    tz = "Europe/Amsterdam"


For debugging purposes you can use the build-in `RstEncoder` to see how the
fields get serialized:

    $ cat /etc/hekad.toml
    # ...
    [RstEncoder]

    [LogOutput]
    message_matcher = "TRUE"
    encoder = "RstEncoder"
    # ...


## contribute

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## license

apache 2.0 -- see [LICENSE](https://github.com/LeaseWeb/heka-symfony2-monolog-decoder/blob/master/LICENSE) for more details.

# themis-finals-checker-server
[![Latest Version](https://img.shields.io/gem/v/themis-finals-checker-server.svg?style=flat-square)](https://rubygems.org/gems/themis-finals-checker-server)
[![License](https://img.shields.io/github/license/aspyatkin/themis-finals-checker-server.svg?style=flat-square)](https://github.com/aspyatkin/themis-finals-checker-server/blob/master/LICENSE)
[![Dependencies status](https://img.shields.io/gemnasium/aspyatkin/themis-finals-checker-server.svg?style=flat-square)](https://gemnasium.com/aspyatkin/themis-finals-checker-server)
[![Code Climate](https://img.shields.io/codeclimate/github/aspyatkin/themis-finals-checker-server.svg?style=flat-square)](https://codeclimate.com/github/aspyatkin/themis-finals-checker-server)  
A Ruby gem to create service checker for [Themis Finals](https://github.com/aspyatkin/themis-finals) attack-defence CTF checking system.

## Installation
```sh
gem install themis-finals-checker-server
```
or just add `gem 'themis-finals-checker-server'` to your Gemfile and run `bundle`.

## Example
A service checker should subclass `Themis::Finals::Checker::Server` and override two methods.

Here's an example:

```ruby
require 'themis/finals/checker/server'
require 'themis/finals/checker/result'

class SampleChecker < Themis::Finals::Checker::Server
    def push(endpoint, flag, adjunct, metadata)
        # business logic...
        return Themis::Finals::Checker::Result::UP, adjunct
    end

    def pull(endpoint, flag, adjunct, metadata)
        # business logic...
        Themis::Finals::Checker::Result::UP
    end
end

checker = SampleChecker.new
checker.run
```

### Operation status
See [themis-finals-checker-result](https://github.com/aspyatkin/themis-finals-checker-result).

## Configuration
Several environment variables should be specified to run service checker process:
### `BEANSTALKD_URI`
A connection string for Beanstalk server.
### `TUBE_LISTEN`
A Beanstalk tube to listen to commands from `Themis Finals` server.
### `TUBE_REPORT`
A Beanstalk tube to report operation results to `Themis Finals` server.
### `LOG_LEVEL`
An optional service checker log level. One of `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` or `UNKNOWN`. Default is `INFO`.
### `STDOUT_SYNC`
An optional parameter controlling `$stdout.sync`.

## Tips
### Logging
There is a class member `logger`. You can use it in overriden `push` and `pull` methods as `@logger`.
### Stopping service checker
Service checker process stops on `INT` signal.
### Configuration for [God](https://github.com/mojombo/god) process manager
```ruby
(0...2).to_a.each do |num|
    God.watch do |w|
        w.group = 'SERVICE_ALIAS'
        w.name = "SERVICE_ALIAS-#{num}"
        w.dir = '/path/to/checker'
        w.uid = 'nobody'
        w.gid = 'nogroup'
        w.log = "/path/to/checker/logs/checker-#{num}.log"
        w.start = 'bundle exec ruby checker.rb'
        w.env = {
            'BEANSTALKD_URI' => '127.0.0.1:11300',
            'LOG_LEVEL' => 'INFO',
            'STDOUT_SYNC' => 'true',
            'TUBE_LISTEN' => 'themis.finals.service.SERVICE_ALIAS.listen',
            'TUBE_REPORT' => 'themis.finals.service.SERVICE_ALIAS.report'
        }
        w.stop_signal = 'INT'
        w.keepalive
    end
end
```
### Configuration for [Supervisor](http://supervisord.org) process manager
```
[program:themis.finals.service.SERVICE_ALIAS.checker]
command=/opt/rbenv/shims/bundle exec ruby checker.rb
process_name=checker-%(process_num)s
numprocs=2
numprocs_start=0
priority=300
autostart=false
autorestart=true
startsecs=1
startretries=3
exitcodes=0,2
stopsignal=INT
stopwaitsecs=10
stopasgroup=false
killasgroup=false
user=nobody
redirect_stderr=false
stdout_logfile=/path/to/checker/logs/checker-%(process_num)s-stdout.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=10
stdout_capture_maxbytes=0
stdout_events_enabled=false
stderr_logfile=/path/to/checker/logs/checker-%(process_num)s-stderr.log
stderr_logfile_maxbytes=10MB
stderr_logfile_backups=10
stderr_capture_maxbytes=0
stderr_events_enabled=false
environment=APP_INSTANCE="%(process_num)s",BEANSTALKD_URI="127.0.0.1:11300",LOG_LEVEL="DEBUG",STDOUT_SYNC="true",TUBE_LISTEN="themis.finals.service.SERVICE_ALIAS.listen",TUBE_REPORT="themis.finals.service.SERVICE_ALIAS.report"
directory=/path/to/checker
serverurl=AUTO

[group:themis.finals.service.SERVICE_ALIAS]
programs=themis.finals.service.SERVICE_ALIAS.checker
```

## License
MIT @ [Alexander Pyatkin](https://github.com/aspyatkin)

require 'logger'
require 'json'
require 'beaneater'
require 'themis/checker/result'
require 'base64'
require 'date'
require 'time_difference'
require 'raven/base'


module Themis
    module Checker
        class Server
            def initialize
                @logger = self.get_logger
                @beanstalk = nil

                if self.raven_enabled?
                    Raven.configure do |config|
                        config.dsn = ENV['SENTRY_DSN']
                        config.ssl_verification = false
                        config.logger = @logger
                        config.async = lambda { |event|
                            Thread.new { Raven.send_event(event) }
                        }
                    end
                end
            end

            def raven_enabled?
                not ENV['SENTRY_DSN'].nil?
            end

            def run
                @beanstalk = Beaneater.new ENV['BEANSTALKD_URI']
                @logger.info 'Connected to beanstalk server'

                @beanstalk.jobs.register ENV['TUBE_LISTEN'] do |job|
                    job_data = JSON.parse job.body
                    job_result = nil

                    case job_data['operation']
                    when 'push'
                        metadata = job_data['metadata']
                        timestamp_created = DateTime.iso8601 metadata['timestamp']
                        timestamp_delivered = DateTime.now

                        status, updated_adjunct = self.internal_push(
                            job_data['endpoint'],
                            job_data['flag'],
                            Base64.decode64(job_data['adjunct']),
                            metadata
                        )

                        timestamp_processed = DateTime.now

                        job_result = {
                            operation: job_data['operation'],
                            status: status,
                            flag: job_data['flag'],
                            adjunct: Base64.encode64(updated_adjunct)
                        }

                        delivery_time = TimeDifference.between(timestamp_created, timestamp_delivered).in_seconds
                        processing_time = TimeDifference.between(timestamp_delivered, timestamp_processed).in_seconds

                        log_message = 'PUSH flag `%s` /%d to `%s`@`%s` (%s) - status %s, adjunct `%s` [delivery %.2fs, processing %.2fs]' % [
                            job_data['flag'],
                            metadata['round'],
                            metadata['service_name'],
                            metadata['team_name'],
                            job_data['endpoint'],
                            Themis::Checker::Result.key(status),
                            job_result[:adjunct],
                            delivery_time,
                            processing_time
                        ]

                        if self.raven_enabled?
                            short_log_message = 'PUSH `%s...` /%d to `%s` - status %s' % [
                                job_data['flag'][0..7],
                                metadata['round'],
                                metadata['team_name'],
                                Themis::Checker::Result.key(status)
                            ]

                            Raven.capture_message short_log_message, {
                                level: 'info',
                                tags: {
                                    tf_operation: 'push',
                                    tf_status: Themis::Checker::Result.key(status).to_s,
                                    tf_team: metadata['team_name'],
                                    tf_service: metadata['service_name'],
                                    tf_round: metadata['round']
                                },
                                extra: {
                                    endpoint: job_data['endpoint'],
                                    flag: job_data['flag'],
                                    adjunct: job_result[:adjunct],
                                    delivery_time: delivery_time,
                                    processing_time: processing_time
                                }
                            }
                        end

                        @logger.info log_message
                    when 'pull'
                        metadata = job_data['metadata']
                        timestamp_created = DateTime.iso8601 metadata['timestamp']
                        timestamp_delivered = DateTime.now

                        status = self.internal_pull(
                            job_data['endpoint'],
                            job_data['flag'],
                            Base64.decode64(job_data['adjunct']),
                            job_data['metadata']
                        )

                        timestamp_processed = DateTime.now

                        job_result = {
                            operation: job_data['operation'],
                            request_id: job_data['request_id'],
                            status: status
                        }

                        delivery_time = TimeDifference.between(timestamp_created, timestamp_delivered).in_seconds
                        processing_time = TimeDifference.between(timestamp_delivered, timestamp_processed).in_seconds

                        begin
                            log_message = 'PULL flag `%s` /%d from `%s`@`%s` (%s) with adjunct `%s` - status %s [delivery %.2fs, processing %.2fs]' % [
                                job_data['flag'],
                                metadata['round'],
                                metadata['service_name'],
                                metadata['team_name'],
                                job_data['endpoint'],
                                job_data['adjunct'],
                                Themis::Checker::Result.key(status),
                                delivery_time,
                                processing_time
                            ]

                            if self.raven_enabled?
                                short_log_message = 'PULL `%s...` /%d from `%s` - status %s' % [
                                    job_data['flag'][0..7],
                                    metadata['round'],
                                    metadata['team_name'],
                                    Themis::Checker::Result.key(status)
                                ]

                                Raven.capture_message short_log_message, {
                                    level: 'info',
                                    tags: {
                                        tf_operation: 'pull',
                                        tf_status: Themis::Checker::Result.key(status).to_s,
                                        tf_team: metadata['team_name'],
                                        tf_service: metadata['service_name'],
                                        tf_round: metadata['round']
                                    },
                                    extra: {
                                        endpoint: job_data['endpoint'],
                                        flag: job_data['flag'],
                                        adjunct: job_data['adjunct'],
                                        delivery_time: delivery_time,
                                        processing_time: processing_time
                                    }
                                }
                            end
                        rescue Exception => e
                            if self.raven_enabled?
                                Raven.capture_exception e
                            end
                            @logger.error e.message
                            e.backtrace.each { |line| @logger.error line }
                        end

                        @logger.info log_message
                    else
                        @logger.warn 'Unknown job!'
                    end

                    unless job_result.nil?
                        report_tube = @beanstalk.tubes[ENV['TUBE_REPORT']]
                        report_tube.put job_result.to_json
                    end
                end

                begin
                    @beanstalk.jobs.process!
                rescue Interrupt
                    @logger.info 'Received shutdown signal'
                end
                @beanstalk.close
                @logger.info 'Disconnected from beanstalk server'
            end

            def push(endpoint, flag, adjunct, metadata)
                raise NotImplementedError, 'Push flag logic not implemented!'
            end

            def pull(endpoint, flag, adjunct, metadata)
                raise NotImplementedError, 'Pull flag logic not implemented!'
            end

            protected
            def get_logger
                logger = ::Logger.new STDOUT

                # Setup log formatter
                logger.datetime_format = '%Y-%m-%d %H:%M:%S'
                logger.formatter = proc do |severity, datetime, progname, msg|
                    "[#{datetime}] #{severity} -- #{msg}\n"
                end

                $stdout.sync = ENV['STDOUT_SYNC'] == 'true'

                # Setup log level
                case ENV['LOG_LEVEL']
                when 'DEBUG'
                    logger.level = ::Logger::DEBUG
                when 'INFO'
                    logger.level = ::Logger::INFO
                when 'WARN'
                    logger.level = ::Logger::WARN
                when 'ERROR'
                    logger.level = ::Logger::ERROR
                when 'FATAL'
                    logger.level = ::Logger::FATAL
                when 'UNKNOWN'
                    logger.level = ::Logger::UNKNOWN
                else
                    logger.level = ::Logger::INFO
                end
                logger
            end

            def internal_push(endpoint, flag, adjunct, metadata)
                result, updated_adjunct = Themis::Checker::Result::INTERNAL_ERROR, adjunct
                begin
                    result, updated_adjunct = self.push endpoint, flag, adjunct, metadata
                rescue Interrupt
                    raise
                rescue Exception => e
                    if self.raven_enabled?
                        Raven.capture_exception e
                    end
                    @logger.error e.message
                    e.backtrace.each { |line| @logger.error line }
                end

                return result, updated_adjunct
            end

            def internal_pull(endpoint, flag, adjunct, metadata)
                result = Themis::Checker::Result::INTERNAL_ERROR
                begin
                    result = self.pull endpoint, flag, adjunct, metadata
                rescue Interrupt
                    raise
                rescue Exception => e
                    if self.raven_enabled?
                        Raven.capture_exception e
                    end
                    @logger.error e.message
                    e.backtrace.each { |line| @logger.error line }
                end

                result
            end
        end
    end
end

require 'logger'
require 'json'
require 'beaneater'
require 'themis/checker/result'
require 'base64'
require 'date'
require 'time_difference'


module Themis
    module Checker
        class Server
            def initialize
                @logger = self.get_logger
                @beanstalk = nil
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

                        @logger.info('PUSH flag `%s` /%d to `%s`@`%s` (%s) — status %s, adjunct `%s` [delivery %.2fs, processing %.2fs]' % [
                            job_data['flag'],
                            metadata['round'],
                            metadata['service_name'],
                            metadata['team_name'],
                            job_data['endpoint'],
                            Themis::Checker::Result.key(status),
                            job_result[:adjunct],
                            TimeDifference.between(timestamp_created, timestamp_delivered).in_seconds,
                            TimeDifference.between(timestamp_delivered, timestamp_processed).in_seconds
                        ])
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

                        @logger.info('PULL flag `%s` /%d from `%s`@`%s` (%s) with adjunct `%s` — status %s [delivery %.2fs, processing %.2fs]' % [
                            job_data['flag'],
                            metadata['round'],
                            metadata['service_name'],
                            metadata['team_name'],
                            job_data['endpoint'],
                            job_data['adjunct'],
                            Themis::Checker::Result.key(status),
                            TimeDifference.between(timestamp_created, timestamp_delivered).in_seconds,
                            TimeDifference.between(timestamp_delivered, timestamp_processed).in_seconds
                        ])
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
                    @logger.error e.message
                    e.backtrace.each { |line| @logger.error line }
                end

                result
            end
        end
    end
end

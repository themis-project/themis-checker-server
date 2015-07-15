require 'logger'
require 'json'
require 'beaneater'
require 'themis/checker/result'


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
                        status, flag_id = self.internal_push(
                            job_data['endpoint'],
                            job_data['flag_id'],
                            job_data['flag']
                        )

                        job_result = {
                            operation: job_data['operation'],
                            status: status,
                            flag: job_data['flag'],
                            flag_id: flag_id,
                            endpoint: job_data['endpoint']
                        }

                        @logger.info "PUSH flag #{job_data['flag']} to #{job_data['endpoint']}: result #{status}, flag_id #{flag_id}"
                    when 'pull'
                        status = self.internal_pull(
                            job_data['endpoint'],
                            job_data['flag_id'],
                            job_data['flag']
                        )

                        job_result = {
                            operation: job_data['operation'],
                            request_id: job_data['request_id'],
                            status: status
                        }

                        @logger.info "PULL flag #{job_data['flag']} from #{job_data['endpoint']} with flag_id #{job_data['flag_id']}: result #{status}"
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

            def push(endpoint, flag_id, flag)
                raise NotImplementedError, 'Push flag logic not implemented!'
            end

            def pull(endpoint, flag_id, flag)
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

            def internal_push(endpoint, flag_id, flag)
                result, new_flag_id = Themis::Checker::Result::INTERNAL_ERROR, flag_id
                begin
                    result, new_flag_id = self.push endpoint, flag_id, flag
                rescue Interrupt
                    raise
                rescue Exception => e
                    @logger.error e.message
                    e.backtrace.each { |line| @logger.error line }
                end

                return result, new_flag_id
            end

            def internal_pull(endpoint, flag_id, flag)
                result = Themis::Checker::Result::INTERNAL_ERROR
                begin
                    result = self.pull endpoint, flag_id, flag
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

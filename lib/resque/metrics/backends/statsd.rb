module Resque
  module Metrics
    module Backends
      class Statsd
        attr_accessor :statsd, :metric_prefix

        def initialize(statsd, metric_prefix = 'resque')
          @statsd = statsd
          @metric_prefix = metric_prefix
        end

        def increment_metric(metric, by = 1)
          if metric =~ /^(.+)(?:_job)?_(time|count)(?::(queue|job):(.*))?$/
            event = $1
            event = 'complete' if event == 'job'

            time_or_count = $2
            queue_or_job = $3
            queue_or_job_name = $4
            key = if queue_or_job && queue_or_job_name
                    # ie resque.complete.queue.high.count, resque.failed.job.Index.timing
                    "#{metric_prefix}.#{event}.#{queue_or_job}.#{queue_or_job_name}.#{time_or_count}"
                  else

                    # ie resque.complete.time
                    "#{metric_prefix}.#{event}.#{time_or_count}"
                  end
            case time_or_count
            when 'time'
              statsd.timing key, by
            when 'count'
              statsd.count key, by
            else
              raise "Not sure how to increment_metric for a #{time_or_count} metric (#{metric})"
            end
          elsif metric =~ /^payload_size(?::(queue|job):(.*))?$/
            queue_or_job = $1
            queue_or_job_name = $2
            key = if queue_or_job && queue_or_job_name
                    # ie resque.complete.queue.high.count, resque.failed.job.Index.timing
                    "#{metric_prefix}.payload_size.#{queue_or_job}.#{queue_or_job_name}.#{time_or_count}"
                  else
                    "#{metric_prefix}.payload_size.#{time_or_count}"
                  end
            statsd.count key, by
          else
            raise "Not sure how to increment_metric #{metric}"
          end
        end

        def set_metric(metric, val)
          if metric =~ /^depth(?::(failed|pending|queue)(?::(.+))?)?$/
            key = "#{metric_prefix}.#{metric.gsub(':', '.')}"
            statsd.gauge key, val
          else
            raise "Not sure how to set_metric #{metric}"
          end
        end

        # set_avg: let statsd & graphite handle that
        # get_metric: would have to talk to graphite. but man, complicated
      end
    end
  end
end


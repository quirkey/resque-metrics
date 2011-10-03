require 'resque'

module Resque
  module Metrics

    VERSION = '0.0.1'

    def self.extended(klass)
      klass.extend(Hooks)
    end

    def self.redis
      Resque.redis
    end

    def self.on_job(&block)
      @on_job_callbacks ||= []
      @on_job_callbacks << block
    end

    def self.record_job(job_class, time)
      queue = Resque.queue_from_class(job_class)
      redis.multi do
        redis.incrby "_metrics_:job_time", time
        redis.incrby "_metrics_:job_time:queue:#{queue}", time
        redis.incrby "_metrics_:job_time:job:#{job_class}", time
        redis.incr "_metrics_:job_count"
        redis.incr "_metrics_:job_count:queue:#{queue}"
        redis.incr "_metrics_:job_count:job:#{job_class}"
      end
      redis.set "_metrics_:avg_time", total_job_time / total_job_count
      redis.set "_metrics_:avg_time:queue:#{queue}", total_job_time_by_queue(queue) / total_job_count_by_queue(queue)
      redis.set "_metrics_:avg_time:job:#{job_class}", total_job_time_by_job(job_class) / total_job_count_by_job(job_class)
      if @on_job_callbacks
        @on_job_callbacks.each {|callback| callback.call(job_class, queue, time) }
      end
    end

    def self.get_metric(metric)
      redis.get("_metrics_:#{metric}").to_i
    end

    def self.avg_job_time
      get_metric "avg_time"
    end

    def self.avg_job_time_by_queue(queue)
      get_metric "avg_time:queue:#{queue}"
    end

    def self.avg_job_time_by_job(job)
      get_metric "avg_time:job:#{job}"
    end

    def self.total_job_time
      get_metric "job_time"
    end

    def self.total_job_time_by_queue(queue)
      get_metric "job_time:queue:#{queue}"
    end

    def self.total_job_time_by_job(job)
      get_metric "job_time:job:#{job}"
    end

    def self.total_job_count
      get_metric "job_count"
    end

    def self.total_job_count_by_queue(queue)
      get_metric "job_count:queue:#{queue}"
    end

    def self.total_job_count_by_job(job)
      get_metric "job_count:job:#{job}"
    end

    module Hooks

      def around_perform_metrics(*args)
        start = Time.now
        yield
        finish = ((Time.now.to_f - start.to_f) * 1000).to_i
        Resque::Metrics.record_job(self, finish)
      end

    end

  end
end

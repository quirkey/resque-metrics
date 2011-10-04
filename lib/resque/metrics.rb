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

    def self.on_job_complete(&block)
      @on_job_complete_callbacks ||= []
      @on_job_complete_callbacks << block
    end

    def self.record_job_enqueue(job_class)
      queue = Resque.queue_from_class(job_class)
      increment_metric "enqueue_count"
      increment_metric "enqueue_count:job:#{job_class}"
      increment_metric "enqueue_count:queue:#{queue}"
      true
    end

    def self.record_job_completion(job_class, time)
      queue = Resque.queue_from_class(job_class)
      redis.multi do
        increment_metric "job_time", time
        increment_metric "job_time:queue:#{queue}", time
        increment_metric "job_time:job:#{job_class}", time
        increment_metric "job_count"
        increment_metric "job_count:queue:#{queue}"
        increment_metric "job_count:job:#{job_class}"
      end
      increment_metric "avg_job_time", total_job_time / total_job_count
      increment_metric "avg_job_time:queue:#{queue}", total_job_time_by_queue(queue) / total_job_count_by_queue(queue)
      increment_metric "avg_job_time:job:#{job_class}", total_job_time_by_job(job_class) / total_job_count_by_job(job_class)
      if @on_job_complete_callbacks
        @on_job_complete_callbacks.each {|callback| callback.call(job_class, queue, time) }
      end
    end

    def self.increment_metric(metric, by = 1)
      redis.incrby("_metrics_:#{metric}", by)
    end

    def self.get_metric(metric)
      redis.get("_metrics_:#{metric}").to_i
    end

    def self.total_enqueue_count
      get_metric "enqueue_count"
    end

    def self.total_enqueue_count_by_job(job)
      get_metric "enqueue_count:job:#{job}"
    end

    def self.total_enqueue_count_by_queue(queue)
      get_metric "enqueue_count:queue:#{queue}"
    end

    def self.avg_job_time
      get_metric "avg_job_time"
    end

    def self.avg_job_time_by_queue(queue)
      get_metric "avg_job_time:queue:#{queue}"
    end

    def self.avg_job_time_by_job(job)
      get_metric "avg_job_time:job:#{job}"
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

      def after_enqueue_metrics(*args)
        Resque::Metrics.record_job_enqueue(self)
      end

      def around_perform_metrics(*args)
        start = Time.now
        yield
        finish = ((Time.now.to_f - start.to_f) * 1000).to_i
        Resque::Metrics.record_job_completion(self, finish)
      end

    end

  end
end

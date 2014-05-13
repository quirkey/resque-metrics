require 'resque'
require 'resque/metrics/backends'

module Resque
  module Metrics

    def self.extended(klass)
      klass.extend(Hooks)
    end

    def self.redis
      @_redis ||= ::Resque.redis
    end

    def self.redis=(redis)
      @_redis = redis
    end

    def self.use_multi=(multi)
      @_use_multi = multi
    end

    def self.use_multi?
      @_use_multi
    end

    def self.backends
      @_backends ||= begin
                       self.backends = [Resque::Metrics::Backends::Redis.new(redis)]
                     end
    end

    def self.backends=(new_backends)
      @_backends = new_backends
    end

    def self.run_backends(method, *args)
      ran_any = false

      backends.each do |backend|
        if backend.respond_to?(method)
          ran_any = true
          backend.send method, *args
        end
      end

      raise "No backend responded to #{method}: #{backends.inspect}" unless ran_any
    end

    def self.run_first_backend(method, *args)
      backend = backends.detect {|backend| backend.respond_to?(method)}
      raise "No backend responds to #{method}: #{backends.inspect}" unless backend

      backend.send method, *args
    end

    def self.watch_fork
      ::Resque.before_fork = before_fork
      ::Resque.after_fork = after_fork
    end

    def self.on_job_fork(&block)
      set_callback(:on_job_fork, &block)
    end

    def self.on_job_complete(&block)
      set_callback(:on_job_complete, &block)
    end

    def self.on_job_enqueue(&block)
      set_callback(:on_job_enqueue, &block)
    end

    def self.on_job_failure(&block)
      set_callback(:on_job_failure, &block)
    end

    def self.set_callback(callback_name, &block)
      @callbacks ||= {}
      @callbacks[callback_name] ||= []
      @callbacks[callback_name] << block
    end

    def self.run_callback(callback_name, *args)
      if @callbacks && @callbacks[callback_name]
        @callbacks[callback_name].each {|callback| callback.call(*args) }
      end
    end

    def self.before_fork
      lambda do |job|
        start = Time.now.to_f * 1000
        key = "_metrics_:fork_start:#{job.worker.to_s}"
        ::Resque.redis.set key, start
        ::Resque.redis.expire key, 60 * 60 * 60
        true
      end
    end

    def self.after_fork
      lambda do |job|
        end_time = Time.now.to_f * 1000
        key = "_metrics_:fork_start:#{job.worker.to_s}"
        start_time = ::Resque.redis.get key
        if start_time
          total = (end_time - start_time.to_f).to_i
          ::Resque::Metrics.record_job_fork(job, total)
        end
        true
      end
    end

    def self.record_job_fork(job, time)
      job_class = job.payload_class
      queue = job.queue
      multi do
        increment_metric "fork_time", time
        increment_metric "fork_time:queue:#{queue}", time
        increment_metric "fork_time:job:#{job_class}", time
        increment_metric "fork_count"
        increment_metric "fork_count:queue:#{queue}"
        increment_metric "fork_count:job:#{job_class}"
      end
      set_avg "avg_fork_time", total_fork_time , total_fork_count
      set_avg "avg_fork_time:queue:#{queue}", total_fork_time_by_queue(queue) , total_fork_count_by_queue(queue)
      set_avg "avg_fork_time:job:#{job_class}", total_fork_time_by_job(job_class) , total_fork_count_by_job(job_class)
      run_callback(:on_job_fork, job_class, queue, time)
    end

    def self.record_job_enqueue(job_class, *args)
      queue = Resque.queue_from_class(job_class)
      increment_metric "enqueue_count"
      increment_metric "enqueue_count:job:#{job_class}"
      increment_metric "enqueue_count:queue:#{queue}"

      size = Resque.encode(args).length
      multi do
        increment_metric "payload_size", size
        increment_metric "payload_size:queue:#{queue}", size
        increment_metric "payload_size:job:#{job_class}", size
      end
      set_avg "avg_payload_size", total_payload_size , total_enqueue_count
      set_avg "avg_payload_size:queue:#{queue}", total_payload_size_by_queue(queue) , total_enqueue_count_by_queue(queue)
      set_avg "avg_payload_size:job:#{job_class}", total_payload_size_by_job(job_class) , total_enqueue_count_by_job(job_class)
      run_callback(:on_job_enqueue, job_class, queue, size)
      true
    end

    def self.record_job_completion(job_class, time)
      queue = Resque.queue_from_class(job_class)
      multi do
        increment_metric "job_time", time
        increment_metric "job_time:queue:#{queue}", time
        increment_metric "job_time:job:#{job_class}", time
        increment_metric "job_count"
        increment_metric "job_count:queue:#{queue}"
        increment_metric "job_count:job:#{job_class}"
      end
      set_avg "avg_job_time", total_job_time, total_job_count
      set_avg "avg_job_time:queue:#{queue}", total_job_time_by_queue(queue) , total_job_count_by_queue(queue)
      set_avg "avg_job_time:job:#{job_class}", total_job_time_by_job(job_class) , total_job_count_by_job(job_class)
      run_callback(:on_job_complete, job_class, queue, time)
    end

    def self.record_job_failure(job_class, e)
      queue = Resque.queue_from_class(job_class)
      
      multi do
        increment_metric "failed_job_count"
        increment_metric "failed_job_count:queue:#{queue}"
        increment_metric "failed_job_count:job:#{job_class}"
      end
      
      run_callback(:on_job_failure, job_class, queue)
    end

    def self.multi(&block)
      use_multi? ? redis.multi(&block) : yield
    end

    def self.increment_metric(metric, by = 1)
      run_backends(:increment_metric, metric, by)
    end

    def self.set_metric(metric, val)
      run_backends(:set_metric, metric, val)
    end

    def self.set_avg(metric, num, total)
      run_backends(:set_avg, metric, num, total)
    end

    def self.get_metric(metric)
      run_first_backend(:get_metric, metric)
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

    def self.failed_job_count
      get_metric "failed_job_count"
    end

    def self.failed_job_count_by_queue(queue)
      get_metric "failed_job_count:queue:#{queue}"
    end

    def self.failed_job_count_by_job(job)
      get_metric "failed_job_count:job:#{job}"
    end

    def self.total_payload_size
      get_metric "payload_size"
    end

    def self.total_payload_size_by_queue(queue)
      get_metric "payload_size:queue:#{queue}"
    end

    def self.total_payload_size_by_job(job)
      get_metric "payload_size:job:#{job}"
    end

    def self.avg_payload_size
      get_metric "avg_payload_size"
    end

    def self.avg_payload_size_by_queue(queue)
      get_metric "avg_payload_size:queue:#{queue}"
    end

    def self.avg_payload_size_by_job(job)
      get_metric "avg_payload_size:job:#{job}"
    end

    def self.avg_fork_time
      get_metric "avg_fork_time"
    end

    def self.avg_fork_time_by_queue(queue)
      get_metric "avg_fork_time:queue:#{queue}"
    end

    def self.avg_fork_time_by_job(job)
      get_metric "avg_fork_time:job:#{job}"
    end

    def self.total_fork_time
      get_metric "fork_time"
    end

    def self.total_fork_time_by_queue(queue)
      get_metric "fork_time:queue:#{queue}"
    end

    def self.total_fork_time_by_job(job)
      get_metric "fork_time:job:#{job}"
    end

    def self.total_fork_count
      get_metric "fork_count"
    end

    def self.total_fork_count_by_queue(queue)
      get_metric "fork_count:queue:#{queue}"
    end

    def self.total_fork_count_by_job(job)
      get_metric "fork_count:job:#{job}"
    end

    module Hooks

      def after_enqueue_metrics(*args)
        Resque::Metrics.record_job_enqueue(self, *args)
      end

      def around_perform_metrics(*args)
        start = Time.now
        yield
        finish = ((Time.now.to_f - start.to_f) * 1000).to_i
        Resque::Metrics.record_job_completion(self, finish)
      end

      def on_failure_metrics(e, *args)
        Resque::Metrics.record_job_failure(self, e)
      end

    end

  end
end

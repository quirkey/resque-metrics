module Resque
  module Metrics
    module Backends
      # Null backend is useful for testing and using Resque Metrics to just
      # get the callback hooks
      class Null

        def increment_metric(metric, by = 1)
          true
        end

        def set_metric(metric, val)
          true
        end

        def set_avg(metric, num, total)
          true
        end

        def get_metric(metric)
          1
        end

        def register_job(job)
          true
        end

        def known_jobs
          []
        end
      end
    end
  end
end

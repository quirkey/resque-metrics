module Resque
  module Metrics
    module Backends
      class Cloudwatch

        def increment_metric(metric, by = 1)
          true
        end

        def set_metric(metric, val)
          cw.put_metric_data(
            namespace: "#{Rails.application.class.parent_name}/#{Rails.env}/",
            metric_data: [
              hashify_metric("#{app_name}_#{Rails.env}_#{metric}", val)
            ]
          )

        end

        def register_job(job)
          true
          # cw.sadd('_metrics_:known_jobs', job)
        end

        def known_jobs
          true
          # cw.smembers('_metrics_:known_jobs')
          []
        end

        def hashify_metric(name, value)
          Hash[
            :metric_name,
            name,
            :value,
            value
          ]
        end

      end
    end
  end
end

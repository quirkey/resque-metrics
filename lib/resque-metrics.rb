require 'resque/metrics'
require 'resque-metrics/server'

Resque::Server.class_eval do
  include Resque::Metrics::Server
end

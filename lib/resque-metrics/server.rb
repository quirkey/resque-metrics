require 'resque/server'
require 'resque/metrics'

# Extend Resque::Server to add tabs
module Resque
  module Metrics
    module Server
      def self.included(base)
        base.class_eval do
          helpers do
            # reads a 'local' template file.
            def local_template(path)
              # Is there a better way to specify alternate template locations with sinatra?
              File.read(File.join(File.dirname(__FILE__), "server/views/#{path}"))
            end

            def metrics_formatted_ms(milliseconds)
              seconds = milliseconds / 1000
              hours = (seconds / 3600).floor
              minutes = (seconds % 3600) / 60
              seconds = seconds % 60

              str = []
              str << "#{hours} hours" if hours > 0
              str << "#{minutes} minutes" if minutes > 0
              str << "#{seconds} seconds" if seconds > 0
              str << "Less than a second" if milliseconds < 1000

              str.join(" ")
            end
          end

          get "/metrics" do
            erb local_template("metrics.erb")
          end
        end
      end

      Resque::Server.tabs << 'Metrics'
    end
  end
end

Resque::Server.class_eval do
  include Resque::Metrics::Server
end

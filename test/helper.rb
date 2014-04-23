dir = File.dirname(File.expand_path(__FILE__))
require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'minitest/autorun'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
$TESTING = true

require 'resque/metrics'

#
# make sure we can run redis
#

if ENV['BOXEN_REDIS_PORT']
  redis_port = ENV['BOXEN_REDIS_PORT']
else
  if !system("which redis-server")
    puts '', "** can't find `redis-server` in your path"
    puts "** try running `sudo rake install`"
    abort ''
  end

  #
  # start our own redis when the tests start,
  # kill it when they end
  #

  at_exit do
    next if $!

    if defined?(MiniTest)
      exit_code = MiniTest::Unit.new.run(ARGV)
    else
      exit_code = Test::Unit::AutoRunner.run
    end

    pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
    puts "Killing test redis server..."
    Process.kill("KILL", pid.to_i)
    FileUtils.rm_rf("#{dir}/dump.rdb")
    exit exit_code
  end

  puts "Starting redis for testing at localhost:9736..."
  `redis-server #{dir}/redis-test.conf`

  redis_port = 9736
end
Resque.redis = "localhost:#{redis_port}:2"

class SomeJob
  extend Resque::Metrics

  @queue = :jobs

  def self.perform(x, y)
    sleep rand * 0.01
  end

end

class FailureJob
  extend Resque::Metrics

  @queue = :jobs

  def self.perform
    raise "failing lol"
  end
end

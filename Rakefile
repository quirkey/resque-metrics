# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "resque-metrics"
  gem.homepage = "http://github.com/quirkey/resque-metrics"
  gem.license = "MIT"
  gem.summary = %Q{A Resque plugin for recording simple metrics for your jobs}
  gem.description = <<-desc
A simple Resque plugin that times and saves some simple metrics for Resque jobs back into redis. Based on this system
you could build some simple auto-scaling mechanism based on the speed and ETA of queues. Also includes a hook/callback
mechanism for recording/sending the metrics to your favorite tool (AKA statsd/graphite).
desc
  gem.email = "aaron@quirkey.com"
  gem.authors = ["Aaron Quint", "Josh Nichols", "Michael Smith", "Tomas Varaneckas"]  
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

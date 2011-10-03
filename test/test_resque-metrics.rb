require 'helper'

class TestResqueMetrics < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall

    Resque.before_first_fork = nil
    Resque.before_fork = nil
    Resque.after_fork = nil

    @worker = Resque::Worker.new(:jobs)
    4.times do
      Resque::Job.create(:jobs, SomeJob, 20, '/tmp')
      @worker.work(0)
    end
  end

  def test_should_pass_resque_plugin_lint
    assert Resque::Plugin.lint(Resque::Metrics::Hooks)
  end

  def test_should_record_total_job_time
    assert Resque::Metrics.total_job_time > 0
    assert Resque::Metrics.total_job_time_by_queue(:jobs) > 0
    assert Resque::Metrics.total_job_time_by_job(SomeJob) > 0
  end

  def test_should_record_job_count
    assert Resque::Metrics.total_job_count > 0
    assert Resque::Metrics.total_job_count_by_queue(:jobs) > 0
    assert Resque::Metrics.total_job_count_by_job(SomeJob) > 0
  end

  def test_should_record_avg_job_time
    assert Resque::Metrics.avg_job_time > 0
    assert Resque::Metrics.avg_job_time_by_queue(:jobs) > 0
    assert Resque::Metrics.avg_job_time_by_job(SomeJob) > 0
  end

end

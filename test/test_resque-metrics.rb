require 'helper'

class TestResqueMetrics < MiniTest::Unit::TestCase
  def setup
    Resque.redis.flushall

    Resque.before_first_fork = nil
    Resque.before_fork = nil
    Resque.after_fork = nil

    @worker = Resque::Worker.new(:jobs)
    4.times do
      work_job
    end
  end

  def test_should_pass_resque_plugin_lint
    assert Resque::Plugin.lint(Resque::Metrics::Hooks)
  end

  def test_should_perform_job
    assert Resque::Job.new(:jobs, 'class' => SomeJob, 'args' => [1,2]).perform
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

  def test_should_call_callbacks
    recorded = []
    Resque::Metrics.on_job do |klass, queue, time|
      recorded << [klass, queue, time]
    end
    work_job
    work_job
    assert_equal 2, recorded.length
    assert_equal SomeJob, recorded[0][0]
    assert_equal :jobs, recorded[0][1]
    assert recorded[0][2] > 0
  end

  private
  def work_job
    Resque::Job.create(:jobs, SomeJob, 20, '/tmp')
    @worker.work(0)
  end

end

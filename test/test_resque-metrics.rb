require 'helper'

class TestResqueMetrics < MiniTest::Unit::TestCase

  def test_should_pass_resque_plugin_lint
    assert Resque::Plugin.lint(Resque::Metrics)
  end

end

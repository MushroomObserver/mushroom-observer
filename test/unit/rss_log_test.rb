require File.dirname(__FILE__) + '/../test_helper'

class RssLogTest < Test::Unit::TestCase
  fixtures :rss_logs

  # Replace this with your real tests.
  def test_truth
    assert_kind_of RssLog, @observation_rss_log
  end
end

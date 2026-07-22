# frozen_string_literal: true

require("test_helper")

class SilenceSolidCacheLogsTest < UnitTestCase
  def test_solid_cache_record_logger_is_silenced
    assert_nil(SolidCache::Record.logger,
               "SolidCache::Record.logger should be nil (config/" \
               "initializers/silence_solid_cache_logs.rb) so every " \
               "cache read/write doesn't log a SolidCache::Entry Load " \
               "SQL line -- the app's own ActiveRecord::Base.logger is " \
               "unaffected, since each AR subclass can override its own")
  end

  def test_other_active_record_logging_is_unaffected
    assert_not_nil(ActiveRecord::Base.logger,
                   "Silencing SolidCache::Record must not silence the " \
                   "app's shared query logger")
  end
end

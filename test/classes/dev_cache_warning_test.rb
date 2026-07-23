# frozen_string_literal: true

require("test_helper")

class DevCacheWarningTest < UnitTestCase
  def test_applicable_when_dev_server_boot_and_caching_off
    assert(
      DevCacheWarning.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server_or_console: true, cache_file_exists: false
      )
    )
  end

  def test_not_applicable_when_caching_already_on
    assert_not(
      DevCacheWarning.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server_or_console: true, cache_file_exists: true
      )
    )
  end

  def test_not_applicable_outside_server_or_console_boot
    assert_not(
      DevCacheWarning.applicable?(
        env: ActiveSupport::StringInquirer.new("development"),
        server_or_console: false, cache_file_exists: false
      )
    )
  end

  def test_not_applicable_outside_development
    assert_not(
      DevCacheWarning.applicable?(
        env: ActiveSupport::StringInquirer.new("test"),
        server_or_console: true, cache_file_exists: false
      )
    )
  end

  def test_warn_if_applicable_prints_the_message_when_applicable
    DevCacheWarning.stub(:applicable?, true) do
      assert_output(nil, DevCacheWarning::MESSAGE) do
        DevCacheWarning.warn_if_applicable
      end
    end
  end

  def test_warn_if_applicable_silent_when_not_applicable
    DevCacheWarning.stub(:applicable?, false) do
      assert_output(nil, "") do
        DevCacheWarning.warn_if_applicable
      end
    end
  end
end

# frozen_string_literal: true

require("test_helper")

module Admin
  class BlockedIpsControllerTest < FunctionalTestCase
    def test_blocked_ips
      new_ip = "5.4.3.2"
      IpStats.remove_blocked_ips([new_ip])
      # make sure there is an API key logged to test that part of view
      api_key = api_keys(:rolfs_api_key)
      IpStats.log_stats({ ip: "3.14.15.9",
                          time: Time.zone.now,
                          controller: "api",
                          action: "observations",
                          api_key: api_key.key })
      assert_false(IpStats.blocked?(new_ip))

      login(:rolf)
      get(:edit)
      assert_response(:redirect)

      make_admin
      get(:edit)
      assert_response(:success)
      assert_includes(@response.body, api_key.key)

      patch(:update, params: { add_bad: "garbage" })
      assert_flash_error

      time = 1.minute.ago
      File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
      patch(:update, params: { add_bad: new_ip })
      assert_no_flash
      assert(time < File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_true(IpStats.blocked?(new_ip))

      time = 1.minute.ago
      File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
      patch(:update, params: { remove_bad: new_ip })
      assert_no_flash
      assert(time < File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_false(IpStats.blocked?(new_ip))
    end
  end
end

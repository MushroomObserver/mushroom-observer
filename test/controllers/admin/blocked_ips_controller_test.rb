# frozen_string_literal: true

require("test_helper")

module Admin
  class BlockedIpsControllerTest < FunctionalTestCase
    def setup
      super
      # Ensure blocked_ips.txt exists (may not exist on CI)
      FileUtils.touch(MO.blocked_ips_file)
      FileUtils.touch(MO.okay_ips_file)
      # Reset IpStats to ensure clean state, especially when running
      # in parallel with other tests that modify blocked_ips.txt
      IpStats.reset!
    end

    def test_blocked_ips
      ActiveSupport.to_time_preserves_timezone = true
      new_ip = "5.4.3.2"
      IpStats.remove_blocked_ips([new_ip])
      # make sure there is an API key logged to test that part of view
      api_key = api_keys(:rolfs_api_key)
      IpStats.log_stats({ ip: "3.14.15.9",
                          time: Time.zone.now,
                          controller: "api",
                          action: "observations",
                          api_key: api_key.key },
                        nil)
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

      time = 1.minute.ago
      File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
      patch(:update, params: { add_bad: " #{new_ip} " })
      assert_no_flash
      assert(time < File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_true(IpStats.blocked?(new_ip),
                  "It should ignore leading & trailing spaces in ip addr")
    end

    def test_blocked_ips_filter
      login(:rolf)
      make_admin

      # Save original file contents to restore after test
      original_contents = File.read(MO.blocked_ips_file)

      begin
        # Clear existing IPs and generate fake IPs with different prefixes
        IpStats.clear_blocked_ips
        generate_blocked_ips(
          "10.0.0" => 5,
          "10.0.1" => 3,
          "192.168.1" => 4
        )
        IpStats.reset!

        # Test unfiltered - should show all IPs
        get(:edit)
        assert_response(:success)
        assert_select("turbo-frame#blocked_ips_list")
        assert_includes(@response.body, "10.0.0")
        assert_includes(@response.body, "192.168.1")

        # Test filter by prefix "10.0.0"
        get(:edit, params: { text_filter: { starts_with: "10.0.0" } })
        assert_response(:success)
        assert_includes(@response.body, "10.0.0")
        assert_not_includes(@response.body, "192.168.1")

        # Test filter by prefix "192."
        get(:edit, params: { text_filter: { starts_with: "192." } })
        assert_response(:success)
        assert_includes(@response.body, "192.168.1")
        assert_not_includes(@response.body, "10.0.0")

        # Test filter with no matches
        get(:edit, params: { text_filter: { starts_with: "255.255" } })
        assert_response(:success)
        assert_includes(@response.body, "Showing 0 of 0")
      ensure
        # Restore original file contents
        File.write(MO.blocked_ips_file, original_contents)
        IpStats.reset!
      end
    end

    # Test that turbo_frame responses work for add, remove, and paging
    def test_turbo_frame_responses
      login(:rolf)
      make_admin

      original_blocked = File.read(MO.blocked_ips_file)
      original_okay = File.read(MO.okay_ips_file)

      begin
        IpStats.clear_blocked_ips
        IpStats.clear_okay_ips
        generate_blocked_ips("10.0.0" => 150) # Enough for multiple pages
        IpStats.reset!

        # Test both blocked and okay IPs
        [
          { type: :blocked, frame: "blocked_ips_list",
            add_param: :add_bad, remove_param: :remove_bad,
            form_key: :blocked_ips },
          { type: :okay, frame: "okay_ips_list",
            add_param: :add_okay, remove_param: :remove_okay,
            form_key: :okay_ips }
        ].each do |config|
          new_ip = "5.5.5.#{config[:type] == :blocked ? 1 : 2}"

          # Test add returns turbo_frame
          patch(:update, params: {
                  config[:form_key] => { config[:add_param] => new_ip }
                })
          assert_response(:success)
          assert_select("turbo-frame##{config[:frame]}")
          assert_includes(@response.body, new_ip,
                          "#{config[:type]}: should show added IP")

          # Test remove returns turbo_frame
          patch(:update, params: { config[:remove_param] => new_ip })
          assert_response(:success)
          assert_select("turbo-frame##{config[:frame]}")
        end

        # Test paging returns turbo_frame (blocked only has pagination)
        get(:edit, params: { page: 2 })
        assert_response(:success)
        assert_select("turbo-frame#blocked_ips_list")
        assert_includes(@response.body, "page 2 of")
      ensure
        File.write(MO.blocked_ips_file, original_blocked)
        File.write(MO.okay_ips_file, original_okay)
        IpStats.reset!
      end
    end

    # Test that the Superform-generated nested params work
    # (form submits blocked_ips[add_bad] instead of add_bad)
    def test_blocked_ips_nested_params
      login(:rolf)
      make_admin

      original_contents = File.read(MO.blocked_ips_file)

      begin
        IpStats.clear_blocked_ips
        IpStats.reset!

        new_ip = "1.2.3.4"
        assert_false(IpStats.blocked?(new_ip))

        # Test adding via nested params (how Superform submits)
        patch(:update, params: { blocked_ips: { add_bad: new_ip } })
        assert_no_flash
        IpStats.reset!
        assert_true(IpStats.blocked?(new_ip),
                    "Should add IP via nested blocked_ips[add_bad] param")

        # Test removing via flat params (how remove buttons submit)
        patch(:update, params: { remove_bad: new_ip })
        assert_no_flash
        IpStats.reset!
        assert_false(IpStats.blocked?(new_ip),
                     "Should remove IP via flat remove_bad param")
      ensure
        File.write(MO.blocked_ips_file, original_contents)
        IpStats.reset!
      end
    end

    private

    def generate_blocked_ips(prefixes_with_counts)
      ips = []
      prefixes_with_counts.each do |prefix, count|
        count.times do |i|
          ips << "#{prefix}.#{i + 1}"
        end
      end
      IpStats.add_blocked_ips(ips)
    end
  end
end

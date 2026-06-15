# frozen_string_literal: true

require("test_helper")

module Admin
  class BlockedIpsControllerTest < FunctionalTestCase
    def setup
      super
      # Ensure these files exist (may not on CI; ip_stats_file may
      # also have been deleted by IpStatsTest's teardown earlier in
      # the same parallel worker — see #4238).
      FileUtils.touch(MO.blocked_ips_file)
      FileUtils.touch(MO.okay_ips_file)
      FileUtils.touch(MO.ip_stats_file)
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
      assert_operator(time, :<, File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_true(IpStats.blocked?(new_ip))

      time = 1.minute.ago
      File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
      patch(:update, params: { remove_bad: new_ip })
      assert_no_flash
      assert_operator(time, :<, File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_false(IpStats.blocked?(new_ip))

      time = 1.minute.ago
      File.utime(time.to_time, time.to_time, MO.blocked_ips_file)
      patch(:update, params: { add_bad: " #{new_ip} " })
      assert_no_flash
      assert_operator(time, :<, File.mtime(MO.blocked_ips_file))
      IpStats.reset!
      assert_true(IpStats.blocked?(new_ip),
                  "It should ignore leading & trailing spaces in ip addr")
    end

    def test_ip_list_filters
      login(:rolf)
      make_admin

      original_blocked = File.read(MO.blocked_ips_file)
      original_okay = File.read(MO.okay_ips_file)

      begin
        [
          { type: :blocked, frame: "blocked_ips_list",
            filter_param: :text_filter, generator: :generate_blocked_ips,
            clear: -> { IpStats.clear_blocked_ips },
            prefix1: "10.0.0", prefix2: "192.168.1" },
          { type: :okay, frame: "okay_ips_list",
            filter_param: :okay_filter, generator: :generate_okay_ips,
            clear: -> { IpStats.clear_okay_ips },
            prefix1: "20.0.0", prefix2: "172.16.1" }
        ].each do |config|
          config[:clear].call
          send(config[:generator],
               config[:prefix1] => 5, config[:prefix2] => 4)
          IpStats.reset!

          # Test unfiltered
          get(:edit)
          assert_response(:success)
          assert_select("turbo-frame##{config[:frame]}")
          assert_includes(@response.body, config[:prefix1])
          assert_includes(@response.body, config[:prefix2])

          # Test filter by prefix (simulating Turbo frame request)
          prefix = config[:prefix1]
          filter = { config[:filter_param] => { starts_with: prefix } }
          @request.headers["Turbo-Frame"] = config[:frame]
          get(:edit, params: filter)
          assert_response(:success)
          assert_includes(@response.body, config[:prefix1],
                          "#{config[:type]}: should show filtered IPs")
          assert_not_includes(@response.body, config[:prefix2],
                              "#{config[:type]}: should hide non-matching IPs")
          # Filter value should be preserved in the input field within the
          # turbo_frame response. Input ID matches filter_param.
          input_id = "#{config[:filter_param]}_starts_with"
          assert_select("turbo-frame##{config[:frame]}") do
            assert_select(
              "input##{input_id}[value='#{prefix}']",
              { count: 1 },
              "#{config[:type]}: filter value should be preserved in input"
            )
          end
        end
      ensure
        File.write(MO.blocked_ips_file, original_blocked)
        File.write(MO.okay_ips_file, original_okay)
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

    # Exercises the per-IP stats panel (`IpStats` Phlex view) and the
    # bot / missing-user branches in `IpSummary`. Without this test
    # the entire `app/views/controllers/admin/blocked_ips/edit/
    # ip_stats.rb` file is dead code from coverage's perspective.
    def test_report_ip_renders_stats_panels
      login(:rolf)
      make_admin

      api_key = api_keys(:rolfs_api_key)
      # IP 1: user + api_key — exercises `render_user_line` (user found)
      # + `render_api_key_line` (api_key found) in both IpStats and
      # IpSummary.
      IpStats.log_stats({ ip: "1.1.1.1", time: Time.zone.now,
                          controller: "api", action: "observations",
                          api_key: api_key.key },
                        rolf.id)
      # IP 2: no user, no api_key — exercises IpSummary's "bot" branch.
      IpStats.log_stats({ ip: "2.2.2.2", time: Time.zone.now,
                          controller: "rss_logs", action: "index" },
                        nil)
      # IP 3: user_id set but the User doesn't exist — exercises
      # IpSummary's `plain(user_id.to_s)` fallback when
      # `@users_by_id[user_id]` is nil.
      IpStats.log_stats({ ip: "3.3.3.3", time: Time.zone.now,
                          controller: "observations", action: "show" },
                        9_999_999)
      # IP 4: api_key string set but no APIKey record matches —
      # exercises the `plain("bogus!")` branch in both IpStats and
      # IpSummary.
      IpStats.log_stats({ ip: "4.4.4.4", time: Time.zone.now,
                          controller: "api", action: "observations",
                          api_key: "key-not-in-db-bogus" },
                        nil)
      # IP 5: >50 activity entries — exercises IpStats'
      # "most recent 50 of N" branch in `render_activity_count`.
      51.times do |i|
        IpStats.log_stats({ ip: "5.5.5.5", time: i.seconds.ago,
                            controller: "observations", action: "show" },
                          nil)
      end

      # Valid IP that IS in stats — `report_ip_if_present` returns the
      # IP; `Edit#render_right_column` renders the IpStats panel.
      get(:edit, params: { report: "1.1.1.1" })
      assert_response(:success)
      assert_select("#ip_stats")

      # Bot IP — IpStats panel renders, IpSummary writes "bot" label.
      get(:edit, params: { report: "2.2.2.2" })
      assert_response(:success)
      assert_select("#ip_stats")

      # User_id without backing User — fallback to user_id text.
      get(:edit, params: { report: "3.3.3.3" })
      assert_response(:success)
      assert_select("#ip_stats")

      # Valid IP shape but not in stats — `report_ip_if_present`
      # returns nil at the `@stats.key?(ip)` guard; IpStats panel
      # does NOT render.
      get(:edit, params: { report: "9.9.9.9" })
      assert_response(:success)
      assert_select("#ip_stats", count: 0)

      # Invalid IP — `validate_ip!` flashes and returns nil before
      # the stats lookup; IpStats panel does NOT render.
      get(:edit, params: { report: "not.an.ip" })
      assert_response(:success)
      assert_select("#ip_stats", count: 0)

      # Bogus api_key — IpStats and IpSummary both render the
      # `"bogus!"` fallback when the key string has no matching APIKey.
      get(:edit, params: { report: "4.4.4.4" })
      assert_response(:success)
      assert_select("#ip_stats")

      # >50 activity — IpStats renders the "most recent 50 of N"
      # heading from `render_activity_count`.
      get(:edit, params: { report: "5.5.5.5" })
      assert_response(:success)
      assert_select("#ip_stats")
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
      IpStats.add_blocked_ips(generate_ips(prefixes_with_counts))
    end

    def generate_okay_ips(prefixes_with_counts)
      IpStats.add_okay_ips(generate_ips(prefixes_with_counts))
    end

    def generate_ips(prefixes_with_counts)
      ips = []
      prefixes_with_counts.each do |prefix, count|
        count.times { |i| ips << "#{prefix}.#{i + 1}" }
      end
      ips
    end
  end
end

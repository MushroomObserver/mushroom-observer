# frozen_string_literal: true

module Views::Controllers::Admin::BlockedIps
  class Edit
    # Sub-partial of the IP-access-manager page (the
    # right-hand column's "Stats for <ip>" panel).
    # Converted from `admin/blocked_ips/_ip_stats.html.erb`.
    class IpStats < Views::Base
      prop :stats, ::Hash
      prop :ip, ::String

      def view_template
        render(::Components::Panel.new(panel_class: "my-3",
                                       panel_id: "ip_stats")) do |panel|
          panel.with_heading { plain("Stats for #{@ip}:") }
          panel.with_heading_links { render_close_link }
          panel.with_body { render_body }
        end
      end

      private

      def ip_stats
        @stats[@ip]
      end

      def render_close_link
        link_to("[Close]", edit_admin_blocked_ips_path)
      end

      def render_body
        render_user_line
        render_api_key_line
        render_rate_line
        render_load_line
        render_activity_section
      end

      def render_user_line
        return unless (user_id = ip_stats[:user])

        plain("User: ")
        render(::Components::UserLink.new(
                 user: ::User.safe_find(user_id) || user_id
               ))
        br
      end

      def render_api_key_line
        return unless (api_key_str = ip_stats[:api_key])

        api_key = ::APIKey.find_by(key: api_key_str)
        plain("API key: #{api_key_str} (")
        if api_key
          render(::Components::UserLink.new(user: api_key.user))
        else
          plain("bogus!")
        end
        plain(")")
        br
      end

      def render_rate_line
        rate = ip_stats[:rate].to_f
        per_min = (rate * 60).round(2)
        per_req = (1.0 / rate).round(2)
        plain("Rate: #{per_min} / minute = 1 every #{per_req} seconds")
        br
      end

      def render_load_line
        load_pct = (ip_stats[:load].to_f * 100).round(2)
        plain("Load: #{load_pct}% of one worker")
        br
      end

      def render_activity_section
        plain("Activity:")
        render_activity_count
        br
        render_activity_table
      end

      def render_activity_count
        n = ip_stats[:activity].length
        if n > 50
          plain(" (most recent 50 of #{n} requests)")
        else
          plain(" (all of the most recent #{n} requests)")
        end
      end

      def render_activity_table
        render(::Components::Table.new(
                 ip_stats[:activity].reverse[0..50],
                 class: "ips ips-lined"
               )) { |t| render_activity_columns(t) }
      end

      def render_activity_columns(table)
        table.column("time") { |row| plain(row[0]) }
        table.column("seconds") { |row| plain(row[1].to_f.round(2)) }
        table.column("action") { |row| plain("#{row[2]}/#{row[3]}") }
      end
    end
  end
end

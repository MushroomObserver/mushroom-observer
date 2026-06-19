# frozen_string_literal: true

module Views::Controllers::Admin::BlockedIps
  class Edit
    # Sub-partial of the IP-access-manager page (the
    # right-hand column's "Most active users" panel).
    class IpSummary < Views::Base
      prop :stats, ::Hash
      # `{ user_id => User }` + `{ api_key_str => APIKey }` preloaded
      # by the controller — see `BlockedIpsController#render_edit_view`.
      prop :users_by_id, ::Hash, default: -> { {} }
      prop :api_keys_by_str, ::Hash, default: -> { {} }

      def view_template
        render(::Components::Panel.new(panel_class: "my-3",
                                       panel_id: "ip_summary")) do |panel|
          panel.with_heading { plain("Most active users: (top 50)") }
          panel.with_body(wrapper: false) { render_table }
        end
      end

      private

      def sorted_ips
        @stats.keys.sort_by { |ip| @stats[ip][:load] }.last(50).reverse
      end

      def render_table
        render(::Components::Table.new(
                 sorted_ips, class: "ips ips-lined align-middle"
               )) { |t| render_table_columns(t) }
      end

      def render_table_columns(table)
        table.column("ip") { |ip| render_ip_link(ip) }
        table.column("block") { |ip| render_block_button(ip) }
        table.column("user") { |ip| render_user_cell(ip) }
        table.column("rate / min") { |ip| render_rate_cell(ip) }
        table.column("load %") { |ip| render_load_cell(ip) }
      end

      def render_rate_cell(ip)
        plain((@stats[ip][:rate] * 60).round(2))
      end

      def render_load_cell(ip)
        plain((@stats[ip][:load] * 100).round(2))
      end

      def render_ip_link(ip)
        link_to(ip, edit_admin_blocked_ips_path(report: ip))
      end

      def render_block_button(ip)
        return if ::IpStats.blocked?(ip)

        # Inline of the `patch_button` helper (LinkHelper#patch_button).
        render(::Components::CrudButton::Patch.new(
                 name: "Block",
                 target: admin_blocked_ips_path(add_bad: ip),
                 class: "btn btn-default"
               ))
      end

      def render_user_cell(ip)
        # Original ERB's `elsif browser.bot?` was reading the admin's
        # request UA, not the per-IP UA — `IpStats` doesn't log a
        # User-Agent per request, so we can't actually classify. By
        # admin convention, an IP with no `:user` is treated as a bot
        # (most anonymous traffic is crawlers).
        if (user_id = @stats[ip][:user])
          render_user_line(user_id)
        elsif !@stats[ip][:api_key]
          plain("bot")
          br
        end
        render_api_key_line(ip)
      end

      def render_user_line(user_id)
        user = @users_by_id[user_id]
        plain("User: ")
        if user
          render(::Components::Link::Object::User.new(user: user))
        else
          plain(user_id.to_s)
        end
        br
      end

      def render_api_key_line(ip)
        return unless (api_key_str = @stats[ip][:api_key])

        api_key = @api_keys_by_str[api_key_str]
        plain("API key: #{api_key_str} (")
        if api_key
          render(::Components::Link::Object::User.new(user: api_key.user))
        else
          plain("bogus!")
        end
        plain(")")
        br
      end
    end
  end
end

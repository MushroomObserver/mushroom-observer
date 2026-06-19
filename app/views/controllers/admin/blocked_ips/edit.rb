# frozen_string_literal: true

module Views::Controllers::Admin::BlockedIps
  # Action template for the IP Access Manager page. Two-column
  # layout: left has the okay-IPs and blocked-IPs Manager forms,
  # right has the optional per-IP stats panel + global most-active-
  # users summary panel.
  class Edit < Views::FullPageBase
    prop :ip, _Nilable(::String), default: nil
    prop :stats, ::Hash
    prop :okay, ::Admin::BlockedIps::IpListState
    prop :blocked, ::Admin::BlockedIps::IpListState
    # `{ user_id (Integer) => User }` preloaded by the controller.
    prop :users_by_id, ::Hash, default: -> { {} }
    # `{ api_key_str (String) => APIKey-with-:user-preloaded }`.
    prop :api_keys_by_str, ::Hash, default: -> { {} }

    def view_template
      add_page_title("IP Access Manager")
      container_class(:full)
      div(class: "row") do
        div(class: "col-md-6") { render_left_column }
        div(class: "col-md-6") { render_right_column }
      end
    end

    private

    def render_left_column
      p { render_refresh_link }
      render_manager(type: :okay, list: @okay,
                     form: ::FormObject::OkayIps.new)
      render_manager(type: :blocked, list: @blocked,
                     form: ::FormObject::BlockedIps.new)
    end

    def render_refresh_link
      link_to("Refresh Stats", edit_admin_blocked_ips_path,
              class: "btn btn-default")
    end

    def render_manager(form:, type:, list:)
      # `Manager` hardcodes its `action_path` / `filter_path` (both
      # point at this same admin/blocked_ips resource) so they're not
      # passed through here. See the comment on those methods inside
      # `Manager` for the reasoning.
      render(Manager.new(form, type: type, list: list))
    end

    def render_right_column
      if @ip.present?
        render(IpStats.new(stats: @stats, ip: @ip,
                           users_by_id: @users_by_id,
                           api_keys_by_str: @api_keys_by_str))
      end
      render(IpSummary.new(stats: @stats,
                           users_by_id: @users_by_id,
                           api_keys_by_str: @api_keys_by_str))
    end
  end
end

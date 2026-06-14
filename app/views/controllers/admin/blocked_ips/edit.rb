# frozen_string_literal: true

module Views::Controllers::Admin::BlockedIps
  # Action template for the IP Access Manager page. Two-column
  # layout: left has the okay-IPs and blocked-IPs Manager forms,
  # right has the optional per-IP stats panel + global most-active-
  # users summary panel. Converted from `admin/blocked_ips/edit.html.erb`.
  class Edit < Views::Base
    prop :ip, _Nilable(::String), default: nil
    prop :stats, ::Hash
    prop :okay, ::Admin::BlockedIps::IpListState
    prop :blocked, ::Admin::BlockedIps::IpListState

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
      render(Manager.new(
               form,
               type: type, list: list,
               filter_path: edit_admin_blocked_ips_path,
               action_path: admin_blocked_ips_path
             ))
    end

    def render_right_column
      render(IpStats.new(stats: @stats, ip: @ip)) if @ip.present?
      render(IpSummary.new(stats: @stats))
    end
  end
end

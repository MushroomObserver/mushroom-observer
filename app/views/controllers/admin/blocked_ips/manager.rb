# frozen_string_literal: true

module Views::Controllers::Admin::BlockedIps
  # Superform component for managing IP lists (blocked or okay).
  # Rendered by `Views::Controllers::Admin::BlockedIps::Edit`.
  # Renders a Panel containing a management form (PATCH) with:
  # - Panel heading with title and count
  # - Add IP input + ADD button + Clear List button
  # - Optional filter form with pagination (rendered for either type
  #   whenever `list.page` and `list.total_pages` are present)
  # - Table of IPs with REMOVE buttons
  #
  # @example Usage
  #   render(Views::Controllers::Admin::BlockedIps::Manager.new(
  #     FormObject::BlockedIps.new,
  #     type: :blocked,
  #     list: blocked_ip_list_state
  #   ))
  class Manager < ::Components::ApplicationForm
    def initialize(form, type:, list:, **)
      @type = type
      @list = list # ::Admin::BlockedIps::IpListState
      super(form, **)
    end

    private

    # Manager only ever lives on the admin/blocked_ips edit page;
    # both paths are fixed (POST target for the main form, GET target
    # for the filter sub-form). No reason to make callers pass them.
    def action_path = admin_blocked_ips_path
    def filter_path = edit_admin_blocked_ips_path

    public

    def around_template(&block)
      turbo_frame_tag("#{@type}_ips_list") do
        render(Components::Panel.new(
                 panel_class: "my-3",
                 collapsible: true,
                 collapse_target: "##{@type}_ips_body",
                 expanded: true
               )) do |panel|
          panel.with_heading { title }
          panel.with_heading_links { render_showing_message }
          panel.with_body(wrapper: false, collapse: true) do
            div(class: "d-flex flex-column") do
              super(&block)
              # Filter form rendered outside main form (GET vs PATCH).
              # CSS order places it visually between controls and table.
              render_filter_form if filterable?
            end
          end
        end
      end
    end

    def view_template
      render_controls_row
      render_ips_table
    end

    private

    def filterable?
      @list.page.present? && @list.total_pages.present?
    end

    def form_tag(&block)
      form(action: action_path, method: :post, **form_attributes, &block)
    end

    def form_attributes
      {
        id: "#{@type}_ips_manager_form",
        class: "#{@type}-ips-manager",
        style: "display: contents",
        data: { turbo_frame: "#{@type}_ips_list" }
      }
    end

    def render_filter_form
      render(Components::Form::LiveDataFilter.new(
               FormObject::TextFilter.new(starts_with: @list.starts_with),
               turbo_frame: "#{@type}_ips_list",
               page: @list.page,
               total_pages: @list.total_pages,
               filter_path: filter_path,
               placeholder: "Filter by IP prefix...",
               page_param: @type == :blocked ? "page" : "okay_page",
               filter_param:
                 @type == :blocked ? "text_filter" : "okay_filter"
             ))
    end

    def title
      @type == :blocked ? "Blocked IPs:" : "Okay IPs:"
    end

    def render_showing_message
      plain("Showing #{@list.ips.size}")
      return unless filterable?

      plain(" of #{@list.total_count}")
      return unless @list.total_pages > 1

      plain(" (page #{@list.page} of #{@list.total_pages})")
    end

    def render_controls_row
      div(class: "d-flex justify-content-between align-items-center " \
                 "p-3 border-bottom",
          style: "order: 1") do
        div(class: "form-group form-inline mb-0") do
          render_add_field
          render_add_button
        end
        render_clear_button
      end
    end

    def render_add_field
      text_field(add_param,
                 label: false,
                 placeholder: "IP address...",
                 class: "form-control mr-2",
                 size: 20)
    end

    def add_param
      @type == :blocked ? :add_bad : :add_okay
    end

    def render_add_button
      submit(:add.ti, as: :button, class: "mr-3")
    end

    def render_clear_button
      submit("Clear List", as: :button,
                           name: clear_param, value: "1",
                           id: "clear_#{@type}_ips_list",
                           class: "ml-auto",
                           data: { confirm: :are_you_sure.t })
    end

    def clear_param
      @type == :blocked ? "clear_bad" : "clear_okay"
    end

    def render_ips_table
      render(Components::Table.new(@list.ips,
                                   id: "#{@type}_ips",
                                   show_headers: false,
                                   class: "ips align-middle border-top",
                                   attributes: { style: "order: 3" })) do |t|
        t.column("ip", &:t)
        t.column("actions", class: "text-right") do |ip|
          render_remove_button(ip)
        end
      end
    end

    def render_remove_button(ip)
      submit(:remove.ti, as: :button,
                         name: remove_param, value: ip,
                         id: "remove_#{@type}_ip_#{ip}",
                         variant: :link, size: :sm,
                         class: "font-weight-bold")
    end

    def remove_param
      @type == :blocked ? "remove_bad" : "remove_okay"
    end
  end
end

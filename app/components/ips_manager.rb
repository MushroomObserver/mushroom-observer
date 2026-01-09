# frozen_string_literal: true

# Superform component for managing IP lists (blocked or okay).
# Renders a Panel containing a management form (PATCH) with:
# - Panel heading with title and count
# - Add IP input + ADD button + Clear List button
# - Optional filter form with pagination (for blocked IPs)
# - Table of IPs with REMOVE buttons
#
# @example Usage for okay IPs
#   <%= render(Components::IpsManager.new(
#         FormObject::OkayIps.new,
#         type: :okay,
#         ips: @okay_ips,
#         action_path: admin_blocked_ips_path
#       )) %>
#
# @example Usage for blocked IPs (with filtering)
#   <%= render(Components::IpsManager.new(
#         FormObject::BlockedIps.new,
#         type: :blocked,
#         ips: @blocked_ips,
#         action_path: admin_blocked_ips_path,
#         page: @blocked_ips_page,
#         total_pages: @blocked_ips_pages,
#         total_count: @blocked_ips_total,
#         starts_with: @starts_with,
#         filter_path: edit_admin_blocked_ips_path
#       )) %>
#
class Components::IpsManager < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(form, type:, ips:, action_path:,
                 page: nil, total_pages: nil, total_count: nil,
                 starts_with: nil, filter_path: nil, **)
    # rubocop:enable Metrics/ParameterLists
    @type = type
    @ips = ips
    @action_path = action_path
    @page = page
    @total_pages = total_pages
    @total_count = total_count
    @starts_with = starts_with
    @filter_path = filter_path
    super(form, **)
  end

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
            # Filter form rendered outside main form (GET vs PATCH)
            # CSS order places it visually between controls and table
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
    @page.present? && @total_pages.present?
  end

  def form_tag(&block)
    form(action: @action_path, method: :post, **form_attributes, &block)
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
    render(Components::LiveDataFilterForm.new(
             FormObject::TextFilter.new(starts_with: @starts_with),
             turbo_frame: "#{@type}_ips_list",
             page: @page,
             total_pages: @total_pages,
             filter_path: @filter_path,
             placeholder: "Filter by IP prefix...",
             page_param: @type == :blocked ? "page" : "okay_page",
             filter_param: @type == :blocked ? "text_filter" : "okay_filter"
           ))
  end

  def title
    @type == :blocked ? "Blocked IPs:" : "Okay IPs:"
  end

  def render_showing_message
    if filterable?
      plain("Showing #{@ips.size} of #{@total_count}")
      plain(" (page #{@page} of #{@total_pages})") if @total_pages > 1
    else
      plain("Showing #{@ips.size}")
    end
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
    button(type: "submit", class: "btn btn-default mr-3") { :ADD.l }
  end

  def render_clear_button
    button(type: "submit",
           id: "clear_#{@type}_ips_list",
           name: clear_param,
           value: "1",
           class: "btn btn-default ml-auto",
           data: { confirm: :are_you_sure.t }) do
      "Clear List"
    end
  end

  def clear_param
    @type == :blocked ? "clear_bad" : "clear_okay"
  end

  def render_ips_table
    render(Components::Table.new(@ips,
                                 id: "#{@type}_ips",
                                 headers: false,
                                 class: "ips align-middle border-top",
                                 style: "order: 3")) do |t|
      t.column("ip", &:t)
      t.column("actions", class: "text-right") { |ip| render_remove_button(ip) }
    end
  end

  def render_remove_button(ip)
    button(type: "submit",
           id: "remove_#{@type}_ip_#{ip}",
           name: remove_param,
           value: ip,
           class: "btn btn-sm btn-link font-weight-bold") do
      :REMOVE.l
    end
  end

  def remove_param
    @type == :blocked ? "remove_bad" : "remove_okay"
  end
end

# frozen_string_literal: true

# Superform component for managing blocked IPs.
# Renders a filter form (GET) and a management form (PATCH) with:
# - Add IP input + ADD button
# - Clear List button
# - Table of IPs with REMOVE buttons
#
# @example Usage in ERB
#   <%= render(Components::BlockedIpsManager.new(
#         FormObject::BlockedIps.new,
#         blocked_ips: @blocked_ips,
#         page: @blocked_ips_page,
#         total_pages: @blocked_ips_pages,
#         total_count: @blocked_ips_total,
#         starts_with: @starts_with,
#         filter_path: edit_admin_blocked_ips_path,
#         action_path: admin_blocked_ips_path
#       )) %>
#
class Components::BlockedIpsManager < Components::ApplicationForm
  include Phlex::Rails::Helpers::ButtonTo

  # rubocop:disable Metrics/ParameterLists
  def initialize(blocked_ips_form, blocked_ips:, page:, total_pages:,
                 total_count:, starts_with:, filter_path:, action_path:, **)
    # rubocop:enable Metrics/ParameterLists
    @blocked_ips = blocked_ips
    @page = page
    @total_pages = total_pages
    @total_count = total_count
    @starts_with = starts_with
    @filter_path = filter_path
    @action_path = action_path
    super(blocked_ips_form, **)
  end

  def around_template(&block)
    div(class: "d-flex flex-column") do
      div(style: "order: 3") { render_filter_form }
      super(&block)
    end
  end

  def view_template
    div(style: "order: 1") { render_title_row }
    div(style: "order: 2") { render_controls_row }
    div(style: "order: 4") { render_ips_table }
  end

  private

  def form_tag(&block)
    form(action: @action_path, method: :post, **form_attributes) do
      input(type: "hidden", name: "_method", value: "patch")
      yield
    end
  end

  def form_attributes
    {
      id: "blocked_ips_manager_form",
      class: "blocked-ips-manager",
      style: "display: contents",
      data: { turbo_frame: "blocked_ips_list" }
    }
  end

  def render_filter_form
    render(Components::BlockedIpsFilterForm.new(
             FormObject::TextFilter.new(starts_with: @starts_with),
             page: @page,
             total_pages: @total_pages,
             filter_path: @filter_path
           ))
  end

  def render_title_row
    div(class: "d-flex justify-content-between mb-3") do
      span(class: "text-larger") { "Blocked IPs:" }
      div do
        plain("Showing #{@blocked_ips.size} of #{@total_count}")
        plain(" (page #{@page} of #{@total_pages})") if @total_pages > 1
      end
    end
  end

  def render_controls_row
    div(class: "d-flex justify-content-between align-items-center mb-3") do
      div(class: "form-group form-inline mb-0") do
        render_add_field
        render_add_button
      end
      render_clear_button
    end
  end

  def render_add_field
    text_field(:add_bad,
               label: false,
               placeholder: "IP address...",
               class: "form-control mr-2",
               size: 20)
  end

  def render_add_button
    button(type: "submit", class: "btn btn-default mr-3") { :ADD.l }
  end

  def render_clear_button
    button(type: "submit",
           name: "clear_bad",
           value: "1",
           class: "btn btn-default ml-auto",
           data: { confirm: :are_you_sure.t }) do
      "Clear List"
    end
  end

  def render_ips_table
    render(Components::Table.new(@blocked_ips,
                                 id: "blocked_ips",
                                 headers: false,
                                 class: "ips my-3 align-middle")) do |t|
      t.column("ip", &:t)
      t.column("actions", class: "text-right") { |ip| render_remove_button(ip) }
    end
  end

  def render_remove_button(ip)
    button(type: "submit",
           name: "remove_bad",
           value: ip,
           class: "btn btn-sm btn-link font-weight-bold") do
      :REMOVE.l
    end
  end
end

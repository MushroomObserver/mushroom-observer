# frozen_string_literal: true

# Superform component for managing okay IPs.
# Renders a management form (PATCH) with:
# - Add IP input + ADD button
# - Clear List button
# - Table of IPs with REMOVE buttons
#
# @example Usage in ERB
#   <%= render(Components::OkayIpsManager.new(
#         FormObject::OkayIps.new,
#         okay_ips: @okay_ips,
#         action_path: admin_blocked_ips_path
#       )) %>
#
class Components::OkayIpsManager < Components::ApplicationForm
  def initialize(okay_ips_form, okay_ips:, action_path:, **)
    @okay_ips = okay_ips
    @action_path = action_path
    super(okay_ips_form, **)
  end

  def view_template
    render_title_row
    render_controls_row
    render_ips_table
  end

  private

  def form_tag
    form(action: @action_path, method: :post, **form_attributes) do
      input(type: "hidden", name: "_method", value: "patch")
      yield
    end
  end

  def form_attributes
    {
      id: "okay_ips_manager_form",
      class: "okay-ips-manager"
    }
  end

  def render_title_row
    div(class: "d-flex justify-content-between mb-3") do
      span(class: "text-larger") { "Okay IPs:" }
      div { plain("Showing #{@okay_ips.size}") }
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
    text_field(:add_okay,
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
           name: "clear_okay",
           value: "1",
           class: "btn btn-default ml-auto",
           data: { confirm: :are_you_sure.t }) do
      "Clear List"
    end
  end

  def render_ips_table
    render(Components::Table.new(@okay_ips,
                                 id: "okay_ips",
                                 headers: false,
                                 class: table_classes)) do |t|
      t.column("ip", &:t)
      t.column("actions", class: "text-right") { |ip| render_remove_button(ip) }
    end
  end

  def table_classes
    "ips my-3 align-middle"
  end

  def render_remove_button(ip)
    button(type: "submit",
           name: "remove_okay",
           value: ip,
           class: "btn btn-sm btn-link font-weight-bold") do
      :REMOVE.l
    end
  end
end

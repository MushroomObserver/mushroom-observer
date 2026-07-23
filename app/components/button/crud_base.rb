# frozen_string_literal: true

# Base class for all form-submitting mutation buttons.
# Subclasses specialise by HTTP method:
#   Button::Post   — POST  (create)
#   Button::Put    — PUT   (full replace)
#   Button::Patch  — PATCH (partial update)
#   Button::Delete — DELETE (destroy)
#
# GET links are handled by `Components::Button::Get` (→ `Components::Link::Get`).
#
# Inherits `@name`, `@variant`, `@size`, `@icon`, `@icon_class`,
# `@html_attrs`, `validate_no_btn_classes!`, `btn_class`, and
# `size_class` from `Components::Button`. Path-building (`path`,
# `identifier`, `action`, `target_path`, etc.) comes from
# `Components::CRUDPathBuilding`.
#
class Components::Button::CRUDBase < Components::Button
  include Components::CRUDPathBuilding

  # `options` accepts all Button kwargs (variant:, size:, icon:, and
  # arbitrary HTML attrs) plus CRUDBase-only keys: confirm:, action:,
  # back:, params:. CRUDBase-only keys are stripped before delegating
  # to Button.
  def initialize(name:, target:, method: :post, **options, &block)
    @target  = target
    @method  = method
    @confirm = options.delete(:confirm)
    @action  = options.delete(:action)
    @back    = options.delete(:back)
    @params  = options.delete(:params)
    @block   = block
    super(name: name, **options)
  end

  def view_template
    @block&.call
    render_form_button
  end

  private

  def render_form_button
    button_to(path, button_html_options) { button_content }
  end

  # Wrap in `capture` so Rails' `button_to` receives an HTML string
  # from the block (vs Phlex buffer appends that Button's default
  # `button_content` emits).
  def button_content
    capture { super }
  end

  def merged_class
    class_names(identifier, super)
  end

  def button_html_options
    form_data = { turbo: true }
    form_data[:turbo_confirm] = @confirm if @confirm

    button_data = { tooltip_target: "trigger", placement: "top", title: @name }
    if @confirm
      button_data[:turbo_confirm_title] = @confirm
      button_data[:turbo_confirm_button] = @name
    end

    opts = {
      method: @method,
      class: merged_class,
      form: { data: form_data },
      data: button_data
    }
    opts[:params] = @params if @params
    opts.merge(@html_attrs.except(:class))
  end
end

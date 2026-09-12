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
# `@attributes`, `validate_no_btn_classes!`, `btn_class`, and
# `size_class` from `Components::Button`. Path-building (`path`,
# `identifier`, `action`, `target_path`, etc.) comes from
# `Components::CRUDPathBuilding`, which also expects `@method` (see
# the initializer below for why that one stays a plain ivar).
#
class Components::Button::CRUDBase < Components::Button
  include Components::CRUDPathBuilding

  prop :target, _Union(String, Hash, _Interface(:type_tag, :id))
  prop :confirm, _Nilable(String), default: nil
  prop :action, _Nilable(_Union(*Components::CRUDPathBuilding::ACTIONS)),
       default: nil
  prop :back, _Nilable(_Union(*Components::CRUDPathBuilding::BACK_VALUES)),
       default: nil

  # `options` accepts all Button kwargs (variant:, size:, icon:, and
  # arbitrary HTML attrs) plus CRUDBase-only keys: confirm:, action:,
  # back:. `params:` isn't extracted -- it rides through to Button's
  # `attributes` catch-all and is read back out in button_html_options,
  # same as any other arbitrary HTML/form attribute.
  #
  # `@method` stays a plain ivar, not a declared prop -- naming a prop
  # `method` would shadow `Object#method`, and this kwarg is only ever
  # supplied by CRUDBase's own sibling subclasses (Post/Put/Patch/
  # Delete), not by arbitrary callers, so the extra validation a prop
  # would add isn't worth that risk.
  #
  # `validate_no_btn_classes!` is called explicitly here rather than
  # relying on it running via Button's own initializer: when a
  # subclass declares its own new `prop`s (as this class does),
  # Literal's generated `super` chain skips the parent's hand-written
  # `initialize` body entirely (verified empirically) -- prop
  # *assignment* still resolves correctly across the whole hierarchy,
  # but any imperative side effect living in that body doesn't run.
  # `validate_no_btn_classes!` is a plain instance method (from the
  # included `Button::Styling` concern, independent of Button's
  # initialize), so calling it directly here works regardless.
  def initialize(name:, target:, method: :post, **options)
    confirm = options.delete(:confirm)
    action  = options.delete(:action)
    back    = options.delete(:back)
    validate_no_btn_classes!(options[:class])
    super(name: name, target: target, confirm: confirm, action: action,
          back: back, **options)
    @method = method
  end

  # `&block` lives here, not on `initialize` -- Phlex delivers a
  # caller's `render(...) { ... }` block to `view_template` at render
  # time, not to the constructor. A block attached to `.new(...) {
  # ... }` instead never arrives: Literal::Properties' generated
  # `self.new` doesn't forward blocks to `initialize` at all (verified
  # empirically -- this silently dropped any block content passed to
  # a CRUD button before this fix, with no error).
  def view_template(&block)
    render_form_button(&block)
  end

  private

  def render_form_button(&block)
    button_to(path, button_html_options) do
      block ? capture(&block) : button_content
    end
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

    button_data = { tooltip_target: "tip", placement: "top", title: @name }
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
    opts[:params] = @attributes[:params] if @attributes[:params]
    opts.deep_merge(@attributes.except(:class, :params))
  end
end

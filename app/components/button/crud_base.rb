# frozen_string_literal: true

# Base class for all form-submitting and idempotent-action buttons.
# Subclasses specialise by HTTP method:
#   Button::Post   — POST  (create)
#   Button::Put    — PUT   (full replace)
#   Button::Patch  — PATCH (partial update)
#   Button::Delete — DELETE (destroy)
#   Button::Get    — GET   (plain <a> link with icon/style support)
#   Button::Edit   — GET to the edit route (inherits Button::Get)
#   Button::Download — GET to download route (inherits Button::Get)
#
# Inherits `@name`, `@variant`, `@size`, `@icon`, `@icon_class`,
# `@html_attrs`, `validate_no_btn_classes!`, `btn_class`, and
# `size_class` from `Components::Button`. Adds `@target`, `@method`,
# `@confirm`, `@action`, and `@back`.
#
# The rendered element follows the HTTP method:
#   :get → `<a href=…>…</a>` (link_to)
#   anything else → `<form><button type="submit">…</button></form>`
#
class Components::Button::CRUDBase < Components::Button
  # Actions that map to a Rails named-route prefix — e.g. :edit →
  # `edit_<model>_path`. Anything else uses the bare resource path
  # and the HTTP method is set separately.
  NAMED_ROUTE_ACTIONS = [:edit, :new, :download].freeze

  # Controllers whose edit/destroy actions support the `?back=`
  # round-trip so the controller can redirect to the originating page
  # after a mutation. See `default_back_param`.
  SHOW_OBS_EDITABLES = %w[
    collection_numbers herbarium_records sequences external_links
  ].freeze

  # `options` accepts all Button kwargs (style:, size:, icon:, and
  # arbitrary HTML attrs) plus CRUDBase-only keys: confirm:, action:,
  # back:. CRUDBase-only keys are stripped before delegating to Button.
  #
  # Pass `variant: :btn_link` for an underlined-link appearance;
  # `variant: :strip` for a bare element with no btn wrapper.
  # Omit `variant:` for the standard `btn btn-default` frame.
  def initialize(name:, target:, method: :post, **options, &block)
    @target  = target
    @method  = method
    @confirm = options.delete(:confirm)
    @action  = options.delete(:action)
    @back    = options.delete(:back)
    @block   = block
    super(name: name, **options)
  end

  def view_template
    @block&.call
    if @method == :get
      render_link
    else
      render_form_button
    end
  end

  private

  def render_link
    link_to(path, link_html_options) { button_content }
  end

  def render_form_button
    button_to(path, button_html_options) { button_content }
  end

  # Wrap in `capture` so Rails' `button_to` receives an HTML string
  # from the block (vs Phlex buffer appends that Button's default
  # `button_content` emits).
  def button_content
    capture { super }
  end

  def link_html_options
    base = { class: merged_class }
    base.merge!(tooltip_data) if @icon
    base.deep_merge(@html_attrs.except(:class))
  end

  # Prepend the identifier class before the Bootstrap btn classes so
  # it always survives even when `variant: :strip` drops the btn frame.
  def merged_class
    class_names(identifier,
                ("btn" unless @variant == :strip),
                btn_class(@variant),
                size_class(@size),
                @html_attrs[:class])
  end

  def button_html_options
    form_data = { turbo: true }
    form_data[:turbo_confirm] = @confirm if @confirm

    button_data = { toggle: "tooltip", placement: "top", title: @name }
    if @confirm
      button_data[:turbo_confirm_title] = @confirm
      button_data[:turbo_confirm_button] = @name
    end

    {
      method: @method,
      class: merged_class,
      form: { data: form_data },
      data: button_data
    }.merge(@html_attrs.except(:class))
  end

  def tooltip_data
    {
      title: @name,
      data: { toggle: "tooltip", placement: "top", title: @name }
    }
  end

  def path
    if @target.is_a?(String) || @target.is_a?(Hash)
      @target
    else
      target_path
    end
  end

  def identifier
    if @target.is_a?(String) || @target.is_a?(Hash)
      ""
    else
      "#{action}_#{@target.type_tag}_link_#{@target.id}"
    end
  end

  def action
    @action || @method
  end

  def target_path
    send(:"#{path_prefix}#{@target.type_tag}_path", @target.id, **path_args)
  end

  def path_args
    back = @back || default_back_param
    back ? { back: back } : {}
  end

  def default_back_param
    return nil unless back_eligible?
    return nil unless SHOW_OBS_EDITABLES.include?(controller_name)

    case action_name
    when "show" then :show
    when "index" then :index
    end
  end

  def back_eligible?
    [:edit, :destroy].include?(@action) &&
      !@target.is_a?(String) && !@target.is_a?(Hash)
  end

  def path_prefix
    NAMED_ROUTE_ACTIONS.include?(@action) ? "#{action}_" : ""
  end
end

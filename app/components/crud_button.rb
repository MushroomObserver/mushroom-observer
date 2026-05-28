# frozen_string_literal: true

# Renders an icon-styled button that submits to a target path. Used
# as the base for `patch_button`, `post_button`, `put_button`,
# `destroy_button` (non-idempotent verbs → `<form>` + `<button>` via
# Rails' `button_to`) and `download_button` and similar idempotent
# navigations (GET → plain `<a>` via `link_to`). The element choice
# follows the HTTP method:
#
# - `method: :get`   → `<a href=…>…</a>` (link_to). Right-click /
#   open-in-new-tab / save-link-as all work; semantically a
#   navigation; no form wrapper.
# - `method: :post`/`:put`/`:patch`/`:delete` → `<form method=…>
#   <button>…</button></form>` (button_to). Action buttons with
#   CSRF/turbo wiring.
#
# Usage:
#   render(Components::CrudButton.new(
#     name: :REMOVE.l,
#     target: @herbarium,  # or a path string
#     method: :patch,
#     confirm: :show_observation_remove_herbarium_record.l,
#     action: :remove,
#     icon: :remove
#   ))
#
class Components::CrudButton < Components::Base
  # Actions that map to a Rails-generated named route prefix. Anything
  # else (HTTP-verb actions like `:patch`, or undefined custom actions)
  # gets the bare resource path; the HTTP method is set separately via
  # `method:`. See `target_path` / `path_prefix` below.
  NAMED_ROUTE_ACTIONS = [:edit, :new, :download].freeze

  # Controllers whose edit/destroy actions can be reached either from
  # the parent obs `show` page or from their own `index` page — the
  # `?back=show|index` query string round-trips that context so the
  # controller can redirect back to where the user came from after the
  # edit/destroy. When `Components::CrudButton::{Edit,Delete}` is
  # rendered from one of these controllers, the appropriate `back:`
  # default is injected automatically (unless the caller passes
  # `back:` explicitly). See `default_back_param` below.
  SHOW_OBS_EDITABLES = %w[
    collection_numbers herbarium_records sequences external_links
  ].freeze

  def initialize(name:, target:, method: :post, confirm: nil, **args, &block)
    super()
    @name = name
    @target = target
    @method = method
    @confirm = confirm
    @args = args
    @block = block
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

  # GET path — plain `<a>`, no form wrapper, no CSRF/turbo (GET is
  # idempotent). Caller can still pass `class:`, `data:`, etc. and
  # they flow through normally.
  def render_link
    link_to(path, link_html_options) { button_content }
  end

  def render_form_button
    button_to(path, button_html_options) { button_content }
  end

  # `<a>` html options. Tooltip data attrs are emitted only when an
  # `icon:` was passed — for icon-only buttons the tooltip is the
  # accessible label; for text links the tooltip would just duplicate
  # the visible label, so we skip it. The `btn:` kwarg lets callers
  # default into a button-style class (e.g. `"btn btn-default"`)
  # without needing to spell out the full `class:`.
  def link_html_options
    base = { class: merged_class }
    base.merge!(tooltip_data) if @args[:icon]
    base.deep_merge(@args.except(*ignored_arg_keys))
  end

  # Shared class string for both branches: identifier + caller-supplied
  # `btn:` (button-shape default, e.g. `"btn btn-outline-default"`) +
  # caller-supplied `class:` (sizing/spacing, e.g. `"btn-sm"`).
  def merged_class
    class_names(identifier, @args[:btn], @args[:class])
  end

  # Keys consumed by CrudButton itself — must be stripped before
  # `@args` is merged into the underlying `link_to` / `button_to`
  # call, otherwise they'd leak through as HTML attributes.
  def ignored_arg_keys
    [:class, :icon, :action, :back, :btn]
  end

  def tooltip_data
    {
      title: @name,
      data: { toggle: "tooltip", placement: "top", title: @name }
    }
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
    }.merge(@args.except(*ignored_arg_keys))
  end

  def button_content
    capture do
      if @args[:icon]
        span(class: "sr-only") { trusted_html(@name) }
        link_icon(@args[:icon])
      else
        trusted_html(@name)
      end
    end
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
    @args[:action] || @method
  end

  def target_path
    # For model targets, route the URL via the named route helper.
    # HTTP-verb actions (`:patch`, `:put`, `:post`, `:delete`, the
    # default) use the bare resource path (`herbarium_path`,
    # combined with the HTTP method). Named-route actions
    # (`:edit`, `:new`, `:download`) prefix the route helper
    # name (`edit_herbarium_path`, etc.) — Rails generates those
    # paths for the standard RESTful named routes.
    send(:"#{path_prefix}#{@target.type_tag}_path",
         @target.id, **path_args)
  end

  def path_args
    back = @args[:back] || default_back_param
    back ? { back: back } : {}
  end

  # For `:edit`/`:destroy` actions on a model target rendered from a
  # `SHOW_OBS_EDITABLES` controller, default `back:` to the current
  # action (`:show` or `:index`) so the controller can redirect back
  # to the originating page after the edit/destroy. Caller's
  # explicit `back:` always wins (handled in `path_args` above).
  # Returns nil otherwise.
  def default_back_param
    return nil unless back_eligible?
    return nil unless SHOW_OBS_EDITABLES.include?(controller_name)

    case action_name
    when "show" then :show
    when "index" then :index
    end
  end

  def back_eligible?
    [:edit, :destroy].include?(@args[:action]) &&
      !@target.is_a?(String) && !@target.is_a?(Hash)
  end

  def path_prefix
    NAMED_ROUTE_ACTIONS.include?(@args[:action]) ? "#{action}_" : ""
  end
end

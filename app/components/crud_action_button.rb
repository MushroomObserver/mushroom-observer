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
#   render(Components::CrudActionButton.new(
#     name: :REMOVE.l,
#     target: @herbarium,  # or a path string
#     method: :patch,
#     confirm: :show_observation_remove_herbarium_record.l,
#     action: :remove,
#     icon: :remove
#   ))
#
class Components::CrudActionButton < Components::Base
  # Actions that map to a Rails-generated named route prefix. Anything
  # else (HTTP-verb actions like `:patch`, or undefined custom actions)
  # gets the bare resource path; the HTTP method is set separately via
  # `method:`. See `target_path` / `path_prefix` below.
  NAMED_ROUTE_ACTIONS = [:edit, :new, :download].freeze

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

  def link_html_options
    {
      class: class_names(identifier, @args[:class]),
      title: @name,
      data: { toggle: "tooltip", placement: "top", title: @name }
    }.deep_merge(@args.except(:class, :icon, :action, :back))
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
      class: class_names(identifier, @args[:class]),
      form: { data: form_data },
      data: button_data
    }.merge(@args.except(:class, :icon, :action, :back))
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
    path_args = @args[:back] ? { back: @args[:back] } : {}
    send(:"#{path_prefix}#{@target.type_tag}_path",
         @target.id, **path_args)
  end

  def path_prefix
    NAMED_ROUTE_ACTIONS.include?(@args[:action]) ? "#{action}_" : ""
  end
end

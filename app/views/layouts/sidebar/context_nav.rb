# frozen_string_literal: true

# The per-page "Actions" block inside the mobile (`xs`-only)
# offcanvas sidebar — the mobile equivalent of the top-nav's
# Actions dropdown. The visible heading reads
# `:app_context_actions.t` ("Actions:"). Rendered into
# `content_for(:context_nav_mobile)` by `add_context_nav(links)`.
#
# The desktop-only counterpart lives at
# `Views::Layouts::TopNav::ContextNav` — on desktop the top nav
# IS the context nav; on mobile the sidebar holds it.
#
# Renders the same `[text, url, args]` tuples as the top-nav
# variant, flattened into indented rows under a heading (no
# dropdown). Dispatches each tuple through
# `Views::Layouts::ContextNav::LinkRendering#render_crud_button_or_link`
# so `button: :destroy` / `:post` / `:put` / `:patch` render as
# their respective forms — pre-Phlex `sidebar_nav_link` collapsed
# every tuple to a plain `active_link_to`, which meant mobile users
# couldn't trigger destroy / post actions from the sidebar at all.
# Fixed here.
class Views::Layouts::Sidebar::ContextNav < Views::Base
  include Views::Layouts::ContextNav::LinkRendering

  # Lexical-parent namespace (`Views::Layouts::Sidebar`) provides
  # the same CSS class set that the desktop sidebar partials
  # (`Admin`, `Login`, `Section`, etc.) apply via the `classes:`
  # prop.
  CSS_CLASSES = ::Views::Layouts::Sidebar::CSS_CLASSES

  def initialize(links:)
    super()
    @links = links.compact
  end

  def view_template
    return if @links.empty?

    render_heading
    @links.each { |link| render_sidebar_link(link) }
  end

  private

  def render_heading
    div(class: class_names(CSS_CLASSES[:heading],
                           CSS_CLASSES[:mobile_only])) do
      plain("#{:app_context_actions.t}:")
    end
  end

  def render_sidebar_link(link)
    str, url, args = link
    args ||= {}
    kwargs = sidebar_link_kwargs(args)
    render_crud_button_or_link(str, url, args, kwargs)
  end

  # Builds the kwargs hash for one sidebar link: indent + mobile-only
  # classes, the nav-active Stimulus data attrs (only for plain anchor
  # links — buttons / forms aren't tracked by `nav-active`), and a
  # button-specific d-block strip.
  def sidebar_link_kwargs(args)
    kwargs = merge_context_nav_link_args(
      args,
      class: class_names(CSS_CLASSES[:indent], CSS_CLASSES[:mobile_only])
    )
    strip_d_block_for_button!(kwargs, args)
    return kwargs if args[:button].present?

    kwargs[:data] = (kwargs[:data] || {}).merge(
      nav_active_target: "link",
      action: "nav-active#navigate"
    )
    kwargs
  end

  def strip_d_block_for_button!(kwargs, args)
    return unless args[:button].present? && kwargs[:class].present?

    kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
  end
end

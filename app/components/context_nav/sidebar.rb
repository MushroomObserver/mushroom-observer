# frozen_string_literal: true

# Mobile (`xs`-only) sidebar version of the context-nav menu —
# rendered into `content_for(:context_nav_mobile)` by
# `add_context_nav(links)`. Renders the same `[text, url, args]`
# tuples as `TopBar`, but flattened into indented `active_link_to`
# rows under a heading (no dropdown, no per-link button dispatch —
# the sidebar always uses `link_to` even when the tuple says
# `button: :destroy`, matching pre-Phlex behavior).
class Components::ContextNav::Sidebar < Components::Base
  include Components::ContextNav::LinkRendering

  # Inlined from `SidebarHelper#sidebar_css_classes` (single relevant
  # caller after the conversion). Bootstrap 3 / list-group classes
  # the mobile sidebar shares with other `_sidebar.*` partials. Kept
  # as a frozen literal so subclasses can `merge` for variants
  # without mutating the canonical set.
  CSS_CLASSES = {
    wrapper: "navbar navbar-inverse sidebar-nav list-group",
    heading: "list-group-item disabled font-weight-bold",
    item: "list-group-item",
    admin: "list-group-item list-group-item-danger indent",
    indent: "list-group-item indent",
    mobile_only: "visible-xs",
    desktop_only: "hidden-xs"
  }.freeze

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

  # Pre-Phlex `sidebar_nav_link` always used `active_link_to` —
  # ignoring `args[:button]` — so `[ DESTROY ]` / `[ POST ]` tabs
  # collapse to plain text links in the mobile sidebar. Preserved
  # for parity.
  def render_sidebar_link(link)
    str, url, args = link
    kwargs = sidebar_link_kwargs(args || {})
    link_to(str, url, kwargs)
  end

  # Builds the kwargs hash for one sidebar link: indent + mobile-only
  # classes, the nav-active Stimulus data attrs (inlined from
  # `LinkHelper#active_link_to`), and a button-specific d-block strip.
  def sidebar_link_kwargs(args)
    kwargs = merge_context_nav_link_args(
      args,
      class: class_names(CSS_CLASSES[:indent], CSS_CLASSES[:mobile_only])
    )
    strip_d_block_for_button!(kwargs, args)
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

# frozen_string_literal: true

# Bootstrap 3 nav-style dropdown menu. Renders the
# `<li class="dropdown d-inline-block">` + `<a class="dropdown-toggle">` +
# `<ul class="dropdown-menu">` triple that the top-nav's Actions
# dropdown, user dropdown, and similar menus all share.
#
# Builder-pattern API: yields a `menu` object the caller registers
# sections on. Each section is `Tab::Collection`, a single
# `Tab::Base`, or an `Array<[text, url, args]>` (the array shape
# is what `Header::ContextNavHelper#add_context_nav` hands its
# downstream renderers after normalizing — no live caller passes
# raw tuple arrays directly anymore). Multiple sections are
# separated by a `<li class="divider">`. Empty sections are
# skipped (no spurious divider).
#
# @example Single-section (Actions dropdown)
#   render(Components::Dropdown.new(
#     id: "context_nav_toggle",
#     menu_id: "context_nav",
#     label: :app_context_actions.l
#   )) do |menu|
#     menu.section(@links)
#   end
#
# @example Multi-section (user-nav dropdown with auto-divider)
#   render(Components::Dropdown.new(
#     id: "user_nav_toggle",
#     menu_id: "user_drop_down",
#     label: @user.login
#   )) do |menu|
#     menu.section(Tab::UserNav::LoggedIn.new(user: @user))
#     menu.section(Tab::UserNav::LogOut.new(
#       user: @user, in_admin_mode: in_admin_mode?
#     ))
#   end
class Components::Dropdown < Components::Base
  include Components::LinkRendering

  prop :id, ::String
  prop :menu_id, ::String
  prop :label, ::String
  # Extra classes on the outer `<li class="dropdown d-inline-block">`,
  # the toggle `<a>`, and the menu `<ul>`. Defaults are nil — only
  # the index sort-bar (`Views::Layouts::Header::Sorter`) currently
  # passes any of these.
  prop :wrapper_class, _Nilable(::String), default: nil
  prop :toggle_class, _Nilable(::String), default: nil
  prop :menu_class, _Nilable(::String), default: nil
  # Optional pre-section content rendered inside the menu `<ul>`
  # above the first section. SafeBuffer (from `capture { … }`) so
  # `trusted_html` emits it intact. Used by the sort-bar to inject
  # the mobile-only `Sort by:` `<li>` header.
  prop :menu_header, _Nilable(::String), default: nil

  def initialize(...)
    super
    @sections = []
  end

  def view_template(&block)
    # `vanish` runs the caller's block to collect `menu.section(...)`
    # registrations without writing anything to the output buffer;
    # we render the wrapper + items afterwards.
    vanish(self, &block)
    rendered = @sections.map { |s| normalize_section(s) }.reject(&:empty?)
    return if rendered.empty?

    li(class: class_names("dropdown d-inline-block", @wrapper_class)) do
      render_toggle
      render_menu(rendered)
    end
  end

  # Register one section of items. Block-evaluation collects via
  # the vanish pattern above; consecutive sections get a Bootstrap
  # `<li class="divider">` between them.
  #
  # @return [nil] so the call doesn't accidentally emit anything
  def section(items)
    @sections << items
    nil
  end

  private

  def render_toggle
    a(class: class_names("dropdown-toggle", @toggle_class),
      id: @id, role: "button", href: "#",
      data: { toggle: "dropdown" },
      aria: { haspopup: "true", expanded: "false" }) do
      span { plain(@label) }
      span(class: "caret ml-2")
    end
  end

  def render_menu(sections)
    ul(id: @menu_id,
       class: class_names("dropdown-menu", @menu_class),
       aria: { labelledby: @id }) do
      trusted_html(@menu_header) if @menu_header
      sections.each_with_index do |tuples, idx|
        li(class: "divider") if idx.positive?
        tuples.each { |tuple| li { render_link(tuple) } }
      end
    end
  end

  # One `[text, url, args]` tuple → rendered link/button. Mirrors
  # the link-pipeline `Header::ContextNavHelper#context_nav_link`
  # used to provide (merge args, strip `d-block` for buttons,
  # dispatch via `LinkRendering`).
  #
  # `args[:active]` (sort-bar uses this) adds the BS3 `.active`
  # class to the link and disables it so the current sort doesn't
  # navigate away to itself.
  def render_link(tuple)
    str, url, args = tuple
    args ||= {}
    active = args.delete(:active)
    kwargs = build_link_kwargs(args, active: active)
    render_crud_button_or_link(str, url, args, kwargs.compact_blank)
  end

  def build_link_kwargs(args, active:)
    kwargs = merge_context_nav_link_args(args, {})
    kwargs = mix(kwargs, class: "active") if active
    kwargs[:disabled] = true if active
    if args[:button].present? && kwargs[:class].present?
      kwargs[:class] = kwargs[:class].gsub("d-block", "").strip
    end
    kwargs
  end

  def normalize_section(section)
    case section
    when ::Tab::Collection then section.filter_map(&:to_a)
    when ::Tab::Base then [section.to_a]
    when Array then section.compact
    else [] # nil or anything else → no items
    end
  end
end

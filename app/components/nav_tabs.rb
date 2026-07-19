# frozen_string_literal: true

# Bootstrap `nav-tabs` strip — `<ul class="nav nav-tabs">` of
# `<li class="nav-item"><a class="nav-link [active]">` links. Each
# tab is a navigation link to a different page (NOT an in-page panel
# trigger — this is NOT Bootstrap's tabs-with-panels component, just
# the navigation-strip pattern using the same tab styling). If MO
# ever needs in-page panel switching, a separate `Components::TabPanels`
# would use `NavTabs` for the strip + add the `.tab-content > .tab-pane`
# block.
#
# Caller wraps the strip with their own outer chrome (the existing
# project_tabs and project_admin_subtabs callers use slightly
# different wrapper divs / ids — keeping wrapping out of this
# component avoids parameterizing it for a pattern that varies more
# than the component itself).
#
# @example Plain
#   NavTabs(current: "members") do |tabs|
#     tabs.tab("Details",        details_path,        key: "details")
#     tabs.tab("#{n} Members",   members_path,        key: "members")
#     tabs.tab("#{n} Aliases",   aliases_path,        key: "aliases")
#   end
#
# @example With per-link extra class (matches `project_tabs` markup)
#   NavTabs(current: @current_tab,
#           link_class: "mt-3") do |tabs|
#     tabs.tab(:summary.ti, project_path(@project), key: "projects")
#     tabs.tab("#{n} #{:obs.l}", observations_path(...), key: "obs")
#   end
#
# @example With a Tab::Collection (preferred for multi-tab strips)
#   NavTabs(
#     current: @current_tab,
#     link_class: "mt-3",
#     tabs: Tab::Project::Banner.new(project: @project, user: @user)
#   )
#
# @example With wrapper chrome at the call site
#   Column(xs: 12, id: "project_tabs") do
#     NavTabs(current: @current_tab,
#             link_class: "mt-3") do |tabs|
#       # ...
#     end
#   end
class Components::NavTabs < Components::Base
  # @param current [String, Symbol, nil] tab key marked `.active`
  # @param link_class [String, nil] extra CSS classes appended to
  #   every tab's `<a class="nav-link …">` (e.g. `"mt-3"`)
  # @param attributes [Hash] arbitrary HTML attrs forwarded to the
  #   `<ul>` element (`data:`, ARIA, etc.). The `class:` is always
  #   `"nav nav-tabs"` and is not overridable from here.
  # @param tabs [Tab::Collection, Enumerable<Tab::Base>, nil]
  #   pre-built tabs to render. Any block passed to `view_template`
  #   runs *after* these, so a Collection + ad-hoc `tabs.tab(...)`
  #   calls compose cleanly.
  def initialize(current: nil, link_class: nil, attributes: {}, tabs: nil)
    super()
    @current = current
    @link_class = link_class
    @attributes = attributes
    @tabs = []
    Array(tabs).each { |t| tab(t) } if tabs
  end

  def view_template(&block)
    # `vanish` evaluates the block for its side effects (each
    # `tabs.tab(...)` push into `@tabs`) and discards any output —
    # the block configures, the `<ul>` below renders.
    vanish(&block)
    ul(class: "nav nav-tabs", **@attributes) do
      @tabs.each { |tab| render_tab(tab) }
    end
  end

  # Register a tab. Four call shapes:
  #
  # **Tab PORO** (preferred):
  #
  #     tabs.tab(Tab::Project::Summary.new(project: @project))
  #     tabs.tab(Tab::Project::Summary.new(project: @project),
  #              key: "projects")   # override auto-derived nav_key
  #
  # **Bare text + path:**
  #
  #     tabs.tab("Details", details_path, key: "details")
  #
  # **Array splat (the `[title, url, html_options]` shape):**
  #
  #     tabs.tab(*projects_index_tab, key: "index")
  #
  # In all shapes, `current:` (ctor) is matched against `key:` (per
  # tab) to decide which tab gets `.active`. With a Tab PORO, `key:`
  # defaults to `tab.nav_key` (the underscored demodulized class name);
  # pass `key: ...` to override. With a 3-arg splat the carried
  # `html_options[:class]` appends to `nav-link` (+ optional
  # `link_class:`); other attrs pass through.
  #
  # **`html_options[:class]` from Tab POROs must NOT carry Bootstrap
  # nav-tab classes** (`nav-link`, `active`, `mt-3`) — those are
  # NavTabs' responsibility. The class slot is for identifier /
  # behavior classes only (auto-generated `<thing>_link` for test
  # selectors, Stimulus hooks, etc.). Tab styling is owned by the
  # component so the same PORO renders correctly in any tab context.
  #
  # @return [nil] to prevent ERB output
  def tab(text_or_link, path = nil, html_options = {}, key: nil)
    @tabs << build_tab(text_or_link, path, html_options, key)
    nil
  end

  # Append every tab in an Enumerable (typically a `Tab::Collection`).
  # Equivalent to `each { |t| tab(t) }`; provided for readability when
  # mixing a Collection with ad-hoc `tab(...)` calls inside the
  # `view_template` block.
  def add_all(collection)
    collection.each { |t| tab(t) }
    nil
  end

  private

  def build_tab(text_or_link, path, html_options, key)
    case text_or_link
    when ::Tab::Base
      title, url, opts = text_or_link.to_a
      { text: title, path: url,
        key: key || text_or_link.nav_key, link_attrs: opts }
    else
      { text: text_or_link, path: path, key: key,
        link_attrs: html_options || {} }
    end
  end

  def render_tab(tab)
    li(class: "nav-item") do
      a(href: tab[:path], **anchor_attrs(tab)) do
        trusted_or_plain(tab[:text])
      end
    end
  end

  def anchor_attrs(tab)
    extra = tab[:link_attrs].dup
    extra_class = extra.delete(:class)
    extra.merge(class: link_classes_for(tab, extra_class))
  end

  def link_classes_for(tab, extra_class = nil)
    parts = []
    parts << @link_class if @link_class
    parts << "nav-link"
    parts << "active" if @current && tab[:key] == @current
    parts << extra_class if extra_class
    parts.join(" ")
  end

  # Tab text may be a textile-rendered html_safe string (e.g. a
  # name's display_name); `plain` would re-escape, `trusted_html`
  # emits as-is.
  def trusted_or_plain(text)
    if text.respond_to?(:html_safe?) && text.html_safe?
      trusted_html(text)
    else
      plain(text)
    end
  end
end

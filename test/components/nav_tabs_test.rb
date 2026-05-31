# frozen_string_literal: true

require("test_helper")

class NavTabsTest < ComponentTestCase
  def test_renders_nav_tabs_ul_with_one_li_per_tab
    html = render_with do |tabs|
      tabs.tab("Summary", "/summary", key: "summary")
      tabs.tab("Details", "/details", key: "details")
    end

    # Outer structure: <ul class="nav nav-tabs"> with one <li class="nav-item">
    # per tab, each containing an <a class="nav-link">.
    assert_html(html, "ul.nav.nav-tabs")
    assert_html(html, "ul.nav-tabs > li.nav-item", count: 2)
    assert_html(html, "a.nav-link[href='/summary']", text: "Summary")
    assert_html(html, "a.nav-link[href='/details']", text: "Details")
  end

  def test_current_key_marks_matching_tab_active
    html = render_with(current: "details") do |tabs|
      tabs.tab("Summary", "/summary", key: "summary")
      tabs.tab("Details", "/details", key: "details")
    end

    # Only the matching tab gets `.active`.
    assert_html(html, "a.nav-link.active[href='/details']")
    assert_no_html(html, "a.nav-link.active[href='/summary']")
  end

  def test_no_current_means_no_active_tab
    html = render_with do |tabs|
      tabs.tab("Summary", "/summary", key: "summary")
    end

    assert_no_html(html, "a.nav-link.active")
  end

  def test_tab_without_key_never_marked_active
    html = render_with(current: "anything") do |tabs|
      tabs.tab("Static", "/x") # no key:
    end

    assert_no_html(html, "a.nav-link.active")
  end

  def test_link_class_appended_to_every_tab_link
    html = render_with(link_class: "mt-3") do |tabs|
      tabs.tab("One", "/one", key: "one")
      tabs.tab("Two", "/two", key: "two")
    end

    # Per-link extra class lands on every <a>; `nav-link` and (when
    # current) `active` come after.
    assert_html(html, "a.mt-3.nav-link[href='/one']")
    assert_html(html, "a.mt-3.nav-link[href='/two']")
  end

  def test_attributes_forwarded_to_ul
    html = render_with(attributes: { id: "my_tabs",
                                     data: { x: "v" } }) do |tabs|
      tabs.tab("One", "/one")
    end

    assert_html(html, "ul#my_tabs[data-x='v'].nav.nav-tabs")
  end

  def test_html_safe_tab_text_not_escaped
    html = render_with do |tabs|
      tabs.tab("<b>bold</b>".html_safe, "/x", key: "x")
    end

    # Textile-rendered html_safe text passes through, not re-escaped.
    assert_html(html, "a.nav-link b", text: "bold")
  end

  def test_accepts_tab_poro_with_auto_derived_key
    project = projects(:bolete_project)
    # AdminMembers' nav_key defaults to alt_title "members".
    members = Tab::Project::AdminMembers.new(project: project)

    html = render_with(current: "members") do |tabs|
      tabs.tab(members)
    end

    # Tab PORO's path + title + auto-derived `*_link` class come
    # through. Auto-key "members" (from alt_title) matches `current:`
    # → active set.
    expected_href = Rails.application.routes.url_helpers.
                    project_members_path(project.id)
    assert_html(html, "a.nav-link.active.members_link[href='#{expected_href}']")
  end

  def test_tab_poro_key_override_wins_over_nav_key
    project = projects(:bolete_project)
    # AdminMembers' nav_key is "members"; override with "elsewhere".
    members = Tab::Project::AdminMembers.new(project: project)

    html = render_with(current: "elsewhere") do |tabs|
      tabs.tab(members, key: "elsewhere")
    end

    assert_html(html, "a.nav-link.active.members_link")
  end

  def test_tabs_ctor_kwarg_renders_a_collection
    project = projects(:bolete_project)
    collection = Tab::Project::AdminSubtabs.new(project: project)

    html = render(Components::NavTabs.new(
                    current: "members", tabs: collection
                  ))

    # Collection contributed 3 tabs; the one keyed "members" is active.
    assert_html(html, "ul.nav-tabs > li.nav-item", count: 3)
    assert_html(html, "a.nav-link.active.members_link")
    assert_html(html, "a.nav-link.details_link")
    assert_html(html, "a.nav-link.aliases_link")
  end

  def test_add_all_appends_collection_tabs
    project = projects(:bolete_project)
    collection = Tab::Project::AdminSubtabs.new(project: project)

    html = render(Components::NavTabs.new) do |tabs|
      tabs.add_all(collection)
      tabs.tab("Extra", "/extra", key: "extra")
    end

    # Collection's 3 tabs + 1 ad-hoc = 4 total, in declaration order.
    assert_html(html, "ul.nav-tabs > li.nav-item", count: 4)
    assert_html(html, "a.nav-link.details_link")
    assert_html(html, "a.nav-link.members_link")
    assert_html(html, "a.nav-link.aliases_link")
    assert_html(html, "a.nav-link[href='/extra']", text: "Extra")
  end

  private

  def render_with(**ctor_args, &block)
    render(Components::NavTabs.new(**ctor_args), &block)
  end
end

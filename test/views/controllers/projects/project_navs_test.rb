# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects
  # Tests for ProjectNavs: the project tabs strip, plus the admin
  # sub-tabs strip auto-rendered on an admin-subtab-controller page.
  # Banner's image/title/location/date-range rendering is tested
  # separately in banner_test.rb.
  class ProjectNavsTest < ComponentTestCase
    def test_renders_project_tabs_when_project_has_observations
      project = projects(:eol_project)
      html = render_navs(project: project)

      assert_html(html, "#project_tabs")
      assert_html(html, "ul.nav.nav-tabs")
      assert_html(html, "a.nav-link[href='/projects/#{project.id}']")
    end

    def test_renders_names_and_locations_tabs_for_empty_project
      project = projects(:empty_project)
      html = render_navs(project: project)

      assert_html(html, "#project_tabs")
      assert_includes(html, :names.ti)
      assert_includes(html, :locations.ti)
      # No targets, so no Update tab
      assert_not_includes(html, :project_updates_title.l)
    end

    def test_renders_update_tab_for_admin_with_targets
      project = projects(:rare_fungi_project)
      user = users(:rolf) # admin of rare_fungi_project
      html = render_navs(project: project, user: user)

      assert_html(html, "#project_tabs")
      assert_includes(html, :project_updates_title.l)
      assert_html(
        html,
        "a[href='/projects/#{project.id}/updates']"
      )
    end

    def test_does_not_render_update_tab_for_non_admin
      project = projects(:rare_fungi_project)
      user = users(:mary) # not admin
      html = render_navs(project: project, user: user)

      assert_not_includes(html, :project_updates_title.l)
    end

    def test_renders_admin_tab_for_admin
      project = projects(:rare_fungi_project)
      user = users(:rolf) # admin of rare_fungi_project
      html = render_navs(project: project, user: user)

      assert_html(html, "a[href='/projects/#{project.id}/admin']")
      assert_includes(html, :show_project_admin_tab.l)
    end

    def test_does_not_render_admin_tab_for_non_admin
      project = projects(:rare_fungi_project)
      user = users(:mary) # not admin of rare_fungi_project
      html = render_navs(project: project, user: user)

      assert_no_html(html, "a[href='/projects/#{project.id}/admin']")
    end

    def test_active_tab_highlights_current_tab
      project = projects(:eol_project)
      html = render_navs(project: project, current_tab: "observations")

      # Observations tab should have active class
      assert_html(html, "a.nav-link.active[href*='observations']")
    end

    def test_summary_tab_active_for_projects_controller
      project = projects(:eol_project)
      html = render_navs(project: project, current_tab: "projects")

      # Projects tab (summary) should have active class
      assert_html(html, "a.nav-link.active[href='/projects/#{project.id}']")
    end

    # On the Project show page, the banner sits directly above
    # ProjectBanner's inline title (mt-3 only). Every other
    # project-scoped page (locations, checklists, admin, ...) has a
    # title/content below the tabs, which needs a bottom margin too
    # (my-3). project_page? drives this choice, so the margin class
    # is the contract under test here, not incidental styling.
    # rubocop:disable-next MO/NoCosmeticClassAssertion
    def test_project_tabs_margin_on_projects_show
      project = projects(:eol_project)
      controller.define_singleton_method(:controller_name) { "projects" }
      controller.define_singleton_method(:action_name) { "show" }

      html = render_navs(project: project)

      assert_html(html, "#project_tabs.mt-3")
      assert_no_html(html, "#project_tabs.my-3")
    end

    # Every controller that renders AdminSubtabs below the tabs --
    # its mt-2 already separates it from the tabs, so the tabs don't
    # need a bottom margin either (same contract as
    # test_project_tabs_margin_on_projects_show above).
    # rubocop:disable-next MO/NoCosmeticClassAssertion
    def test_project_tabs_margin_on_admin_subtab_pages
      project = projects(:eol_project)
      controller.define_singleton_method(:controller_name) { "locations" }
      controller.define_singleton_method(:action_name) { "index" }

      %w[projects/admin projects/members projects/aliases
         field_slips projects/field_slips
         projects/external_sites].each do |path|
        controller.define_singleton_method(:controller_path) { path }
        html = render_navs(project: project)

        assert_html(html, "#project_tabs.mt-3")
      end
    end

    # rubocop:disable-next MO/NoCosmeticClassAssertion
    def test_project_tabs_margin_off_projects_show
      project = projects(:eol_project)
      controller.define_singleton_method(:controller_name) { "locations" }
      controller.define_singleton_method(:action_name) { "index" }

      html = render_navs(project: project)

      assert_html(html, "#project_tabs.my-3")
      assert_no_html(html, "#project_tabs.mt-3")
    end

    # ADMIN_SUBTAB_CONTROLLERS maps each admin-subtab controller path
    # to the sub-tab it should land on -- the point of moving this
    # into ProjectNavs is that no caller passes current_subtab.
    def test_renders_admin_subtabs_with_correct_current_subtab
      project = projects(:eol_project)
      controller.define_singleton_method(:controller_name) { "locations" }
      controller.define_singleton_method(:action_name) { "index" }
      # The External Sites sub-tab is a site admin's (#5416) --
      # stub admin mode so all 4 paths render their active sub-tab.
      stub_admin_mode!

      {
        "projects/admin" => "/projects/#{project.id}/admin",
        "projects/members" => "/projects/#{project.id}/members",
        "projects/aliases" => "/projects/#{project.id}/aliases",
        "field_slips" => "/field_slips?project=#{project.id}",
        "projects/field_slips" => "/field_slips?project=#{project.id}",
        "projects/external_sites" =>
          "/projects/#{project.id}/external_sites"
      }.each do |path, active_href|
        controller.define_singleton_method(:controller_path) { path }
        html = render_navs(project: project)

        assert_html(html, "#project_admin_subtabs")
        assert_html(html, "a.nav-link.active[href='#{active_href}']")
      end
    end

    def test_does_not_render_admin_subtabs_off_an_admin_subtab_page
      project = projects(:eol_project)
      controller.define_singleton_method(:controller_name) { "locations" }
      controller.define_singleton_method(:action_name) { "index" }
      controller.define_singleton_method(:controller_path) do
        "projects/locations"
      end

      html = render_navs(project: project)

      assert_no_html(html, "#project_admin_subtabs")
    end

    private

    def render_navs(project: projects(:eol_project),
                    user: nil, current_tab: nil)
      render(ProjectNavs.new(project: project,
                             user: user,
                             current_tab: current_tab))
    end
  end
end

# frozen_string_literal: true

require("test_helper")

# Covers all 10 Tab::Project::* singular Tab POROs in one file. Each
# test asserts:
# - #title (the rendered text)
# - #path (compared against the route helper, not a hardcoded URL)
# - #alt_title (drives the stable `*_link` selector class via
#   Tab::Base#derived_html_class)
# - #html_options[:class] matching the `<alt_title>_link` pattern
#   (composed in by `Tab::Base::HtmlOptionsComposer`)
module Tab::Project
  class TabsTest < UnitTestCase
    # Routes are accessed via a proxy method instead of
    # `include Rails.application.routes.url_helpers` — including
    # the helpers makes MiniTest treat any route named `test_*`
    # (e.g. `/test_pages/...`) as a test method on this class.
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @project = projects(:bolete_project)
    end

    def test_summary
      tab = Tab::Project::Summary.new(project: @project)

      assert_equal(:SUMMARY.t, tab.title)
      assert_equal(routes.project_path(id: @project.id), tab.path)
      assert_equal("summary", tab.alt_title)
      assert_equal("summary_link", link_class(tab))
    end

    def test_observations
      tab = Tab::Project::Observations.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_match(/observations/i, tab.title)
      assert_equal(routes.observations_path(project: @project), tab.path)
      assert_equal("observations", tab.alt_title)
      assert_equal("observations_link", link_class(tab))
    end

    def test_species_lists
      tab = Tab::Project::SpeciesLists.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.species_lists_path(project: @project), tab.path)
      assert_equal("species_lists", tab.alt_title)
      assert_equal("species_lists_link", link_class(tab))
    end

    def test_names
      tab = Tab::Project::Names.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.checklist_path(project_id: @project.id),
                   tab.path)
      assert_equal("checklists", tab.alt_title)
      assert_equal("checklists_link", link_class(tab))
    end

    def test_locations
      tab = Tab::Project::Locations.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.project_locations_path(project_id: @project.id),
                   tab.path)
      assert_equal("locations", tab.alt_title)
      assert_equal("locations_link", link_class(tab))
    end

    def test_updates
      tab = Tab::Project::Updates.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.project_updates_path(project_id: @project.id),
                   tab.path)
      assert_equal("updates", tab.alt_title)
      assert_equal("updates_link", link_class(tab))
    end

    def test_admin
      tab = Tab::Project::Admin.new(project: @project)

      assert_equal(:show_project_admin_tab.l, tab.title)
      assert_equal(routes.project_admin_path(project_id: @project.id),
                   tab.path)
      assert_equal("admin", tab.alt_title)
      assert_equal("admin_link", link_class(tab))
    end

    def test_admin_details
      tab = Tab::Project::AdminDetails.new(project: @project)

      assert_equal(:show_project_admin_details_tab.l, tab.title)
      assert_equal(routes.project_admin_path(project_id: @project.id),
                   tab.path)
      assert_equal("details", tab.alt_title)
      assert_equal("details_link", link_class(tab))
    end

    def test_admin_members
      tab = Tab::Project::AdminMembers.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.project_members_path(@project.id), tab.path)
      assert_equal("members", tab.alt_title)
      assert_equal("members_link", link_class(tab))
    end

    def test_admin_aliases
      tab = Tab::Project::AdminAliases.new(project: @project)

      assert_match(/\A\d+ /, tab.title)
      assert_equal(routes.project_aliases_path(project_id: @project.id),
                   tab.path)
      assert_equal("aliases", tab.alt_title)
      assert_equal("aliases_link", link_class(tab))
    end

    def test_to_a_legacy_shape
      tab = Tab::Project::Summary.new(project: @project)
      title, url, opts = tab.to_a

      assert_equal(tab.title, title)
      assert_equal(tab.path, url)
      assert_equal("summary_link", opts[:class])
    end

    def test_nav_key_defaults_to_alt_title
      # AdminMembers: alt_title "members" → nav_key "members"
      # (matches `current_subtab: "members"` from the controller).
      assert_equal("members",
                   Tab::Project::AdminMembers.new(project: @project).nav_key)
      # Names: alt_title "checklists" → nav_key "checklists"
      # (matches `active_project_tab` returning controller_name).
      assert_equal("checklists",
                   Tab::Project::Names.new(project: @project).nav_key)
    end

    def test_summary_nav_key_overrides_alt_title
      # Summary is the odd one — alt_title "summary" but nav_key
      # "projects" because banner's current_tab comes from
      # controller_name ("projects" on the project show page).
      tab = Tab::Project::Summary.new(project: @project)

      assert_equal("summary", tab.alt_title)
      assert_equal("projects", tab.nav_key)
    end

    # --- Action-nav tabs (the singleton tabs converted out of
    # `Tabs::ProjectsHelper`'s standalone tab methods).

    def test_index_action_nav_tab
      tab = Tab::Project::Index.new

      assert_equal(:cancel_to_index.t(type: :PROJECT), tab.title)
      assert_equal(routes.projects_path, tab.path)
    end

    def test_new_action_nav_tab
      tab = Tab::Project::New.new

      assert_equal(:list_projects_add_project.t, tab.title)
      assert_equal(routes.new_project_path, tab.path)
    end

    def test_change_member_status_action_nav_tab
      tab = Tab::Project::ChangeMemberStatus.new(project: @project)

      assert_equal(:change_member_status_edit.t, tab.title)
      assert_equal(routes.edit_project_path(@project.id), tab.path)
    end

    def test_for_user_action_nav_tab
      user = users(:mary)
      tab = Tab::Project::ForUser.new(user: user)

      assert_equal(:app_your_projects.l, tab.title)
      assert_equal(routes.projects_path(member: user.id), tab.path)
    end

    # Alias tabs set `model`, so the auto-derived selector class
    # follows the model-aware flavour. Edit case: alt_title="EDIT"
    # short-circuits the model-name segment → class = "edit_link"
    # + per-id flavour "edit_link_<id>". Add case: no alt_title +
    # title="ADD" doesn't contain the model name → composes as
    # "add_project_alias_link" + Bootstrap button styling from
    # html_options.
    def test_alias_edit_uses_model_derived_class
      tab = Tab::Project::AliasEdit.new(
        project_id: @project.id, name: "MO", id: 42
      )

      assert_equal("MO", tab.title)
      assert_equal(routes.edit_project_alias_path(project_id: @project.id,
                                                  id: 42),
                   tab.path)
      assert_equal(:EDIT.t, tab.alt_title)

      link_class = tab.html_options[:class]
      assert_includes(link_class, "edit_link")
      assert_includes(link_class, "edit_link_42")
    end

    def test_alias_new_uses_model_derived_class
      tab = Tab::Project::AliasNew.new(
        project_id: @project.id, target_id: 5, target_type: "Location"
      )

      assert_equal(:ADD.t, tab.title)
      assert_equal(
        routes.new_project_alias_path(project_id: @project.id,
                                      target_id: 5, target_type: "Location"),
        tab.path
      )

      opts = tab.html_options
      assert_includes(opts[:class], "add_project_alias_link")
    end

    private

    def link_class(tab)
      tab.html_options[:class]
    end
  end
end

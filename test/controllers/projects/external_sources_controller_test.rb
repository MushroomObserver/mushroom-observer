# frozen_string_literal: true

require("test_helper")

module Projects
  # Configuring where a project's observations may come from, and what
  # MO may do about them (#5416).
  class ExternalSourcesControllerTest < FunctionalTestCase
    setup do
      @controller = Projects::ExternalSourcesController.new
      @project = projects(:eol_project)
      @site = external_sites(:inaturalist)
      # rolf is an admin of the eol project.
      @admin = users(:rolf)
    end

    def source
      ProjectExternalSource.find_by(project: @project, external_site: @site)
    end

    def create_source(**args)
      ProjectExternalSource.create!(project: @project, external_site: @site,
                                    **args)
    end

    def test_index_needs_a_project_admin
      # katrina is a project member, not an admin of it.
      login("katrina")
      get(:index, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
    end

    def test_index_draws_a_form_for_a_project_with_no_source
      login("rolf")
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
      assert_select("form[data-turbo='true']")
      assert_select("#project_source_approval")
      # Nothing is created merely by looking at the page.
      assert_nil(source)
    end

    def test_index_shows_the_ceiling_to_a_project_admin
      create_source(use_criteria: true, import_limit: 500)
      login("rolf")
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
      # Only a site admin gets the editable field.
      assert_select("input[name='project_external_source[import_limit]']",
                    count: 0)
      assert_select("#project_source_approval", text: /500/)
    end

    def test_index_offers_the_ceiling_to_a_site_admin
      create_source(use_criteria: true)
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
      assert_select("input[name='project_external_source[import_limit]']")
    end

    def test_create_saves_the_first_configuration
      login("rolf")
      post(:create,
           params: { project_id: @project.id,
                     project_external_source: { remote_project_id: "169620",
                                                use_criteria: "1" } })

      assert_redirected_to(
        project_external_sources_path(project_id: @project.id)
      )
      assert_equal("169620", source.remote_project_id)
      assert(source.use_criteria?)
      assert_equal(@site, source.external_site)
    end

    def test_create_refuses_to_act_without_approval
      login("rolf")
      post(:create,
           params: { project_id: @project.id,
                     project_external_source: { use_criteria: "1",
                                                alerting: "1" } })

      assert_flash_error
      assert_unprocessable
      assert_select("form[data-turbo='true']")
      assert_nil(source)
    end

    def test_update_changes_the_configuration
      existing = create_source(remote_project_id: "169620")
      login("rolf")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_source: { remote_project_id: "1234" } })

      assert_redirected_to(
        project_external_sources_path(project_id: @project.id)
      )
      assert_equal("1234", existing.reload.remote_project_id)
    end

    def test_update_refuses_to_act_without_a_source
      existing = create_source
      existing.approve(@admin)
      login("rolf")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_source: { importing: "1" } })

      assert_flash_error
      assert_unprocessable
      assert_not(existing.reload.importing?)
    end

    def test_a_project_admin_cannot_move_the_ceiling
      existing = create_source(use_criteria: true)
      login("rolf")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_source: { import_limit: "99999" } })

      assert_equal(10_000, existing.reload.import_limit)
    end

    def test_a_site_admin_can_move_the_ceiling
      existing = create_source(use_criteria: true)
      make_admin("dick")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_source: { import_limit: "99999" } })

      assert_equal(99_999, existing.reload.import_limit)
    end

    def test_approve_is_the_site_admins_to_give
      existing = create_source(use_criteria: true)
      login("rolf")
      patch(:approve, params: { project_id: @project.id, id: existing.id })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
      assert_not(existing.reload.approved?)
    end

    def test_approve_records_the_site_admin
      existing = create_source(use_criteria: true)
      make_admin("dick")
      patch(:approve, params: { project_id: @project.id, id: existing.id })

      assert_redirected_to(
        project_external_sources_path(project_id: @project.id)
      )
      assert(existing.reload.approved?)
      assert_equal(users(:dick), existing.approved_by)
    end

    def test_revoke_turns_both_flags_off
      existing = create_source(use_criteria: true)
      existing.approve(@admin)
      existing.update!(alerting: true, importing: true)
      make_admin("dick")
      patch(:revoke, params: { project_id: @project.id, id: existing.id })

      assert_redirected_to(
        project_external_sources_path(project_id: @project.id)
      )
      existing.reload

      assert_not(existing.approved?)
      assert_not(existing.alerting?)
      assert_not(existing.importing?)
    end

    def test_a_source_of_another_project_is_not_found
      other = ProjectExternalSource.create!(project: projects(:bolete_project),
                                            external_site: @site,
                                            use_criteria: true)
      make_admin("dick")
      patch(:approve, params: { project_id: @project.id, id: other.id })

      assert_flash_error
      assert_not(other.reload.approved?)
    end
  end
end

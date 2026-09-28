# frozen_string_literal: true

require("test_helper")

module Projects
  # A project's relationship with each external site: what it already
  # holds from them, and what MO may do about iNaturalist (#5416).
  class ExternalSitesControllerTest < FunctionalTestCase
    include InatStubHelpers

    YOOP = { id: 303_327, title: "2026 NAMA Yoop" }.freeze

    setup do
      @controller = Projects::ExternalSitesController.new
      @project = projects(:eol_project)
      @inat = external_sites(:inaturalist)
      stub_candidate_counts
    end

    # Every render of the page asks iNat what a configuration would
    # bring in; the numbers themselves are Inat::CandidateCount's
    # own test.
    def stub_candidate_counts(total = 238)
      stub_request(:get, %r{#{Inat::Constants::API_BASE}/observations}o).
        to_return(status: 200,
                  body: { total_results: total }.to_json)
    end

    def project_site
      ProjectExternalSite.find_by(project: @project, external_site: @inat)
    end

    def create_project_site(**args)
      ProjectExternalSite.create!(project: @project, external_site: @inat,
                                  **args)
    end

    def stub_project_lookup(path, results)
      stub_request(:get, "#{Inat::Constants::API_BASE}/#{path}").
        with(headers: { "Accept" => "application/json",
                        "User-Agent" => user_agent }).
        to_return(status: 200, body: { results: results }.to_json)
    end

    # --- who may see it ----------------------------------------------

    def test_index_is_not_for_a_project_admin
      # rolf is an admin of the EOL project, but not in admin mode.
      login("rolf")
      get(:index, params: { project_id: @project.id })

      assert_redirected_to(project_path(@project.id))
      assert_flash_error
    end

    def test_index_is_for_a_site_admin
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_response(:success)
      assert_select("form[data-turbo='true']")
    end

    # --- what it shows -----------------------------------------------

    def test_index_has_a_panel_per_external_site
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      ExternalSite.find_each do |site|
        assert_select("#project_site_#{site.id}", text: /#{site.name}/)
      end
    end

    # Only iNaturalist answers queries, so only its panel has a form.
    def test_only_inaturalist_offers_configuration
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_select("#project_site_#{@inat.id} form")
      assert_select("#project_site_#{external_sites(:mycoportal).id} form",
                    count: 0)
    end

    def test_index_counts_what_the_project_already_holds
      obs = @project.observations.first
      ExternalLink.create!(target: obs, external_site: @inat,
                           user: obs.user, external_id: "12345",
                           relationship: :import)
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      holdings = @project.external_site_holdings(@inat)

      assert_equal(1, holdings.linked)
      assert_equal(1, holdings.imported)
      assert_select("#project_site_#{@inat.id}",
                    text: /#{holdings.observations} observations/)
    end

    def test_index_links_to_the_resolved_inat_project
      create_project_site(remote_project_id: "303327",
                          remote_project_name: "2026 NAMA Yoop")
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_select(
        "a[href='#{Inat::Constants::SITE}/projects/303327']",
        text: "2026 NAMA Yoop (238 not yet imported)"
      )
    end

    # A project that constrains nothing has nothing to follow, so it is
    # told why rather than given a checkbox that would do nothing.
    def test_a_project_without_constraints_is_told_so
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_select("#project_site_#{@inat.id}",
                    text: /#{:project_sites_no_constraints.l}/)
      assert_select("input[name='project_external_site[use_constraints]']",
                    count: 0)
    end

    # The count beside the checkbox is what following the constraints
    # would bring in that MO does not already hold.
    def test_constraints_carry_what_they_would_bring_in
      project = projects(:rare_fungi_project)
      stub_request(:get, %r{#{Inat::Constants::API_BASE}/taxa}o).
        to_return(status: 200, body: { results: [] }.to_json)
      stub_request(:get, %r{#{Inat::Constants::API_BASE}/places}o).
        to_return(status: 200, body: { results: [] }.to_json)
      make_admin("dick")
      get(:index, params: { project_id: project.id })

      assert_select("label",
                    text: /#{:project_sites_use_constraints.l}.*238/)
    end

    # Saved: the panel shows what the id resolved to, with the field
    # behind it for a clear to bring back.
    def test_a_saved_project_shows_as_a_link_with_the_field_hidden
      create_project_site(remote_project_id: "303327",
                          remote_project_name: "2026 NAMA Yoop")
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_select("[data-controller='remote-project']") do
        assert_select("[data-remote-project-target='display']:not([hidden])")
        assert_select("[data-remote-project-target='entry'][hidden]")
        assert_select("input[data-remote-project-target='input']" \
                      "[value='303327']")
        # The site's clear convention: the circled red X, as an
        # anchor so the browser paints it no button box.
        assert_select("a.text-danger[data-action='remote-project" \
                      "#clear:prevent']")
        assert_select("[data-remote-project-target='display'] label",
                      text: /iNaturalist project/)
      end
    end

    def test_an_unset_project_shows_the_field
      make_admin("dick")
      get(:index, params: { project_id: @project.id })

      assert_select("[data-remote-project-target='display'][hidden]")
      assert_select("[data-remote-project-target='entry']:not([hidden])")
      # The site's own help convention: a question-mark trigger beside
      # the label opening a collapsed block, not a title attribute.
      assert_select("a.info-collapse-trigger")
      assert_select("#project_external_site_remote_project_id_help")
    end

    # --- saving ------------------------------------------------------

    def test_create_resolves_and_saves_the_inat_project
      stub_project_lookup("projects/2026-nama-yoop", [YOOP])
      make_admin("dick")
      post(:create,
           params: { project_id: @project.id,
                     project_external_site: {
                       remote_project_id: "2026-nama-yoop"
                     } })

      assert_redirected_to(
        project_external_sites_path(project_id: @project.id)
      )
      assert_equal("303327", project_site.remote_project_id)
      assert_equal("2026 NAMA Yoop", project_site.remote_project_name)
    end

    def test_create_rejects_a_value_naming_no_inat_project
      stub_project_lookup("projects/nope", [])
      stub_project_lookup("projects?q=nope&per_page=10", [])
      make_admin("dick")
      post(:create,
           params: { project_id: @project.id,
                     project_external_site: { remote_project_id: "nope" } })

      assert_flash_error
      assert_unprocessable
      assert_select("form[data-turbo='true']")
      assert_nil(project_site)
    end

    def test_create_refuses_to_act_without_a_source
      make_admin("dick")
      post(:create,
           params: { project_id: @project.id,
                     project_external_site: { alerting: "1" } })

      assert_flash_error
      assert_unprocessable
      assert_nil(project_site)
    end

    def test_update_keeps_a_resolved_project_without_asking_inat_again
      existing = create_project_site(remote_project_id: "303327",
                                     remote_project_name: "2026 NAMA Yoop")
      make_admin("dick")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_site: { remote_project_id: "303327",
                                               use_constraints: "1" } })

      assert_redirected_to(
        project_external_sites_path(project_id: @project.id)
      )
      existing.reload

      assert(existing.use_constraints?)
      assert_equal("2026 NAMA Yoop", existing.remote_project_name)
    end

    def test_update_clears_the_inat_project
      existing = create_project_site(remote_project_id: "303327",
                                     remote_project_name: "2026 NAMA Yoop",
                                     use_constraints: true)
      make_admin("dick")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_site: { remote_project_id: "",
                                               use_constraints: "1" } })
      existing.reload

      assert_nil(existing.remote_project_id)
      assert_nil(existing.remote_project_name)
    end

    def test_a_site_admin_sets_the_ceiling
      existing = create_project_site(use_constraints: true)
      make_admin("dick")
      patch(:update,
            params: { project_id: @project.id, id: existing.id,
                      project_external_site: { import_limit: "500" } })

      assert_equal(500, existing.reload.import_limit)
    end

    def test_a_row_of_another_project_is_not_found
      other = ProjectExternalSite.create!(project: projects(:bolete_project),
                                          external_site: @inat,
                                          use_constraints: true)
      make_admin("dick")
      patch(:update,
            params: { project_id: @project.id, id: other.id,
                      project_external_site: { alerting: "1" } })

      assert_flash_error
      assert_not(other.reload.alerting?)
    end
  end
end

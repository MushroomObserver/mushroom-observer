# frozen_string_literal: true

require("test_helper")

# An import a project admin starts for their project (#5416). A site
# admin turns importing on for the project's iNaturalist row; the
# project's admins are then the people who may start one, and what it
# covers is the project's configuration rather than a choice on the
# form.
class InatImportsProjectScopeTest < FunctionalTestCase
  include InatStubHelpers

  def setup
    super
    @controller = InatImportsController.new
    @project = projects(:rare_fungi_project)
    @inat = external_sites(:inaturalist)
    @admin = users(:rolf)
    stub_resolved_targets
    stub_resolved_places
  end

  # The project's target locations, which narrow the search alongside
  # its names. Left unresolved they would widen it, not open it up.
  def stub_resolved_places
    @project.target_locations.each_with_index do |location, i|
      place = location.name.to_s.split(",").first.to_s.strip
      stub_request(:get, inat_api_matcher("places/autocomplete")).
        with(query: hash_including("q" => place)).
        to_return(status: 200,
                  body: { results: [{ "id" => 8001 + i,
                                      "name" => place }] }.to_json)
    end
  end

  # The project's two target names, as iNat answers for them. The
  # mapping is tested in Inat::ConstraintMapper.
  def stub_resolved_targets
    @project.target_names.each_with_index do |name, i|
      stub_request(:get, inat_api_matcher("taxa")).
        with(query: hash_including("q" => name.text_name)).
        to_return(status: 200,
                  body: { results: [{ "id" => 9001 + i,
                                      "name" => name.text_name }] }.to_json)
    end
  end

  def stub_unresolved_targets
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(status: 200, body: { results: [] }.to_json)
  end

  def project_site(**args)
    ProjectExternalSite.create!(project: @project, external_site: @inat,
                                use_constraints: true, importing: true,
                                **args)
  end

  def taxon_ids
    @project.target_names.each_with_index.map { |_n, i| 9001 + i }.join(",")
  end

  # A translation read as a pattern, so its punctuation stays literal.
  def matching(tag)
    Regexp.new(Regexp.escape(tag.l))
  end

  # ---- the form a project admin is given -------------------------------

  def test_the_scoped_form_states_the_search_rather_than_offering_it
    site = project_site

    login(@admin.login)
    get(:new, params: { project_site: site.id })

    assert_response(:success)
    assert_select("input[name='inat_import[project_site]'][value=?]",
                  site.id.to_s)
    assert_select("input[name='inat_import[choose_method]']", count: 0)
    assert_select("a[href*=?]", "taxon_id=#{CGI.escape(taxon_ids)}")
  end

  def test_the_scoped_form_turns_on_importing_others_and_skeletons
    login(@admin.login)
    get(:new, params: { project_site: project_site.id })

    assert_select("input[name='inat_import[import_others]'][checked]")
    assert_select("input[name='inat_import[create_skeletons]'][checked]")
  end

  # The consent an ordinary importer gives is about their material. An
  # admin importing a project is bringing in other people's.
  def test_the_scoped_form_asks_for_the_consent_that_fits
    login(@admin.login)
    get(:new, params: { project_site: project_site.id })

    assert_select("label", text: matching(:inat_import_consent_project))
    assert_select("label", text: matching(:inat_import_consent), count: 0)
  end

  # The project is where the observations are filed, which the admin
  # settled by starting here; the autocompleter would invite changing it.
  def test_the_scoped_form_states_the_project
    login(@admin.login)
    get(:new, params: { project_site: project_site.id })

    assert_select("input[name='inat_import[inat_project]']", count: 0)
    assert_select("div", text: /#{@project.title}/)
  end

  def test_the_recheck_choice_stays
    login(@admin.login)
    get(:new, params: { project_site: project_site.id })

    assert_select("input[name='inat_import[recheck_all]']")
  end

  # ---- who the scope is for --------------------------------------------

  def test_a_member_who_is_not_an_admin_gets_the_ordinary_form
    site = project_site

    login(users(:mary).login)
    get(:new, params: { project_site: site.id })

    assert_response(:success)
    assert_select("input[name='inat_import[project_site]']", count: 0)
    assert_select("input[name='inat_import[inat_project]']")
  end

  # Importing is what a site admin turns on, and it is what permits
  # this. An alerting-only row does not.
  def test_a_project_not_set_up_for_importing_gets_the_ordinary_form
    site = project_site(importing: false, alerting: true)

    login(@admin.login)
    get(:new, params: { project_site: site.id })

    assert_select("input[name='inat_import[project_site]']", count: 0)
    assert_select("input[name='inat_import[inat_project]']")
  end

  def test_an_unknown_project_site_gets_the_ordinary_form
    login(@admin.login)
    get(:new, params: { project_site: "0" })

    assert_response(:success)
    assert_select("input[name='inat_import[project_site]']", count: 0)
  end

  # ---- what the import is recorded as ----------------------------------

  def test_the_scope_is_rebuilt_rather_than_read_back_from_the_form
    site = project_site
    stub_taxon_validation
    stub_counts

    login(@admin.login)
    post(:create,
         params: { project_site: site.id, consent: "1",
                   import_others: "1", create_skeletons: "1",
                   confirmed: "1",
                   # What a tampered form would carry.
                   inat_url: "https://www.inaturalist.org/observations" \
                             "?user_login=someone_else",
                   inat_project_id: projects(:eol_project).id.to_s })

    import = InatImport.where(user: @admin).order(:id).last

    assert_equal(@project.id, import.project_id)
    assert(import.import_others)
    assert(import.create_skeletons)
    assert_includes(import.inat_url, "taxon_id=#{CGI.escape(taxon_ids)}")
    assert_not_includes(import.inat_url, "someone_else")
  end

  # The confirm page is a second form, and the scope has to survive it
  # or the import it finally starts would be a different one.
  def test_the_scope_survives_the_confirm_round_trip
    site = project_site
    stub_taxon_validation
    stub_counts

    login(@admin.login)
    post(:create, params: { project_site: site.id, consent: "1",
                            import_others: "1", create_skeletons: "1" })

    assert_unprocessable
    assert_select(
      "input[name='inat_import_confirm[project_site]'][value=?]",
      site.id.to_s
    )
  end

  def test_the_details_say_whose_observations_a_project_import_covers
    login(@admin.login)
    get(:new, params: { project_site: project_site.id })

    assert_select("li", text: matching(:inat_details_includes_project))
    assert_select("li", text: matching(:inat_details_includes_all), count: 0)
  end

  # A project none of whose target names iNat knows would search for
  # every fungus in its area and dates, which is not what the project
  # means.
  def test_an_import_whose_targets_do_not_resolve_is_refused
    site = project_site
    stub_unresolved_targets

    login(@admin.login)
    post(:create, params: { project_site: site.id, consent: "1",
                            import_others: "1", confirmed: "1" })

    assert_flash_error
    assert_unprocessable
    assert_empty(InatImport.where(user: @admin, project_id: @project.id))
  end

  def stub_taxon_validation
    results = @project.target_names.each_with_index.map do |_name, i|
      { "id" => 9001 + i, "ancestor_ids" => [47_170, 9001 + i] }
    end
    stub_request(:get, inat_api_matcher("taxa")).
      with(query: hash_including("id" => taxon_ids)).
      to_return(status: 200, body: { results: results }.to_json)
  end

  def stub_counts(total = 7)
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 200, body: { total_results: total }.to_json)
  end
end

# frozen_string_literal: true

require("test_helper")

# How many iNat observations a project's saved configuration would bring
# in, counted without importing anything (#5416).
class Inat::CandidateCountTest < UnitTestCase
  include InatStubHelpers

  def setup
    super
    @project = projects(:eol_project)
    @site = external_sites(:inaturalist)
  end

  def project_site(**args)
    ProjectExternalSite.new(project: @project, external_site: @site, **args)
  end

  def stub_count(query_fragment, total)
    stub_request(:get, inat_api_matcher("observations")).
      with(query: hash_including(query_fragment)).
      to_return(status: 200, body: { total_results: total }.to_json)
  end

  def candidates_for(**args)
    Inat::CandidateCount.for(project_site: project_site(**args))
  end

  # Neither shape set means every fungus on iNat, which is not a number
  # worth showing; the page says so instead.
  def test_nothing_configured_has_no_number
    candidates = candidates_for

    assert_not(candidates.configured)
    assert_nil(candidates.total)
  end

  def test_a_sister_project_on_its_own
    stub_count({ "project_id" => "303327" }, 338)
    candidates = candidates_for(remote_project_id: "303327")

    assert(candidates.configured)
    assert_equal(338, candidates.total)
  end

  # Whatever else is set, MO imports fungi and slime moulds.
  def test_a_sister_project_is_still_filtered_to_importable_taxa
    stub_count({ "taxon_id" =>
                 Inat::Constants::IMPORTABLE_TAXON_IDS_ARG }, 338)

    assert_equal(338, candidates_for(remote_project_id: "303327").total)
  end

  # What MO already holds is left out, so the number is what remains to
  # import rather than what exists.
  def test_the_count_excludes_what_mo_already_imported
    stub_count({ "without_field" =>
                 Inat::Constants::MO_URL_OBSERVATION_FIELD_NAME }, 12)

    assert_equal(12, candidates_for(remote_project_id: "303327").total)
  end

  def test_the_constraints_on_their_own
    @project.update!(location: locations(:burbank))
    stub_count({ "swlat" => locations(:burbank).south.to_s }, 236)

    assert_equal(236, candidates_for(use_constraints: true).total)
  end

  def test_the_constraints_narrow_a_sister_project
    @project.update!(location: locations(:burbank))
    stub_count({ "project_id" => "303327",
                 "swlat" => locations(:burbank).south.to_s }, 47)

    candidates = candidates_for(remote_project_id: "303327",
                                use_constraints: true)

    assert_equal(47, candidates.total)
  end

  # An unfollowed constraint is not part of the search.
  def test_unfollowed_constraints_do_not_narrow
    @project.update!(location: locations(:burbank))
    stub_count({ "project_id" => "303327" }, 338)

    assert_equal(338, candidates_for(remote_project_id: "303327").total)
  end

  def test_inat_not_answering_is_no_number_rather_than_a_wrong_one
    stub_request(:get, inat_api_matcher("observations")).
      to_return(status: 500)
    candidates = candidates_for(remote_project_id: "303327")

    assert(candidates.configured)
    assert_nil(candidates.total)
  end

  # A target iNat does not know is left out of the search and named,
  # so an admin can see why a number is bigger than the project means.
  def test_unresolved_targets_ride_along_with_the_count
    project = projects(:rare_fungi_project)
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(status: 200, body: { results: [] }.to_json)
    stub_request(:get, inat_api_matcher("places")).
      to_return(status: 200, body: { results: [] }.to_json)
    stub_count({ "taxon_id" =>
                 Inat::Constants::IMPORTABLE_TAXON_IDS_ARG }, 9_999)
    site = ProjectExternalSite.new(project: project, external_site: @site,
                                   use_constraints: true)

    candidates = Inat::CandidateCount.for(project_site: site)

    assert_equal(project.target_names.map(&:text_name),
                 candidates.unresolved_names)
    assert_equal(project.target_locations.map(&:name),
                 candidates.unresolved_locations)
  end

  def test_an_unconfigured_row_has_no_unresolved_targets
    candidates = candidates_for

    assert_empty(candidates.unresolved_names)
    assert_empty(candidates.unresolved_locations)
  end
end

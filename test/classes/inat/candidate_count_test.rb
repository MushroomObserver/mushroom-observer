# frozen_string_literal: true

require("test_helper")

# How many iNat observations a project's configuration would bring in,
# counted without importing anything (#5416).
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
    stub_request(:get, %r{#{Inat::Constants::API_BASE}/observations}o).
      with(query: hash_including(query_fragment)).
      to_return(status: 200, body: { total_results: total }.to_json)
  end

  def counts_for(**args)
    Inat::CandidateCount.for(project: @project,
                             project_site: project_site(**args))
  end

  def test_nothing_configured_counts_nothing
    counts = counts_for

    assert_nil(counts.constraints)
    assert_nil(counts.combined)
  end

  def test_a_sister_project_on_its_own
    stub_count({ "project_id" => "303327" }, 338)

    assert_equal(338, counts_for(remote_project_id: "303327").combined)
  end

  # What MO already holds is left out, so the number is what remains to
  # import rather than what exists.
  def test_the_count_excludes_what_mo_already_imported
    stub_count({ "without_field" =>
                 Inat::Constants::MO_URL_OBSERVATION_FIELD_NAME }, 12)

    assert_equal(12, counts_for(remote_project_id: "303327").combined)
  end

  def test_the_constraints_narrow_a_sister_project
    @project.update!(location: locations(:burbank))
    stub_count({ "swlat" => locations(:burbank).south.to_s }, 236)
    stub_count({ "project_id" => "303327",
                 "swlat" => locations(:burbank).south.to_s }, 47)

    counts = counts_for(remote_project_id: "303327", use_constraints: true)

    assert_equal(47, counts.combined)
  end

  # Unfollowed constraints still get counted, since that number is what
  # says whether following them is worth doing.
  def test_constraints_are_counted_whether_followed_or_not
    @project.update!(location: locations(:burbank))
    stub_count({ "project_id" => "303327" }, 338)
    stub_count({ "swlat" => locations(:burbank).south.to_s }, 236)

    counts = counts_for(remote_project_id: "303327")

    assert_equal(236, counts.constraints)
    assert_equal(338, counts.combined)
  end

  def test_inat_not_answering_is_no_number_rather_than_a_wrong_one
    stub_request(:get, %r{#{Inat::Constants::API_BASE}/observations}o).
      to_return(status: 500)

    assert_nil(counts_for(remote_project_id: "303327").combined)
  end
end

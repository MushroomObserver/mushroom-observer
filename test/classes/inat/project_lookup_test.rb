# frozen_string_literal: true

require("test_helper")

# Resolving whatever an admin types for a sister iNat project into the
# one project it names (#5416).
class Inat::ProjectLookupTest < UnitTestCase
  include InatStubHelpers

  YOOP = { id: 303_327, title: "2026 NAMA Yoop",
           slug: "2026-nama-yoop" }.freeze

  def stub_project(path, results)
    stub_request(:get, "#{Inat::Constants::API_BASE}/#{path}").
      with(headers: { "Accept" => "application/json",
                      "User-Agent" => user_agent }).
      to_return(status: 200, body: { results: results }.to_json)
  end

  def assert_resolves_to_yoop(input)
    found = Inat::ProjectLookup.new(input).resolve

    assert_not_nil(found, "#{input.inspect} should name a project")
    assert_equal("303327", found.id)
    assert_equal("2026 NAMA Yoop", found.title)
  end

  def test_a_bare_id
    stub_project("projects/303327", [YOOP])

    assert_resolves_to_yoop("303327")
  end

  def test_a_bare_slug
    stub_project("projects/2026-nama-yoop", [YOOP])

    assert_resolves_to_yoop("2026-nama-yoop")
  end

  # The address iNat's own project page has, which carries the slug and
  # no id at all.
  def test_a_project_page_url
    stub_project("projects/2026-nama-yoop", [YOOP])

    assert_resolves_to_yoop(
      "https://www.inaturalist.org/projects/2026-nama-yoop?tab=observations"
    )
  end

  def test_an_observation_search_url
    stub_project("projects/303327", [YOOP])

    assert_resolves_to_yoop(
      "https://www.inaturalist.org/observations?project_id=303327"
    )
  end

  def test_a_name_that_one_project_answers_to
    stub_project("projects?q=2026%20NAMA%20Yoop&per_page=10", [YOOP])

    assert_resolves_to_yoop("2026 NAMA Yoop")
  end

  # Several matches resolve only when one is titled what was typed.
  def test_a_name_matching_one_of_several_exactly
    others = [{ id: 1, title: "2026 NAMA Yoop Fungi" }, YOOP]
    stub_project("projects?q=2026%20NAMA%20Yoop&per_page=10", others)

    assert_resolves_to_yoop("2026 NAMA Yoop")
  end

  # A single word reads as a slug first; when iNat does not answer
  # to it, the search runs and turns up more than one project.
  def test_an_ambiguous_name
    results = [{ id: 1, title: "Yoop North" },
               { id: 2, title: "Yoop South" }]
    stub_project("projects/Yoop", [])
    stub_project("projects?q=Yoop&per_page=10", results)
    lookup = Inat::ProjectLookup.new("Yoop")

    assert_nil(lookup.resolve)
    assert_equal(:project_site_inat_project_ambiguous, lookup.error)
  end

  # A slug iNat does not answer to falls through to the search, which
  # also finds nothing.
  def test_an_unknown_slug
    stub_project("projects/nope", [])
    stub_project("projects?q=nope&per_page=10", [])
    lookup = Inat::ProjectLookup.new("nope")

    assert_nil(lookup.resolve)
    assert_equal(:project_site_inat_project_unknown, lookup.error)
  end

  def test_blank_input_asks_inat_nothing
    assert_nil(Inat::ProjectLookup.new("  ").resolve)
  end

  # iNat being down is an answer of "not found", not a 500 for the admin.
  def test_a_failed_request
    stub_request(:get, %r{#{Inat::Constants::API_BASE}/projects}o).
      to_return(status: 500)
    lookup = Inat::ProjectLookup.new("303327")

    assert_nil(lookup.resolve)
    assert_equal(:project_site_inat_project_unknown, lookup.error)
  end

  def test_the_lookup_counts_against_inats_request_limit
    stub_project("projects/303327", [YOOP])
    Inat::ProjectLookup.new("303327").resolve

    assert_equal(1, ExternalSiteUsage.requests_since(
                      external_sites(:inaturalist), 1.hour
                    ))
  end
end

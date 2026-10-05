# frozen_string_literal: true

require("test_helper")

# The iNat observation search one project's configuration describes
# (#5416), which the candidate count and a project admin's import both
# read.
class Inat::ProjectSearchTest < UnitTestCase
  include InatStubHelpers

  def setup
    super
    @project = projects(:eol_project)
    @site = external_sites(:inaturalist)
  end

  def search(**args)
    Inat::ProjectSearch.new(
      ProjectExternalSite.new(project: @project, external_site: @site, **args)
    )
  end

  # An import takes its scope as a URL, and only an observation search
  # is one. A `/projects/<id>` or `/projects/<slug>` address is the
  # sister project's page: Inat::URLNormalizer refuses it, so an import
  # built on it would be turned away rather than run.
  def test_the_url_is_an_observation_search_by_numeric_project_id
    url = search(remote_project_id: "102213").url

    assert_equal("https://www.inaturalist.org/observations",
                 url.split("?").first)
    assert_includes(url, "project_id=102213")
    assert_not_nil(Inat::URLNormalizer.new(url, keep_taxon_id: true).normalize,
                   "The import form has to accept the URL it is given")
  end

  # Whatever else is set, MO imports fungi and slime moulds.
  def test_the_search_is_filtered_to_importable_taxa
    assert_includes(search(remote_project_id: "102213").url,
                    CGI.escape(Inat::Constants::IMPORTABLE_TAXON_IDS_ARG))
  end

  def test_the_constraints_narrow_the_search
    @project.update!(location: locations(:burbank))
    stub_request(:get, inat_api_matcher("places")).
      to_return(status: 200, body: { results: [] }.to_json)

    url = search(remote_project_id: "102213", use_constraints: true).url

    assert_includes(url, "project_id=102213")
    assert_includes(url, "swlat=#{locations(:burbank).south}")
  end

  # An unfollowed constraint is not part of the search.
  def test_unfollowed_constraints_do_not_narrow
    @project.update!(location: locations(:burbank))

    assert_not_includes(search(remote_project_id: "102213").url, "swlat")
  end

  # ---- whether the targets resolved ------------------------------------

  def test_a_project_without_constraints_has_nothing_to_resolve
    assert(search(remote_project_id: "102213").targets_resolved?)
  end

  def test_targets_that_resolve_are_reported_as_resolved
    rare = projects(:rare_fungi_project)
    stub_resolved(rare)

    assert(Inat::ProjectSearch.new(
      ProjectExternalSite.new(project: rare, external_site: @site,
                              use_constraints: true)
    ).targets_resolved?)
  end

  # Names iNat does not know are left out of the search, which would
  # widen it to every fungus in the project's area and dates.
  def test_targets_that_resolve_to_nothing_are_reported_with_their_names
    rare = projects(:rare_fungi_project)
    stub_request(:get, inat_api_matcher("taxa")).
      to_return(status: 200, body: { results: [] }.to_json)
    search = Inat::ProjectSearch.new(
      ProjectExternalSite.new(project: rare, external_site: @site,
                              use_constraints: true)
    )

    assert_not(search.targets_resolved?)
    assert_equal(rare.target_names.map(&:text_name).sort,
                 search.unresolved_names.sort)
  end

  def stub_resolved(project)
    project.target_names.each_with_index do |name, i|
      stub_request(:get, inat_api_matcher("taxa")).
        with(query: hash_including("q" => name.text_name)).
        to_return(status: 200,
                  body: { results: [{ "id" => 9001 + i,
                                      "name" => name.text_name }] }.to_json)
    end
  end
end

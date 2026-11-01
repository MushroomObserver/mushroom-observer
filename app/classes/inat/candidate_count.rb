# frozen_string_literal: true

class Inat
  # How many iNat observations a project's saved configuration would
  # bring in (#5416), counted without importing anything.
  #
  # One number, for the configuration as stored: the sister project
  # narrowed by the project's constraints when it follows them, or
  # whichever of the two is set. It excludes what MO already holds,
  # using the same "Mushroom Observer URL" field filter the importer
  # uses, so the number is what is left to import rather than what
  # exists.
  #
  # A configuration that sets neither shape has no number, since the
  # search would be every fungus on iNat; the page says so instead.
  #
  # Counts are cached briefly: a page reloaded twice should not ask
  # iNat twice, and nothing here needs to be accurate to the minute.
  class CandidateCount
    include Inat::Constants
    include Inat::JsonFetch

    CACHE_TTL = 10.minutes

    # total is nil when iNat could not answer, so the page can show
    # nothing rather than a wrong number. The unresolved lists are what
    # the constraints asked for and iNat does not know: left out of the
    # search rather than guessed at, and named on the page so an admin
    # can see why a number is bigger than the project means.
    Candidates = Data.define(:configured, :total, :unresolved_names,
                             :unresolved_locations)

    def self.for(project_site:)
      new(project_site).candidates
    end

    def initialize(project_site)
      @project_site = project_site
      @search = Inat::ProjectSearch.new(project_site)
      @mapper = @search.mapper
    end

    def candidates
      return unconfigured unless @project_site.configured?

      # The mapper fills its unresolved lists while the search is
      # built, so they are read after the count, not before.
      total = count
      Candidates.new(configured: true, total: total,
                     unresolved_names: @mapper.unresolved_names,
                     unresolved_locations: @mapper.unresolved_locations)
    end

    private

    def unconfigured
      Candidates.new(configured: false, total: nil, unresolved_names: [],
                     unresolved_locations: [])
    end

    def search_params = @search.params

    def count
      query = search_params.merge(BASE_FILTER_PARAMS).
              merge(only_id: true, per_page: 1).to_query
      Rails.cache.fetch(["inat_candidate_count", query],
                        expires_in: CACHE_TTL) do
        fetch_json("observations?#{query}")&.dig("total_results")
      end
    end
  end
end

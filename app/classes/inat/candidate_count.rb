# frozen_string_literal: true

class Inat
  # How many iNat observations a project's configuration would bring in
  # (#5416), counted without importing anything.
  #
  # Two numbers, because the page asks two questions: how many meet the
  # project's constraints, and how many the configured sister project
  # offers -- narrowed by those constraints when the project follows
  # them. Both exclude what MO already holds, using the same
  # "Mushroom Observer URL" field filter the importer uses, so a number
  # is what is left to import rather than what exists.
  #
  # Counts are cached briefly: a page reloaded twice should not ask iNat
  # twice, and nothing here needs to be accurate to the minute.
  class CandidateCount
    include Inat::Constants
    include Inat::JsonFetch

    CACHE_TTL = 10.minutes

    Counts = Data.define(:constraints, :combined)

    def self.for(project:, project_site:)
      new(project, project_site).counts
    end

    def initialize(project, project_site)
      @project = project
      @project_site = project_site
      @mapper = Inat::ConstraintMapper.new(project)
    end

    # Either number is nil when it has nothing to count or when iNat
    # could not answer; the page then shows no number rather than a
    # wrong one.
    def counts
      Counts.new(constraints: constraints_count, combined: combined_count)
    end

    private

    def constraints_count
      return nil unless @project.constraints?

      count(constraint_params)
    end

    def combined_count
      return nil if @project_site.remote_project_id.blank?

      params = { project_id: @project_site.remote_project_id }
      params = constraint_params.merge(params) if
        @project_site.use_constraints?
      count(params)
    end

    def constraint_params
      @constraint_params ||= @mapper.params.presence ||
                             { taxon_id: IMPORTABLE_TAXON_IDS_ARG }
    end

    def count(params)
      query = params.merge(BASE_FILTER_PARAMS).
              merge(only_id: true, per_page: 1).to_query
      Rails.cache.fetch(["inat_candidate_count", query],
                        expires_in: CACHE_TTL) do
        fetch_json("observations?#{query}")&.dig("total_results")
      end
    end
  end
end

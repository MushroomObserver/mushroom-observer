# frozen_string_literal: true

class Inat
  # The iNat observation search one project's configuration describes
  # (#5416): its sister collection there, narrowed by whichever of the
  # project's constraints it follows.
  #
  # The candidate count on the External Sites tab and the import a
  # project admin starts both read this, so the number an admin is
  # shown and the observations an import brings in answer one question.
  class ProjectSearch
    include Inat::Constants

    attr_reader :mapper

    def initialize(project_site)
      @project_site = project_site
      @mapper = Inat::ConstraintMapper.new(project_site.project)
    end

    def params
      params = {}
      params.merge!(@mapper.params) if @project_site.use_constraints?
      if @project_site.remote_project_id.present?
        params[:project_id] = @project_site.remote_project_id
      end
      # Whatever else is set, MO imports fungi and slime moulds.
      params[:taxon_id] ||= IMPORTABLE_TAXON_IDS_ARG
      params
    end

    # The search as a page a person can open, which is also the form an
    # import takes it in.
    #
    # An observation search carrying the numeric project id, not
    # `ProjectExternalSite#remote_url`: a `/projects/<id>` or
    # `/projects/<slug>` address is the sister project's page rather
    # than a search, and `Inat::URLNormalizer` accepts only
    # `/observations`. The id is what MO stores, whatever shape the
    # admin typed (`Inat::ProjectLookup`).
    def url
      "#{SITE}/observations?#{params.to_query}"
    end

    # Target names iNat does not know are left out of the search rather
    # than guessed at, so a project none of whose names resolve searches
    # for every fungus in its area and dates. That is a count worth
    # reading and an import worth refusing, which is why this is asked
    # separately from the params.
    def targets_resolved?
      return true unless @project_site.use_constraints?
      return true unless @project_site.project.target_names_present?

      @mapper.target_taxon_ids.any?
    end

    def unresolved_names
      @mapper.target_taxon_ids
      @mapper.unresolved_names
    end
  end
end

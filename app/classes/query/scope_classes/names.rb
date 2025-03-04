# frozen_string_literal: true

# base class for Queries which return Names
class Query::ScopeClasses::Names < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::ScopeInitializers::Names
  include Query::ScopeInitializers::AdvancedSearch
  include Query::ScopeInitializers::Filters
  include Query::Titles::Observations

  def model
    Name
  end

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Name],
      names: [Name],
      include_synonyms: :boolean,
      include_subtaxa: :boolean,
      include_immediate_subtaxa: :boolean,
      exclude_original_names: :boolean,
      by_users: [User],
      by_editor: User,
      locations: [Location],
      species_lists: [SpeciesList],
      misspellings: { string: [:no, :either, :only] },
      deprecated: { string: [:either, :no, :only] },
      is_deprecated: :boolean, # api param
      has_synonyms: :boolean,
      rank: [{ string: Name.all_ranks }],
      text_name_has: :string,
      has_author: :boolean,
      author_has: :string,
      has_citation: :boolean,
      citation_has: :string,
      has_classification: :boolean,
      classification_has: :string,
      has_notes: :boolean,
      notes_has: :string,
      has_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      need_description: :boolean,
      has_descriptions: :boolean,
      has_default_desc: :boolean,
      ok_for_export: :boolean,
      has_observations: { boolean: [true] },
      description_query: { subquery: :NameDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Name)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_names_has_descriptions
    initialize_names_has_observations
    initialize_names_only_parameters
    initialize_taxonomy_parameters
    initialize_name_record_parameters
    initialize_name_search_parameters
    initialize_content_filters(Name)
    super
  end

  def initialize_names_only_parameters
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions
    add_by_editor_condition
    initialize_name_comments_and_notes_parameters
    initialize_name_parameters_for_name_queries
    add_pattern_condition
    add_need_description_condition
    add_has_default_description_condition
    add_name_advanced_search_conditions
    initialize_subquery_parameters
    initialize_name_association_parameters
  end

  def initialize_name_comments_and_notes_parameters
    initialize_name_notes_parameters
    initialize_name_comments_parameters
  end

  def initialize_name_notes_parameters
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.notes,'')) > 0",
    #   "LENGTH(COALESCE(names.notes,'')) = 0",
    #   params[:with_notes]
    # )
    add_coalesced_presence_condition(Name[:notes], params[:with_notes])
    add_search_condition(
      # "names.notes",
      Name[:notes],
      params[:notes_has]
    )
  end

  def initialize_name_comments_parameters
    # add_join(:comments) if params[:has_comments]
    @scopes = @scopes.joins(:comments) if params[:has_comments]
    add_search_condition(
      # "CONCAT(comments.summary,COALESCE(comments.comment,''))",
      Comment[:summary] + Comment[:comment].coalesce(""),
      params[:comments_has],
      :comments
    )
  end

  def initialize_taxonomy_parameters
    initialize_misspellings_parameter
    initialize_deprecated_parameter
    add_rank_condition(params[:rank])
    initialize_is_deprecated_parameter
    initialize_ok_for_export_parameter
  end

  def initialize_misspellings_parameter
    val = params[:misspellings] || :no
    # where << "names.correct_spelling_id IS NULL"     if val == :no
    # where << "names.correct_spelling_id IS NOT NULL" if val == :only
    @scopes = @scopes.with_correct_spelling if val == :no
    @scopes = @scopes.with_incorrect_spelling if val == :only
  end

  # Not sure how these two are different!
  def initialize_deprecated_parameter
    val = params[:deprecated] || :either
    # where << "names.deprecated IS FALSE" if val == :no
    # where << "names.deprecated IS TRUE"  if val == :only
    @scopes = @scopes.not_deprecated if val == :no
    @scopes = @scopes.deprecated if val == :only
  end

  def initialize_is_deprecated_parameter
    # "names.deprecated IS TRUE", "names.deprecated IS FALSE",
    add_boolean_column_condition(Name[:deprecated], params[:is_deprecated])
  end

  def add_rank_condition(vals, joins)
    return if vals.to_s.empty?

    min, max = vals
    # max ||= min
    # all_ranks = Name.all_ranks
    # a = all_ranks.index(min) || 0
    # b = all_ranks.index(max) || (all_ranks.length - 1)
    # a, b = b, a if a > b
    # ranks = all_ranks[a..b].map { |r| Name.ranks[r] }
    # @where << "names.`rank` IN (#{ranks.join(",")})"
    @scopes = @scopes.rank(min, max)
    @scopes = @scopes.joins(**joins) if joins
  end

  def initialize_name_association_parameters
    add_association_condition(
      Observation[:id], params[:observations], :observations
    )
    add_observation_location_condition(
      Observation, params[:locations], :observations
    )
    initialize_species_lists_parameter
  end

  def initialize_name_record_parameters
    initialize_with_synonyms_parameter
    initialize_with_author_parameter
    initialize_with_citation_parameter
    initialize_with_classification_parameter
    @scopes = @scopes.joins(:observations) if params[:with_observations]
  end

  def initialize_with_synonyms_parameter
    add_boolean_condition(
      # "names.synonym_id IS NOT NULL", "names.synonym_id IS NULL",
      Name[:synonym_id].not_eq(nil), Name[:synonym_id].eq(nil),
      params[:with_synonyms]
    )
  end

  def initialize_with_author_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.author,'')) > 0",
    #   "LENGTH(COALESCE(names.author,'')) = 0",
    #   params[:with_author]
    # )
    add_coalesced_presence_condition(Name[:author], params[:with_author])
  end

  def initialize_with_citation_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.citation,'')) > 0",
    #   "LENGTH(COALESCE(names.citation,'')) = 0",
    #   params[:with_citation]
    # )
    add_coalesced_presence_condition(Name[:citation], params[:with_citation])
  end

  def initialize_with_classification_parameter
    # add_boolean_condition(
    #   "LENGTH(COALESCE(names.classification,'')) > 0",
    #   "LENGTH(COALESCE(names.classification,'')) = 0",
    #   params[:with_classification]
    # )
    add_coalesced_presence_condition(
      Name[:classification], params[:with_classification]
    )
  end

  def initialize_name_search_parameters
    add_search_condition(Name[:text_name], params[:text_name_has])
    add_search_condition(Name[:author], params[:author_has])
    add_search_condition(Name[:citation], params[:citation_has])
    add_search_condition(Name[:classification], params[:classification_has])
  end

  def add_name_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join_to_observations if params[:content].present?
    initialize_advanced_search
  end
end

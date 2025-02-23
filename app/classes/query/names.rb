# frozen_string_literal: true

# base class for Query's which return Names
class Query::Names < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  include Query::Initializers::Names
  include Query::Initializers::AdvancedSearch
  include Query::Initializers::Filters
  include Query::Titles::Observations

  def model
    Name
  end

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [Name],
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
    add_ids_condition
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
    add_boolean_condition(
      "LENGTH(COALESCE(names.notes,'')) > 0",
      "LENGTH(COALESCE(names.notes,'')) = 0",
      params[:has_notes]
    )
    add_join(:comments) if params[:has_comments]
    add_search_condition(
      "names.notes",
      params[:notes_has]
    )
    add_search_condition(
      "CONCAT(comments.summary,COALESCE(comments.comment,''))",
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
    where << "names.correct_spelling_id IS NULL"     if val == :no
    where << "names.correct_spelling_id IS NOT NULL" if val == :only
  end

  # Not sure how these two are different!
  def initialize_deprecated_parameter
    val = params[:deprecated] || :either
    where << "names.deprecated IS FALSE" if val == :no
    where << "names.deprecated IS TRUE"  if val == :only
  end

  def initialize_is_deprecated_parameter
    add_boolean_condition(
      "names.deprecated IS TRUE", "names.deprecated IS FALSE",
      params[:is_deprecated]
    )
  end

  def add_rank_condition(vals, *)
    return if vals.empty?

    ranks = parse_rank_parameter(vals)
    @where << "names.`rank` IN (#{ranks.join(",")})"
    add_joins(*)
  end

  def parse_rank_parameter(vals)
    min, max = vals
    max ||= min
    all_ranks = Name.all_ranks
    a = all_ranks.index(min) || 0
    b = all_ranks.index(max) || (all_ranks.length - 1)
    a, b = b, a if a > b
    all_ranks[a..b].map { |r| Name.ranks[r] }
  end

  def initialize_name_association_parameters
    add_id_condition("observations.id", params[:observations], :observations)
    initialize_locations_parameter(
      :observations, params[:locations], :observations
    )
    initialize_species_lists_parameter
  end

  def initialize_name_record_parameters
    initialize_has_synonyms_parameter
    initialize_has_author_parameter
    initialize_has_citation_parameter
    initialize_has_classification_parameter
    add_join(:observations) if params[:has_observations]
  end

  def initialize_has_synonyms_parameter
    add_boolean_condition(
      "names.synonym_id IS NOT NULL", "names.synonym_id IS NULL",
      params[:has_synonyms]
    )
  end

  def initialize_has_author_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.author,'')) > 0",
      "LENGTH(COALESCE(names.author,'')) = 0",
      params[:has_author]
    )
  end

  def initialize_has_citation_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.citation,'')) > 0",
      "LENGTH(COALESCE(names.citation,'')) = 0",
      params[:has_citation]
    )
  end

  def initialize_has_classification_parameter
    add_boolean_condition(
      "LENGTH(COALESCE(names.classification,'')) > 0",
      "LENGTH(COALESCE(names.classification,'')) = 0",
      params[:has_classification]
    )
  end

  def initialize_name_search_parameters
    add_search_condition("names.text_name", params[:text_name_has])
    add_search_condition("names.author", params[:author_has])
    add_search_condition("names.citation", params[:citation_has])
    add_search_condition("names.classification", params[:classification_has])
  end

  def add_name_advanced_search_conditions
    return if advanced_search_params.all? { |key| params[key].blank? }

    add_join(:observations) if params[:search_content].present?
    initialize_advanced_search
  end

  def initialize_subquery_parameters
    add_subquery_condition(:description_query, :name_descriptions)
    add_subquery_condition(:observation_query, :observations)
  end

  def initialize_names_has_descriptions
    return if params[:has_descriptions].blank?

    add_join(:name_descriptions)
  end

  def initialize_names_has_observations
    return if params[:has_observations].blank?

    add_join(:observations)
  end

  def add_need_description_condition
    return unless params[:need_description]

    add_join(:observations)
    @where << "names.description_id IS NULL"
    @title_tag = :query_title_needs_description.t(type: :name)
  end

  def add_has_default_description_condition
    add_boolean_condition(
      "names.description_id IS NOT NULL",
      "names.description_id IS NULL",
      params[:has_default_desc]
    )
  end

  def add_pattern_condition
    return if params[:pattern].blank?

    add_join(:"name_descriptions.default!")
    super
  end

  def add_join_to_names; end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations
    add_join(:observations, :locations!)
  end

  def content_join_spec
    { observations: :comments }
  end

  def search_fields
    fields = [
      "names.search_name",
      "COALESCE(names.citation,'')",
      "COALESCE(names.notes,'')"
    ] + NameDescription.all_note_fields.map do |x|
      "COALESCE(name_descriptions.#{x},'')"
    end
    "CONCAT(#{fields.join(",")})"
  end

  def self.default_order
    "name"
  end

  def title
    default = super
    if params[:has_observations] || params[:observation_query]
      with_observations_query_description || default
    elsif params[:has_descriptions] || params[:description_query]
      :query_title_with_descriptions.t(type: :name) || default
    else
      default
    end
  end
end

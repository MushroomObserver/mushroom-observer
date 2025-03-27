# frozen_string_literal: true

# base class for Query's which return Names
class Query::Names < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters
  # include Query::Initializers::AdvancedSearch
  # include Query::Initializers::Filters

  def model
    @model ||= Name
  end

  def list_by
    @list_by ||= Name[:sort_name]
  end

  def self.parameter_declarations # rubocop:disable Metrics/MethodLength
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Name],
      by_users: [User],
      by_editor: User,
      names: { lookup: [Name],
               include_synonyms: :boolean,
               include_subtaxa: :boolean,
               include_immediate_subtaxa: :boolean,
               exclude_original_names: :boolean },
      text_name_has: :string,
      # clade: :string, # content_filter
      # lichen: :boolean, # content_filter
      misspellings: { string: [:no, :either, :only] },
      deprecated: :boolean,
      has_synonyms: :boolean,
      ok_for_export: :boolean,
      has_author: :boolean,
      author_has: :string,
      has_citation: :boolean,
      citation_has: :string,
      has_classification: :boolean,
      classification_has: :string,
      has_notes: :boolean,
      notes_has: :string,
      rank: [{ string: Name.all_ranks }],
      has_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      locations: [Location],
      species_lists: [SpeciesList],
      needs_description: :boolean,
      has_descriptions: :boolean,
      has_default_description: :boolean,
      has_observations: { boolean: [true] },
      description_query: { subquery: :NameDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Name)).
      merge(advanced_search_parameter_declarations)
  end

  def self.default_order
    "name"
  end

  # def initialize_flavor
  #   initialize_name_basic_parameters
  #   initialize_name_record_parameters
  #   initialize_subquery_parameters
  #   initialize_name_association_parameters
  #   initialize_content_filters(Name)
  #   super
  # end

  # def initialize_name_basic_parameters
  #   add_id_in_set_condition
  #   add_owner_and_time_stamp_conditions
  #   add_by_editor_condition
  # end

  # def initialize_name_record_parameters
  #   initialize_related_names_parameters
  #   initialize_name_column_search_parameters
  #   initialize_has_synonyms_parameter
  #   initialize_has_author_parameter
  #   initialize_has_citation_parameter
  #   initialize_has_classification_parameter
  #   initialize_taxonomy_parameters
  #   initialize_name_notes_parameters
  #   add_pattern_condition
  #   add_name_advanced_search_conditions
  # end

  # # Much simpler form for non-observation-based name queries.
  # def initialize_related_names_parameters
  #   names = params.dig(:names, :lookup)
  #   return if names.blank?

  #   ids = lookup_names_by_name(names, related_names_parameters)
  #   return force_empty_results if ids.blank?

  #   add_association_condition("names.id", ids)
  # end

  # NAMES_EXPANDER_PARAMS = [
  #   :include_synonyms, :include_subtaxa, :include_immediate_subtaxa,
  #   :exclude_original_names
  # ].freeze

  # def related_names_parameters
  #   return {} unless params[:names]

  #   params[:names].dup.slice(*NAMES_EXPANDER_PARAMS).compact
  # end

  # def initialize_name_column_search_parameters
  #   add_search_condition("names.text_name", params[:text_name_has])
  #   add_search_condition("names.author", params[:author_has])
  #   add_search_condition("names.citation", params[:citation_has])
  #   add_search_condition("names.classification", params[:classification_has])
  # end

  # def initialize_has_synonyms_parameter
  #   add_boolean_condition(
  #     "names.synonym_id IS NOT NULL", "names.synonym_id IS NULL",
  #     params[:has_synonyms]
  #   )
  # end

  # def initialize_has_author_parameter
  #   add_boolean_condition(
  #     "LENGTH(COALESCE(names.author,'')) > 0",
  #     "LENGTH(COALESCE(names.author,'')) = 0",
  #     params[:has_author]
  #   )
  # end

  # def initialize_has_citation_parameter
  #   add_boolean_condition(
  #     "LENGTH(COALESCE(names.citation,'')) > 0",
  #     "LENGTH(COALESCE(names.citation,'')) = 0",
  #     params[:has_citation]
  #   )
  # end

  # def initialize_has_classification_parameter
  #   add_boolean_condition(
  #     "LENGTH(COALESCE(names.classification,'')) > 0",
  #     "LENGTH(COALESCE(names.classification,'')) = 0",
  #     params[:has_classification]
  #   )
  # end

  # def initialize_name_notes_parameters
  #   add_boolean_condition(
  #     "LENGTH(COALESCE(names.notes,'')) > 0",
  #     "LENGTH(COALESCE(names.notes,'')) = 0",
  #     params[:has_notes]
  #   )
  # end

  # def initialize_name_comments_parameters
  #   add_join(:comments) if params[:has_comments]
  #   add_search_condition("names.notes", params[:notes_has])
  #   add_search_condition(
  #     "CONCAT(comments.summary,COALESCE(comments.comment,''))",
  #     params[:comments_has],
  #     :comments
  #   )
  # end

  # def initialize_taxonomy_parameters
  #   initialize_misspellings_parameter
  #   initialize_is_deprecated_parameter
  #   add_rank_condition(params[:rank])
  #   initialize_ok_for_export_parameter
  # end

  # def initialize_misspellings_parameter
  #   val = params[:misspellings] || :no
  #   @where << "names.correct_spelling_id IS NULL"     if val == :no
  #   @where << "names.correct_spelling_id IS NOT NULL" if val == :only
  # end

  # def initialize_is_deprecated_parameter
  #   add_boolean_condition(
  #     "names.deprecated IS TRUE", "names.deprecated IS FALSE",
  #     params[:deprecated]
  #   )
  # end

  # def add_rank_condition(vals, *)
  #   return if vals.empty?

  #   ranks = parse_rank_parameter(vals)
  #   @where << "names.`rank` IN (#{ranks.join(",")})"
  #   add_joins(*)
  # end

  # def parse_rank_parameter(vals)
  #   min, max = vals
  #   max ||= min
  #   all_ranks = Name.all_ranks
  #   a = all_ranks.index(min) || 0
  #   b = all_ranks.index(max) || (all_ranks.length - 1)
  #   a, b = b, a if a > b
  #   all_ranks[a..b].map { |r| Name.ranks[r] }
  # end

  # def initialize_name_association_parameters
  #   initialize_name_comments_parameters
  #   add_needs_description_condition
  #   add_has_default_description_condition
  #   initialize_names_has_descriptions
  #   initialize_names_has_observations
  #   add_association_condition(
  #     "observations.id", params[:observations], :observations
  #   )
  #   initialize_locations_parameter(
  #     :observations, params[:locations], :observations
  #   )
  #   initialize_species_lists_parameter
  # end

  # def add_name_advanced_search_conditions
  #   return if advanced_search_params.all? { |key| params[key].blank? }

  #   add_join(:observations) if params[:search_content].present?
  #   initialize_advanced_search
  # end

  # def initialize_subquery_parameters
  #   add_subquery_condition(:description_query, :name_descriptions)
  #   add_subquery_condition(:observation_query, :observations)
  # end

  # def initialize_names_has_descriptions
  #   return if params[:has_descriptions].blank?

  #   add_join(:name_descriptions)
  # end

  # def initialize_names_has_observations
  #   return if params[:has_observations].blank?

  #   add_join(:observations)
  # end

  # def add_needs_description_condition
  #   return unless params[:needs_description]

  #   add_join(:observations)
  #   @where << "names.description_id IS NULL"
  #   @selects = "DISTINCT names.id, count(observations.name_id)"
  #   @group = "observations.name_id"
  #   @order = "count(observations.name_id) DESC"
  # end

  # def add_has_default_description_condition
  #   add_boolean_condition(
  #     "names.description_id IS NOT NULL",
  #     "names.description_id IS NULL",
  #     params[:has_default_description]
  #   )
  # end

  # def add_pattern_condition
  #   return if params[:pattern].blank?

  #   add_join(:"name_descriptions.default!")
  #   super
  # end

  # def add_join_to_names; end

  # def add_join_to_users
  #   add_join(:observations, :users)
  # end

  # def add_join_to_locations
  #   add_join(:observations, :locations!)
  # end

  # def content_join_spec
  #   { observations: :comments }
  # end

  # def search_fields
  #   fields = [
  #     "names.search_name",
  #     "COALESCE(names.citation,'')",
  #     "COALESCE(names.notes,'')"
  #   ] + NameDescription.all_note_fields.map do |x|
  #     "COALESCE(name_descriptions.#{x},'')"
  #   end
  #   "CONCAT(#{fields.join(",")})"
  # end
end

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
      by_user: User,
      by_editor: User,
      users: [User],
      locations: [Location],
      species_lists: [SpeciesList],
      misspellings: { string: [:no, :either, :only] },
      deprecated: { string: [:either, :no, :only] },
      is_deprecated: :boolean, # api param
      with_synonyms: :boolean,
      rank: [{ string: Name.all_ranks }],
      text_name_has: :string,
      with_author: :boolean,
      author_has: :string,
      with_citation: :boolean,
      citation_has: :string,
      with_classification: :boolean,
      classification_has: :string,
      with_notes: :boolean,
      notes_has: :string,
      with_comments: { boolean: [true] },
      comments_has: :string,
      pattern: :string,
      need_description: :boolean,
      with_descriptions: :boolean,
      with_default_desc: :boolean,
      ok_for_export: :boolean,
      with_observations: { boolean: [true] },
      description_query: { subquery: :NameDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Name)).
      merge(advanced_search_parameter_declarations)
  end

  def initialize_flavor
    add_sort_order_to_title
    initialize_names_with_descriptions
    initialize_names_with_observations
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
    add_by_user_condition
    add_by_editor_condition
    initialize_name_comments_and_notes_parameters
    initialize_name_parameters_for_name_queries
    add_pattern_condition
    add_need_description_condition
    add_with_default_description_condition
    add_name_advanced_search_conditions
    initialize_subquery_parameters
    initialize_name_association_parameters
  end

  def initialize_subquery_parameters
    add_subquery_condition(:description_query, :name_descriptions)
    add_subquery_condition(:observation_query, :observations)
  end

  def initialize_names_with_descriptions
    return if params[:with_descriptions].blank?

    add_join(:name_descriptions)
  end

  def initialize_names_with_observations
    return if params[:with_observations].blank?

    add_join(:observations)
  end

  def add_need_description_condition
    return unless params[:need_description]

    add_join(:observations)
    @where << "names.description_id IS NULL"
    @title_tag = :query_title_needs_description.t(type: :name)
  end

  def add_with_default_description_condition
    add_boolean_condition(
      "names.description_id IS NOT NULL",
      "names.description_id IS NULL",
      params[:with_default_desc]
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
    if params[:with_observations] || params[:observation_query]
      with_observations_query_description || default
    elsif params[:with_descriptions] || params[:description_query]
      :query_title_with_descriptions.t(type: :name) || default
    else
      default
    end
  end
end

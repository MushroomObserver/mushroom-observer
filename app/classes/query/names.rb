# frozen_string_literal: true

# base class for Query's which return Names
class Query::Names < Query
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  # Commented-out attributes are here so we don't forget they're added
  # via `extra_parameter_declarations` below.
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Name])
  query_attr(:by_users, [User])
  query_attr(:by_editor, User)
  query_attr(:names, { lookup: [Name],
                       include_synonyms: :boolean,
                       include_subtaxa: :boolean,
                       include_immediate_subtaxa: :boolean,
                       exclude_original_names: :boolean })
  query_attr(:text_name_has, :string)
  query_attr(:search_name_has, :string)
  # query_attr(:clade, :string) # content filter
  # query_attr(:lichen, :boolean) # content filter
  query_attr(:misspellings, { string: [:no, :either, :only] })
  query_attr(:deprecated, :boolean)
  query_attr(:has_synonyms, :boolean)
  query_attr(:ok_for_export, :boolean)
  query_attr(:has_author, :boolean)
  query_attr(:author_has, :string)
  query_attr(:has_citation, :boolean)
  query_attr(:citation_has, :string)
  query_attr(:has_classification, :boolean)
  query_attr(:classification_has, :string)
  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:rank, [{ string: Name.all_ranks }])
  query_attr(:has_comments, { boolean: [true] })
  query_attr(:comments_has, :string)
  query_attr(:pattern, :string)
  # query_attr(:search_name, :string) # advanced search
  # query_attr(:search_where, :string) # advanced search
  # query_attr(:search_user, :string) # advanced search
  # query_attr(:search_content, :string) # advanced search
  query_attr(:within_locations, [Location])
  query_attr(:species_lists, [SpeciesList])
  query_attr(:needs_description, :boolean)
  query_attr(:has_descriptions, :boolean)
  query_attr(:has_default_description, :boolean)
  query_attr(:has_observations, { boolean: [true] })
  query_attr(:description_query, { subquery: :NameDescription })
  query_attr(:observation_query, { subquery: :Observation })

  def self.extra_parameter_declarations
    content_filter_parameter_declarations(Name).
      merge(advanced_search_parameter_declarations)
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  extra_parameter_declarations.each do |param_name, accepts|
    query_attr(param_name, accepts)
  end

  def alphabetical_by
    @alphabetical_by ||= Name[:sort_name]
  end

  def self.default_order
    :name
  end
end

# frozen_string_literal: true

class Query::Locations < Query
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  # Commented-out attributes are here so we don't forget they're added
  # via `extra_parameter_declarations` below.
  query_attr(:created_at, [:time])
  query_attr(:updated_at, [:time])
  query_attr(:id_in_set, [Location])
  query_attr(:by_users, [User])
  query_attr(:by_editor, User)
  query_attr(:in_box, { north: :float, south: :float,
                        east: :float, west: :float })
  # query_attr(:region, :string) # content filter
  query_attr(:has_notes, :boolean)
  query_attr(:notes_has, :string)
  query_attr(:pattern, :string)
  query_attr(:regexp, :string)
  # query_attr(:search_name, :string) # advanced search
  # query_attr(:search_where, :string) # advanced search
  # query_attr(:search_user, :string) # advanced search
  # query_attr(:search_content, :string) # advanced search
  query_attr(:has_descriptions, { boolean: [true] })
  query_attr(:has_observations, { boolean: [true] })
  query_attr(:description_query, { subquery: :LocationDescription })
  query_attr(:observation_query, { subquery: :Observation })

  def self.extra_parameter_declarations
    content_filter_parameter_declarations(Location).
      merge(advanced_search_parameter_declarations)
  end

  # Declare filter and advanced search parameters as model attributes,
  # of custom type `query_param`
  extra_parameter_declarations.each do |param_name, accepts|
    query_attr(param_name, accepts)
  end

  def self.default_order
    :name
  end
end

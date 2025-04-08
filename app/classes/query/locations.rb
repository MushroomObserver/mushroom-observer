# frozen_string_literal: true

class Query::Locations < Query::Base
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Location],
      by_users: [User],
      by_editor: User,
      in_box: { north: :float, south: :float, east: :float, west: :float },
      # region: :string, # content filter
      pattern: :string,
      regexp: :string,
      has_notes: :boolean,
      notes_has: :string,
      has_descriptions: :boolean,
      has_observations: :boolean,
      description_query: { subquery: :LocationDescription },
      observation_query: { subquery: :Observation }
    ).merge(content_filter_parameter_declarations(Location)).
      merge(advanced_search_parameter_declarations)
  end

  # Declare the parameters as model attributes, of custom type `query_param`

  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Location
  end

  def self.default_order
    :name
  end
end

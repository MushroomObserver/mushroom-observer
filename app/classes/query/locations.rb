# frozen_string_literal: true

class Query::Locations < Query::BaseAR
  include Query::Params::AdvancedSearch
  include Query::Params::Filters

  def model
    @model ||= Location
  end

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

  def self.default_order
    :name
  end
end

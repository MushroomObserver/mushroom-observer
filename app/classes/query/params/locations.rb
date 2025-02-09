# frozen_string_literal: true

module Query::Params::Locations
  # The basic Location parameters.
  def locations_per_se_parameter_declarations
    {
      created_at: [:time],
      updated_at: [:time],
      ids: [Location],
      by_user: User,
      by_editor: User,
      users: [User],
      in_box: { north: :float, south: :float, east: :float, west: :float },
      pattern: :string,
      regexp: :string,
      with_notes: :boolean,
      notes_has: :string,
      with_descriptions: :boolean,
      with_observations: :boolean,
      descriptions_query: :query,
      names_query: :query,
      observations_query: :query,
      rss_logs_query: :query,
      species_lists_query: :query
    }
  end

  # Used in coerced queries for obs, plus observation queries
  # def bounding_box_parameter_declarations
  #   {
  #     in_box: { north: :float, south: :float, east: :float, west: :float }
  #   }
  # end
end

# frozen_string_literal: true

module Query::Params::Locations
  # The basic Location parameters.
  def locations_per_se_parameter_declarations
    {
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [Location],
      by_user?: User,
      by_editor?: User,
      users?: [User],
      pattern?: :string,
      regexp?: :string,
      with_descriptions?: :boolean,
      with_observations?: :boolean
    }
  end

  # Used in coerced queries for obs, plus observation queries
  def bounding_box_parameter_declarations
    {
      north?: :float,
      south?: :float,
      east?: :float,
      west?: :float
    }
  end
end

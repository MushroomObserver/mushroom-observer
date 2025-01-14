# frozen_string_literal: true

module Query::Params::Images
  def images_per_se_parameter_declarations
    {
      created_at?: [:time],
      updated_at?: [:time],
      date?: [:date],
      ids?: [Image],
      by_user?: User,
      users?: [User],
      locations?: [:string],
      outer?: :query, # for images inside observations
      observation?: Observation, # for images inside observations
      observations?: [Observation],
      project?: Project,
      projects?: [:string],
      species_lists?: [:string],
      with_observation?: { boolean: [true] },
      size?: { string: Image::ALL_SIZES - [:full_size] },
      content_types?: [{ string: Image::ALL_EXTENSIONS }],
      with_notes?: :boolean,
      notes_has?: :string,
      copyright_holder_has?: :string,
      license?: [License],
      with_votes?: :boolean,
      quality?: [:float],
      confidence?: [:float],
      ok_for_export?: :boolean,
      pattern?: :string,
      with_observations?: :boolean
    }
  end
end

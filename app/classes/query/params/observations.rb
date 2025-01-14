# frozen_string_literal: true

module Query::Params::Observations
  def observations_per_se_parameter_declarations
    {
      # dates/times
      date?: [:date],
      created_at?: [:time],
      updated_at?: [:time],

      ids?: [Observation],
      herbarium_records?: [:string],
      project_lists?: [:string],
      by_user?: User,
      by_editor?: User, # for coercions from name/location
      users?: [User],
      field_slips?: [:string],
      pattern?: :string,
      regexp?: :string, # for coercions from location
      needs_naming?: :boolean,
      in_clade?: :string,
      in_region?: :string
    }
  end

  # for observations, or coercions to observations.
  def observations_parameter_declarations
    {
      notes_has?: :string,
      with_notes_fields?: [:string],
      comments_has?: :string,
      herbaria?: [:string],
      user_where?: :string,
      by_user?: User,
      location?: Location,
      locations?: [:string],
      project?: Project,
      projects?: [:string],
      species_list?: SpeciesList,
      species_lists?: [:string],

      # boolean
      with_comments?: { boolean: [true] },
      with_public_lat_lng?: :boolean,
      with_name?: :boolean,
      with_notes?: :boolean,
      with_sequences?: { boolean: [true] },
      is_collection_location?: :boolean,

      # numeric
      confidence?: [:float]
    }
  end

  def observations_coercion_parameter_declarations
    {
      old_title?: :string,
      old_by?: :string,
      date?: [:date],
      obs_ids?: [Observation]
    }
  end
end

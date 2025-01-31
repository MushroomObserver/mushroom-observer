# frozen_string_literal: true

module Query::Params::Observations
  def observations_per_se_parameter_declarations
    {
      # dates/times
      date?: [:date],
      created_at?: [:time],
      updated_at?: [:time],

      ids?: [Observation],
      users?: [User],
      by_user?: User,
      by_editor?: User, # for coercions from name/location
      field_slips?: [:string],
      herbarium_records?: [HerbariumRecord],
      project_lists?: [Project],
      needs_naming?: :boolean,
      in_clade?: :string,
      in_region?: :string,
      pattern?: :string,
      regexp?: :string # for coercions from location
    }
  end

  # for observations, or coercions to observations.
  def observations_parameter_declarations
    {
      with_name?: :boolean,
      confidence?: [:float],
      location?: Location,
      locations?: [Location],
      user_where?: :string,
      is_collection_location?: :boolean,
      with_public_lat_lng?: :boolean,
      by_user?: User,
      with_notes?: :boolean,
      notes_has?: :string,
      with_notes_fields?: [:string],
      with_comments?: { boolean: [true] },
      comments_has?: :string,
      with_sequences?: { boolean: [true] },
      herbaria?: [Herbarium],
      project?: Project,
      projects?: [Project],
      species_list?: SpeciesList,
      species_lists?: [SpeciesList]
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

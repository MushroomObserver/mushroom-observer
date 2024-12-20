module Query
  module Initializers
    # initializing methods inherited by all Query's for Observations
    module Observations
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
    end
  end
end

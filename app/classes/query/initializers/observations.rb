# frozen_string_literal: true

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

      def observations_coercion_parameter_declarations
        {
          old_title?: :string,
          old_by?: :string,
          date?: [:date]
        }
      end

      def params_out_to_with_observations_params(pargs)
        return pargs if pargs[:ids].blank?

        pargs[:obs_ids] = pargs.delete(:ids)
        pargs
      end

      def params_back_to_observation_params
        pargs = params_with_old_by_restored
        return pargs if pargs[:obs_ids].blank?

        pargs[:ids] = pargs.delete(:obs_ids)
        pargs
      end
    end
  end
end

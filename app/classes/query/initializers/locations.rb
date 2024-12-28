# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Locations
    module Locations
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

      def add_regexp_condition
        return if params[:regexp].blank?

        @title_tag = :query_title_regexp_search
        regexp = escape(params[:regexp].to_s.strip_squeeze)
        where << "locations.name REGEXP #{regexp}"
      end
    end
  end
end

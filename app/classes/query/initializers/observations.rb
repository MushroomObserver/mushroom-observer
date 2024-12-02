# frozen_string_literal: true

module Query
  module Initializers
    # initializing methods inherited by all Query's for Observations
    module Observations
      def observations_parameter_declarations
        {
          pattern?: :string,
          ids?: [Observation]
          # user?: [User]
        }
      end
    end
  end
end

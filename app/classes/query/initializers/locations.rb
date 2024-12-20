module Query
  module Initializers
    # initializing methods inherited by all Query's for Locations
    module Locations
      def bounding_box_parameter_declarations
        {
          north?: :float,
          south?: :float,
          east?: :float,
          west?: :float
        }
      end
    end
  end
end

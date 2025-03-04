# frozen_string_literal: true

class API2
  # Bounding box is missing one or more edges.
  class NeedAllFourEdges < FatalError
  end
end

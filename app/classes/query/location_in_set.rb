# frozen_string_literal: true

class Query::LocationInSet < Query::LocationBase
  def parameter_declarations
    super.merge(
      ids: [Location]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

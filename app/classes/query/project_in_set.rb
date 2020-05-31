# frozen_string_literal: true

class Query::ProjectInSet < Query::ProjectBase
  def parameter_declarations
    super.merge(
      ids: [Project]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

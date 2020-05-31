# frozen_string_literal: true

class Query::NameInSet < Query::NameBase
  def parameter_declarations
    super.merge(
      ids: [Name]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

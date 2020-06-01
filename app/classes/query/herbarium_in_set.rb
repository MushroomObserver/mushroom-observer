# frozen_string_literal: true

class Query::HerbariumInSet < Query::HerbariumBase
  def parameter_declarations
    super.merge(
      ids: [Herbarium]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

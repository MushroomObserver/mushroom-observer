# frozen_string_literal: true

class Query::RssLogInSet < Query::RssLogBase
  def parameter_declarations
    super.merge(
      ids: [RssLog]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

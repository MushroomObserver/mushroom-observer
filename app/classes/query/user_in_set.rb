# frozen_string_literal: true

class Query::UserInSet < Query::UserBase
  def parameter_declarations
    super.merge(
      ids: [User]
    )
  end

  def initialize_flavor
    initialize_in_set_flavor
    super
  end
end

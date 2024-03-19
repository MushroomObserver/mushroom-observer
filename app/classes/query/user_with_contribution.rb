# frozen_string_literal: true

class Query::UserWithContribution < Query::UserBase
  def initialize_flavor
    where << "users.contribution > 0"
    super
  end
end

# frozen_string_literal: true

class Query::HerbariumNonpersonal < Query::HerbariumBase
  def initialize_flavor
    where << "herbaria.personal_user_id IS NULL"
    super
  end
end

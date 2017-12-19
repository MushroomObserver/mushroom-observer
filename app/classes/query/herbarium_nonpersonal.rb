module Query
  # Simple herbarium search.
  class HerbariumNonpersonal < Query::HerbariumBase
    def initialize_flavor
      where << "herbaria.personal_user_id IS NULL"
      super
    end
  end
end

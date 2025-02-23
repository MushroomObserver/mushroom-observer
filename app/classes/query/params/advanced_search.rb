# frozen_string_literal: true

module Query::Params::AdvancedSearch
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # NOTE: The autocompleters for name, location, and user all make the ids
    # available now, so this could be a lot more efficient.
    # But sometimes you're looking for strings that aren't ids.
    def advanced_search_parameter_declarations
      {
        search_name: :string,
        search_where: :string,
        search_user: :string,
        search_content: :string,
        search_location_notes: :boolean
      }
    end

    # These are the ones that if present, are definitive of advanced_search.
    def advanced_search_params
      [:search_name, :search_user, :search_where, :search_content]
    end
  end

  def advanced_search_params
    self.class.advanced_search_params
  end
end

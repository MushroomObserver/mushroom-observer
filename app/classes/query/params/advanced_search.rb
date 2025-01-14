# frozen_string_literal: true

module Query::Params::AdvancedSearch
  # NOTE: The autocomplaters for name, location, and user all make the ids
  # available now, so this could be a lot more efficient.
  # But sometimes you're looking for strings that aren't ids.
  def advanced_search_parameter_declarations
    {
      name?: :string,
      user_where?: :string,
      user?: :string,
      content?: :string,
      search_location_notes?: :boolean
    }
  end

  # These are the ones that if present, are definitive of advanced_search.
  def self.advanced_search_params
    [:name, :user, :user_where, :content]
  end

  def advanced_search_params
    [:name, :user, :user_where, :content]
  end
end

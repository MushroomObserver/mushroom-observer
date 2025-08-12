# frozen_string_literal: true

# Non-AR model for the faceted search form. Subclass this for each model
# you want to search, named after the model it's for, eg "Search::Observations"
class Search
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :pattern, :string

  # Returns the type of search (table_name) the subclass filter is for.
  def self.search_type
    name.pluralize.underscore.to_sym
  end
end

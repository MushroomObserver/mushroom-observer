# frozen_string_literal: true

# Non-AR model for the faceted PatternSearch form. Subclass this for each model
# you want to search, named after the model it's for, eg "ObservationFilter"
class SearchFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :pattern, :string

  # Returns the type of search (table_name) the subclass filter is for.
  def self.search_type
    to_s.underscore.gsub("_filter", "").to_sym
  end
end

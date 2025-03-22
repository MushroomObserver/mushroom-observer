# frozen_string_literal: true

class Query::ScopeClasses::APIKeys < Query::BaseAR
  def model
    APIKey
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      notes_has: :string
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_time_condition(:created_at, params[:created_at])
    add_time_condition(:updated_at, params[:updated_at])
    add_simple_search_condition(:notes)
    super
  end

  def self.default_order
    :created_at
  end
end

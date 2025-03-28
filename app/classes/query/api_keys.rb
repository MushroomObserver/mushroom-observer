# frozen_string_literal: true

class Query::APIKeys < Query::Base
  def model
    @model ||= APIKey
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      notes_has: :string
    )
  end

  def initialize_flavor
    add_time_condition("api_keys.created_at", params[:created_at])
    add_time_condition("api_keys.updated_at", params[:updated_at])
    add_search_condition("api_keys.notes", params[:notes_has])
    super
  end

  def self.default_order
    "created_at"
  end
end

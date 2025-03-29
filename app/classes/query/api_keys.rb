# frozen_string_literal: true

class Query::APIKeys < Query::BaseAR
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

  def self.default_order
    :created_at
  end
end

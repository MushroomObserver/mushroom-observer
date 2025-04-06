# frozen_string_literal: true

class Query::APIKeys < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      notes_has: :string
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= APIKey
  end

  def self.default_order
    :created_at
  end
end

# frozen_string_literal: true

class Query::GlossaryTerms < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      by_users: [User],
      name_has: :string,
      description_has: :string,
      pattern: :string
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= GlossaryTerm
  end

  def alphabetical_by
    @alphabetical_by ||= GlossaryTerm[:name]
  end

  def self.default_order
    :name
  end
end

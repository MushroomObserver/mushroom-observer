# frozen_string_literal: true

class Query::CollectionNumbers < Query::Base
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [CollectionNumber],
      collectors: [:string],
      numbers: [:string],
      collector_has: :string,
      number_has: :string,
      by_users: [User],
      observations: [Observation],
      pattern: :string
    )
  end

  # Declare the parameters as model attributes, of custom type `query_param`
  parameter_declarations.each do |param_name, accepts|
    attribute param_name, :query_param, accepts: accepts
  end

  def model
    @model ||= CollectionNumber
  end

  def alphabetical_by
    @alphabetical_by ||= CollectionNumber[:name]
  end

  def self.default_order
    :name_and_number
  end
end

# frozen_string_literal: true

class Query::Herbaria < Query::BaseAM
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Herbarium],
      code_has: :string,
      name_has: :string,
      description_has: :string,
      mailing_address_has: :string,
      pattern: :string,
      nonpersonal: :boolean
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Herbarium
  end

  def alphabetical_by
    @alphabetical_by ||= Herbarium[:name]
  end

  def self.default_order
    :name
  end
end

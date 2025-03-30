# frozen_string_literal: true

class Query::Articles < Query::BaseAM
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [Article],
      title_has: :string,
      body_has: :string,
      by_users: [User]
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= Article
  end

  def alphabetical_by
    @alphabetical_by ||= Article[:title]
  end

  def self.default_order
    :created_at
  end
end

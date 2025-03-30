# frozen_string_literal: true

class Query::LocationDescriptions < Query::BaseAM
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [LocationDescription],
      is_public: :boolean,
      content_has: :string,
      by_users: [User],
      by_author: User,
      by_editor: User,
      locations: [Location],
      location_query: { subquery: :Location }
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= LocationDescription
  end

  def self.default_order
    :name
  end
end

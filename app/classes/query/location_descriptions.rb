# frozen_string_literal: true

class Query::LocationDescriptions < Query::BaseAR
  # include Query::Initializers::Descriptions

  def model
    @model ||= LocationDescription
  end

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

  def self.default_order
    :name
  end
end

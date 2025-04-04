# frozen_string_literal: true

class Query::NameDescriptions < Query::BaseNew
  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      id_in_set: [NameDescription],
      by_users: [User],
      by_author: User,
      by_editor: User,
      is_public: :boolean,
      sources: [{ string: Description::ALL_SOURCE_TYPES }],
      ok_for_export: :boolean,
      content_has: :string,
      names: [Name],
      projects: [Project],
      name_query: { subquery: :Name }
    )
  end

  # Declare the parameters as attributes of type `query_param`
  parameter_declarations.each_key do |param_name|
    attribute param_name, :query_param
  end

  def model
    @model ||= NameDescription
  end

  def self.default_order
    :name
  end
end

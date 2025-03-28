# frozen_string_literal: true

class Query::NameDescriptions < Query::Base
  include Query::Initializers::Descriptions

  def model
    @model ||= NameDescription
  end

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

  def initialize_flavor
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions
    add_desc_by_author_condition(:name)
    add_desc_by_editor_condition(:name)
    ids = lookup_names_by_name(params[:names])
    add_association_condition("name_descriptions.name_id", ids)
    initialize_description_public_parameter(:name)
    initialize_name_descriptions_parameters
    add_subquery_condition(:name_query, :names)
    super
  end

  def self.default_order
    "name"
  end
end

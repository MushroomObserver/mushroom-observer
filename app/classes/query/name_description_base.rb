# frozen_string_literal: true

class Query::NameDescriptionBase < Query::Base
  include Query::Initializers::Descriptions

  def model
    NameDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [NameDescription],
      by_user?: User,
      by_author?: User,
      by_editor?: User,
      old_by?: :string,
      users?: [User],
      names?: [Name],
      public?: :boolean
    )
  end

  def initialize_flavor
    add_ids_condition("name_descriptions")
    add_owner_and_time_stamp_conditions("name_descriptions")
    add_by_user_condition("name_descriptions")
    add_desc_by_author_condition(:name)
    add_desc_by_editor_condition(:name)
    names = lookup_names_by_name(names: params[:names])
    add_id_condition("name_descriptions.name_id", names)
    add_boolean_condition(
      "name_descriptions.public IS TRUE",
      "name_descriptions.public IS FALSE",
      params[:public]
    )
    super
  end

  def self.default_order
    "name"
  end
end

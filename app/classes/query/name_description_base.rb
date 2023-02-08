# frozen_string_literal: true

class Query::NameDescriptionBase < Query::Base
  def model
    NameDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      names?: [Name],
      public?: :boolean
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("name_descriptions")
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

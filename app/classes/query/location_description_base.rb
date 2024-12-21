# frozen_string_literal: true

class Query::LocationDescriptionBase < Query::Base
  include Query::Initializers::Descriptions

  def model
    LocationDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      ids?: [LocationDescription],
      by_user?: User,
      by_author?: User,
      by_editor?: User,
      old_by?: :string,
      users?: [User],
      locations?: [Location],
      public?: :boolean
    )
  end

  def initialize_flavor
    add_ids_condition("location_descriptions")
    add_owner_and_time_stamp_conditions("location_descriptions")
    add_by_user_condition("location_descriptions")
    add_desc_by_author_condition(:location)
    add_desc_by_editor_condition(:location)
    locations = lookup_locations_by_name(params[:locations])
    add_id_condition("location_descriptions.location_id", locations)
    add_boolean_condition(
      "location_descriptions.public IS TRUE",
      "location_descriptions.public IS FALSE",
      params[:public]
    )
    super
  end

  def self.default_order
    "name"
  end
end

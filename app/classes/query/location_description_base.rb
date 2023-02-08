# frozen_string_literal: true

class Query::LocationDescriptionBase < Query::Base
  def model
    LocationDescription
  end

  def parameter_declarations
    super.merge(
      created_at?: [:time],
      updated_at?: [:time],
      users?: [User],
      locations?: [Location],
      public?: :boolean
    )
  end

  def initialize_flavor
    add_owner_and_time_stamp_conditions("location_descriptions")
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

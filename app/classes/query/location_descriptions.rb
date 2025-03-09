# frozen_string_literal: true

class Query::LocationDescriptions < Query::Base
  include Query::Initializers::Descriptions

  def model
    LocationDescription
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

  def initialize_flavor
    add_sort_order_to_title
    add_id_in_set_condition
    add_owner_and_time_stamp_conditions
    add_desc_by_author_condition(:location)
    add_desc_by_editor_condition(:location)
    ids = lookup_locations_by_name(params[:locations])
    add_association_condition("location_descriptions.location_id", ids)
    initialize_description_public_parameter(:location)
    initialize_content_has_parameter(:location)
    add_subquery_condition(:location_query, :locations)
    super
  end

  def self.default_order
    "name"
  end
end

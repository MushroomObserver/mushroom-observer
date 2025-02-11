# frozen_string_literal: true

class Query::LocationDescriptions < Query::Base
  # include Query::Params::Descriptions
  include Query::Initializers::Descriptions

  def model
    LocationDescription
  end

  def self.parameter_declarations
    super.merge(
      created_at: [:time],
      updated_at: [:time],
      ids: [LocationDescription],
      by_user: User,
      by_author: User,
      by_editor: User,
      # old_by: :string,
      users: [User],
      locations: [Location],
      location_query: { subquery: :Location },
      public: :boolean
      # with_descriptions: :boolean
    )
  end

  def initialize_flavor
    add_sort_order_to_title
    add_ids_condition
    add_owner_and_time_stamp_conditions
    add_by_user_condition
    add_desc_by_author_condition(:location)
    add_desc_by_editor_condition(:location)
    add_id_condition("location_descriptions.location_id", params[:locations])
    initialize_description_public_parameter(:location)
    add_subquery_condition(:location_query, :locations)
    super
  end

  # def coerce_into_location_query
  #   pargs = params_out_to_with_descriptions_params
  #   Query.lookup(:Location, pargs)
  # end

  def self.default_order
    "name"
  end
end

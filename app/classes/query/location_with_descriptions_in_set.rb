# frozen_string_literal: true

class Query::LocationWithDescriptionsInSet < Query::LocationBase
  def parameter_declarations
    super.merge(
      ids: [LocationDescription],
      old_title?: :string,
      old_by?: :string
    )
  end

  def initialize_flavor
    title_args[:descriptions] = params[:old_title] ||
                                :query_title_in_set.t(type: :description)
    initialize_in_set_flavor("location_descriptions")
    add_join(:location_descriptions)
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :in_set, params_with_old_by_restored)
  end
end

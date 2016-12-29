class Query::LocationWithDescriptionsInSet < Query::LocationBase
  def parameter_declarations
    super.merge(
      ids:        [LocationDescription],
      old_title?: :string,
      old_by?:    :string
    )
  end

  def initialize_flavor
    title_args[:descriptions] = params[:old_title] ||
                                :query_title_in_set.t(type: :description)
    set = clean_id_set(params[:ids])
    self.where << "location_descriptions.id IN (#{set})"
    add_join(:location_descriptions)
    super
  end

  def coerce_into_location_description_query
    Query.lookup(:LocationDescription, :in_set, params_with_old_by_restored)
  end
end

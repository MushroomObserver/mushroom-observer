class Query::NameWithDescriptionsInSet < Query::NameBase
  def parameter_declarations
    super.merge(
      ids:        [NameDescription],
      old_title?: :string,
      old_by?:    :string
    )
  end

  def initialize_flavor
    title_args[:descriptions] = params[:old_title] ||
                                :query_title_in_set.t(type: :description)
    add_id_condition("name_descriptions.id", params[:ids])
    add_join(:name_descriptions)
    super
  end

  def coerce_into_name_description_query
    Query.lookup(:NameDescription, :in_set, params_with_old_by_restored)
  end
end

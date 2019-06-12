class Query::ImageAdvancedSearch < Query::ImageBase
  include Query::Initializers::AdvancedSearch

  def parameter_declarations
    super.merge(
      advanced_search_parameter_declarations
    )
  end

  def initialize_flavor
    return if handle_content_search!

    add_join(:images_observations, :observations)
    initialize_advanced_search
    super
  end

  # This case is a disaster.  Perform it as an observation query, then
  # coerce into images.
  def handle_content_search!
    return false if params[:content].blank?

    self.executor = lambda do |args|
      args2 = args.dup
      args2.delete(:select)
      params2 = params.dup
      params2.delete(:by)
      ids = Query.lookup(:Observation, flavor, params2).result_ids(args2)
      ids = clean_id_set(ids)
      args2 = args.dup
      extend_join(args2) << :images_observations
      extend_where(args2) << "images_observations.observation_id IN (#{ids})"
      model.connection.select_rows(query(args2))
    end
  end

  def add_join_to_names
    add_join(:observations, :names)
  end

  def add_join_to_users
    add_join(:observations, :users)
  end

  def add_join_to_locations
    add_join(:observations, :locations!)
  end
end

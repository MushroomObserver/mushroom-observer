# frozen_string_literal: true

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

  # Perform content search as an observation query, then
  # coerce into images.
  def handle_content_search!
    return false if params[:content].blank?

    self.executor = lambda do |args|
      execute_content_search(args)
    end
  end

  def execute_content_search(args)
    # [Sorry, yes, this is a mess. But I don't expect this type of search
    # to survive much longer. Image searches are in desperate need of
    # critical revision for performance concerns, anyway. -JPH 20210809]
    args2 = args.dup
    args2.delete(:select)
    args2.delete(:order)
    args2.delete(:group)
    params2 = params.dup
    params2.delete(:by)
    ids = Query.lookup(:Observation, flavor, params2).result_ids(args2)
    ids = clean_id_set(ids)
    args2 = args.dup
    extend_join(args2) << :images_observations
    extend_where(args2) << "images_observations.observation_id IN (#{ids})"
    model.connection.select_rows(query(args2))
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

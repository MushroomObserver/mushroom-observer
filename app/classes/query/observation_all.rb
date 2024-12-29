# frozen_string_literal: true

class Query::ObservationAll < Query::ObservationBase
  include Query::Initializers::ObservationQueryDescriptions

  def initialize_flavor
    add_sort_order_to_title
    super
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_location_query
    do_coerce(:Location)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    is_search = params[:pattern].present? ||
                advanced_search_params.any? { |key| params[key].present? }
    pargs = is_search ? add_old_title(params_plus_old_by) : params_plus_old_by
    # transform :ids to :obs_ids
    pargs = params_out_to_with_observations_params(pargs)
    Query.lookup(new_model, :all, pargs)
  end

  def title
    default = super
    observation_query_description || default
  end
end

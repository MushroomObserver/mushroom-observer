# frozen_string_literal: true

class Query::ObservationAtWhere < Query::ObservationBase
  def parameter_declarations
    super.merge(
      user_where?: :string # used to pass parameter to create_location
    )
  end

  def initialize_flavor
    location = params[:user_where]
    title_args[:where] = location
    pattern = clean_pattern(location)
    where << "observations.where LIKE '%#{pattern}%'"
    super
  end

  def default_order
    "name"
  end

  def coerce_into_image_query
    do_coerce(:Image)
  end

  def coerce_into_name_query
    do_coerce(:Name)
  end

  def do_coerce(new_model)
    Query.lookup(new_model, :with_observations_at_where, params_plus_old_by)
  end
end

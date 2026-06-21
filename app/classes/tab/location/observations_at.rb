# frozen_string_literal: true

# "Observations at this location" link with a count in parens.
class Tab::Location::ObservationsAt < Tab::Base
  def initialize(location:)
    super()
    @location = location
  end

  def title
    "#{:show_location_observations.t} " \
      "(#{@location.observations.size})"
  end

  def path
    query = Query.lookup(:Observation, locations: @location.id)
    query.save unless query.id
    with_q_param(observations_path, query.q_param)
  end

  def alt_title
    :show_location_observations.t
  end

  def html_options
    { icon: :observations }
  end

  def model
    @location
  end
end

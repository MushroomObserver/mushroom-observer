# frozen_string_literal: true

class ObservationViewsController < ApplicationController
  before_action :login_required

  # endpoint to mark an observation as 'reviewed' by the current user
  def update
    pass_query_params
    # basic sanitizing of the param. ivars needed in js response
    # checked is a string!
    @reviewed = params[:reviewed] == "1"
    return unless (obs = Observation.find(params[:id]))

    # update_view_stats creates an o_v if it doesn't exist
    @obs_id = obs.id # ivar used in the js template
    ov = ObservationView.update_view_stats(@obs_id, User.current_id)
    # now we can update it
    ov.update(reviewed: @reviewed)
    respond_to do |format|
      format.turbo_stream
      format.html do
        return redirect_to(identify_observations_path)
      end
    end
  end
end

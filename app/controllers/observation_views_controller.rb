# frozen_string_literal: true

class ObservationViewsController < ApplicationController
  before_action :login_required

  # endpoint to mark an observation as 'reviewed' by the current user
  def update
    pass_query_params
    # basic sanitizing of the param
    reviewed = params[:reviewed] == 1
    @obs_id = params[:id].to_s # needed in js response
    ov = ObservationView.find_by(observation_id: @obs_id,
                                 user_id: @user.id.to_s)
    return unless ov

    ov.update(reviewed: reviewed)
    respond_to do |format|
      format.js
    end
  end
end

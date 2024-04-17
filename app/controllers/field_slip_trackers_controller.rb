# frozen_string_literal: true

class FieldSlipTrackersController < ApplicationController
  before_action :login_required

  # This is only a JSON endpoint describing the status of a particular tracker.
  def show
    # should we raise an error if the tracker is not found?
    return unless (@tracker = FieldSlipTracker.find(params[:id]))

    status = {
      id: @tracker.id,
      filename: @tracker.filename,
      status: @tracker.status,
      link: @tracker.link
    }
    render(json: ActiveSupport::JSON.encode(status))
  end
end

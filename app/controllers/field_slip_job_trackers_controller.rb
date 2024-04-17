# frozen_string_literal: true

class FieldSlipJobTrackersController < ApplicationController
  before_action :login_required

  # This is only a JSON endpoint describing the status of a particular tracker.
  def show
    # should we raise an error if the tracker is not found?
    return unless (@tracker = FieldSlipJobTracker.find(params[:id]))

    # status = {
    #   id: @tracker.id,
    #   filename: @tracker.filename,
    #   status: @tracker.status,
    #   link: @tracker.link
    # }
    # render(json: ActiveSupport::JSON.encode(status))
    respond_to do |format|
      format.turbo_stream do
        render(partial: "projects/field_slips/tracker_row",
               locals: { tracker: tracker })
      end
    end
  end
end

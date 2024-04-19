# frozen_string_literal: true

class FieldSlipJobTrackersController < ApplicationController
  before_action :login_required

  # This is only a JSON endpoint describing the status of a particular tracker.
  def show
    # should we raise an error if the tracker is not found?
    return unless (@tracker = FieldSlipJobTracker.find(params[:id]))

    respond_to do |format|
      format.turbo_stream do
        render(turbo_stream: turbo_stream.replace(
          :"field_slip_job_tracker_#{@tracker.id}", # id of div to replace
          partial: "projects/field_slips/tracker_row",
          locals: { tracker: @tracker }
        ))
      end
    end
  end
end

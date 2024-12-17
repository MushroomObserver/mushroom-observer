# frozen_string_literal: true

module InatImports
  class JobTrackersController < ApplicationController
    before_action :login_required

    # This is only a Turbo endpoint updating the row of a particular tracker.
    def show
      return unless (@tracker = InatImportJobTracker.find(params[:id]))

      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :status, # id of div to replace
            partial: "inat_imports/job_trackers/status",
            locals: { tracker: @tracker }
          ))
        end
      end
    end
  end
end

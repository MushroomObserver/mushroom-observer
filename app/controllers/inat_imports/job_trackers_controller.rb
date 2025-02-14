# frozen_string_literal: true

module InatImports
  class JobTrackersController < ApplicationController
    before_action :login_required

    # This is only a Turbo endpoint updating the display of the status of a job.
    def show
      return unless (@tracker = InatImportJobTracker.find(params[:id]))

      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :status, # id of element to change
            partial: "inat_imports/job_trackers/updates",
            locals: { tracker: @tracker }
          ))
        end
      end
    end
  end
end

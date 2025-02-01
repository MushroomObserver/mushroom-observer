# frozen_string_literal: true

module InatImports
  class JobTrackersController < ApplicationController
    before_action :login_required

    # This is only a Turbo endpoint updating the display of the status of a job.
    def show
      # Trackers are created in the background and not automatically deleted
      # when the job is done. So we need to find the last one.
      @tracker = InatImportJobTracker.where(params[:id]).
                 order(created_at: :asc).last
      return unless @tracker

      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :updates, # id of element to change
            partial: "inat_imports/job_trackers/updates",
            locals: { tracker: @tracker }
          ))
        end
      end
    end
  end
end

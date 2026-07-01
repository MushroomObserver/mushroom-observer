# frozen_string_literal: true

module InatImports
  class JobTrackersController < ApplicationController
    before_action :login_required

    # This is only a Turbo endpoint updating the display of the status of a job.
    def show
      @tracker = InatImportJobTracker.find(params[:id])
      return unless @tracker

      respond_to do |format|
        format.turbo_stream do
          render(turbo_stream: turbo_stream.update(
            :"status_#{@tracker.id}",
            Views::Controllers::InatImports::JobTrackers::Current.new(
              tracker: @tracker
            )
          ))
        end
      end
    end
  end
end

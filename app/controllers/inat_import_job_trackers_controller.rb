# frozen_string_literal: true

class InatImportJobTrackersController < ApplicationController
  before_action :login_required

  def show
    @tracker = InatImportJobTracker.find(params[:id])
    @inat_import = InatImport.find(@tracker.inat_import)

    respond_to do |format|
      format.html
      format.turbo_stream { render_current_status }
    end
  end

  private

  def render_current_status
    turbo_stream.update("status") { status }
  end
end

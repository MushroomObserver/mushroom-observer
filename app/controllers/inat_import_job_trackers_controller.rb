# frozen_string_literal: true

class InatImportJobTrackersController < ApplicationController
  before_action :login_required

  def show
    @tracker = InatImportJobTracker.find(params[:id])
  end
end

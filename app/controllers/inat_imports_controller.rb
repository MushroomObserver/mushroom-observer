# frozen_string_literal: true

class InatImportsController < ApplicationController
  before_action :login_required

  def show
    @tracker = InatImportJobTracker.find(params[:id])
    @inat_import = InatImport.find(@tracker.inat_import)
  end
end

# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
class InatExportsController < ApplicationController
  include Inat::Constants

  before_action :login_required

  def new
    @inat_export = InatExport.find_or_create_by(user: @user)
=begin
    return unless @inat_export.job_pending?

    tracker = InatExportJobTracker.where(inat_export: @inat_export).
              order(:created_at).last
    flash_warning(:inat_export_tracker_pending.l)
    redirect_to(
      inat_export_path(@inat_import, params: { tracker_id: tracker.id })
    )
=end
  end
end

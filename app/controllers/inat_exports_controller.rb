# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
class InatExportsController < ApplicationController
  include Inat::Constants

  before_action :login_required

  # Display the iNat export form
  # Called two places
  #  observation, with an id param
  #  observations index (which has an Observation query)
  def new
    @inat_export = InatExport.find_or_create_by(user: @user)
    # return export_pending if @inat_export.job_pending?

    define_ivars
  end

  private

  def export_pending
    flash_warning(:inat_export_tracker_pending.l)
    return_path = if called_from_observation_page?
                    observation_path(params[:id])
                  else
                    observations_path
                  end
    redirect_to(return_path)
  end

  def called_from_observation_page?
    params[:id].present?
  end

  def define_ivars
    # id's of MO observations requested for export
    @requested_ids =
      if called_from_observation_page?
        [params[:id].to_i]
      else
        query = find_query(:Observation)
        [query.results.ids]
      end
    # array of ids of Observations to export
    @mo_ids = Observation.where(id: @requested_ids, user: @user).
              # NOTE: jdc 20250902 Make exportable_to_inat? a scope
              select(&:exportable_to_inat?).
              each_with_object([]) { |obs, ary| ary << obs.id }
  end

  public

  def create
    return reload_form unless params_valid?

    assure_user_has_inat_export_api_key
    init_ivars
    request_inat_user_authorization
  end
end

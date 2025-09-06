# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
class InatExportsController < ApplicationController
  include Inat::Constants
  include Validators

  before_action :login_required

  # Display the iNat export form
  # Called two places
  #  observation, with an id param
  #  observations index (which has an Observation query)
  def new
    @inat_export = InatExport.find_or_create_by(user: @user)
    return export_pending if @inat_export.job_pending?

    define_new_ivars
    @inat_export.update(mo_ids: @mo_ids)
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

  def define_new_ivars
    @source = if called_from_observation_page?
                :observation
              else
                :observations
              end
    # id's of MO observations requested for export
    @requested_ids =
      if called_from_observation_page?
        [params[:id].to_i]
      else
        query = find_query(:Observation)
        query.result_ids
      end
    # array of ids of Observations to export
    @mo_ids = Observation.where(id: @requested_ids, user: @user).
              # NOTE: jdc 20250902 Make exportable_to_inat? a scope
              select(&:exportable_to_inat?).
              each_with_object([]) { |obs, ary| ary << obs.id }
  end

  public

  def create
    define_create_ivars
    return reload_form unless params_valid?

    assure_user_has_mo_api_key
    request_inat_user_authorization
  end

  private

  def define_create_ivars
    @inat_export = InatExport.find_or_create_by(user: @user)
    @mo_ids = @inat_export.mo_ids
  end

  def reload_form
    @inat_username = params[:inat_username]
    render(:new)
  end

  # TODO: DRY with InatImportsController#assure_user_has_inat_api_key
  def assure_user_has_mo_api_key
    key = APIKey.find_by(user: @user, notes: MO_API_KEY_NOTES)
    key = APIKey.create(user: @user, notes: MO_API_KEY_NOTES) if key.nil?
    key.verify! if key.verified.nil?
  end

  # TODO: DRY with InatImportsController#request_inat_user_authorization
  def request_inat_user_authorization
    redirect_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end
end

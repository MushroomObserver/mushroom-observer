# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# Actions
# -------
# new (get)
# create (post)
# authorization_response (get)
# cancel (post):: cancels the InatImportJob
#
# Work flow:
# 1. User calls `new`, fills out form
#    Adds a InatImport instance if user lacks one
# 2. create
#    reloads form if params invalid or changed
#    saves some user data in a InatImport instance
#      attributes include: user, inat_ids, token, state
#    passes things off (redirects) to iNat at the INAT_AUTHORIZATION_URL
# 3. iNat
#    checks if MO is authorized to access iNat user's confidential data
#      if not, asks iNat user for authorization
#    iNat calls the MO redirect_url (authorization_response) with a code param
# 4. MO continues in the authorization_response action
#    Reads the saved InatImport instance
#    Updates the InatImport instance with the code received from iNat
#    Instantiates an InatImportJobTracker, passing in the InatImport instance
#    Enqueues an InatImportJob, passing in the InatImport instance
#    Redirects to InatImport.show (for that InatImport instance)
#    ---------------------------------
#    InatImport.show view: (app/views/controllers/inat_imports/show.html.erb)
#      Includes a `#status` element which:
#        Instantiates a Stimulus controller (inat-import-job_controller)
#        with an endpoint of InatImportJobTracker.show
#        is updated by a TurboStream response from the endpoint
#    ---------------------------------
#    Stimulus controller (inat-import-job_controller):
#      Makes a request every second to the InatImportJobTracker.show endpoint
#    ---------------------------------
#    The endpoint (app/controllers/inat_imports/job_trackers_controller.rb):
#      renders the InatImport as a TurboStream response
#    ---------------------------------
# 5. The InatImportJob:
#      Uses the `code` to obtain an oauth access_token
#      Trades the oauth token for a JWT api_token
#      Checks if the MO user is trying to import someone else's observations
#      Makes an authenticated iNat API request for the desired observations
#      For each iNat obs in the results,
#         creates an Inat::Obs
#         adds an MO Observation, mapping Inat::Obs details to the MO Obs
#         adds the iNat id to the MO observation inat_id_field
#         adds a Snapshot of the iNat observation to the MO Observation notes
#         adds Inat photos to the MO Observation via the MO API
#         maps iNat sequences to MO Sequences
#         updates the iNat obs with a Mushroom Observer URL Observation Field
#         updates the iNat obs Notes
#      updates the InatImport instance attributes:
#         state, importables, imported_count, total_imported_count,
#         total_seconds, avg_import_time,response_errors
#
class InatImportsController < ApplicationController
  include Validators
  include Inat::Constants
  include Observations::InatImportsHelper

  before_action :login_required

  def show
    @tracker = InatImportJobTracker.find(params[:tracker_id])
    @inat_import = InatImport.find(params[:id])
  end

  def new
    @inat_import = InatImport.find_or_create_by(user: @user)
    if @inat_import.job_pending?
      tracker = InatImportJobTracker.where(inat_import: @inat_import).
                order(:created_at).last
      flash_warning(:inat_import_tracker_pending.l)
      redirect_to(
        inat_import_path(@inat_import, params: { tracker_id: tracker.id })
      )
    else
      @inat_import.update(inat_ids: "", import_all: false)
      render(:new)
    end
  end

  def create
    @inat_import = InatImport.find_or_create_by(user: @user)
    @inat_import.update(cancel: false) # reset cancel flag when starting create
    return reload_form unless params_valid?

    assure_user_has_inat_import_api_key
    # must decide if user changed input before calling init_ivars
    input_changed = user_input_changed?
    init_ivars
    return update_form if input_changed

    request_inat_user_authorization
  end
  # ---------------------------------

  private

  def reload_form
    @inat_ids = params[:inat_ids]
    @import_all = params[:all]
    @inat_username = params[:inat_username]
    render(:new)
  end

  def assure_user_has_inat_import_api_key
    key = APIKey.find_by(user: @user, notes: MO_API_KEY_NOTES)
    key = APIKey.create(user: @user, notes: MO_API_KEY_NOTES) if key.nil?
    key.verify! if key.verified.nil?
  end

  def user_input_changed?
    truthy?(params[:all]) != truthy?(@inat_import.import_all) ||
      params[:inat_ids] != @inat_import.inat_ids ||
      params[:inat_username].strip != @inat_import.inat_username
  end

  def truthy?(val)
    val.to_s == "1" || val.to_s.downcase == "true"
  end

  def init_ivars
    @inat_import.update(
      state: "Authorizing",
      import_all: params[:all],
      importables: preliminary_importables_count,
      imported_count: 0,
      avg_import_time: @inat_import.initial_avg_import_seconds,
      inat_ids: params[:inat_ids],
      inat_username: params[:inat_username].strip,
      response_errors: "",
      token: "",
      log: [],
      ended_at: nil,
      cancel: false
    )
    # refined count using iNat API query which
    # excludes already imported/exported observations and non-fungi/slime molds
    @inat_import.update(importables: inat_expected_import_count(@inat_import))
  end

  # Initial estimate based only on the user-provided list of iNat ids.
  def preliminary_importables_count
    return nil if importing_all?

    params[:inat_ids].split(",").length
  end

  def update_form
    reload_form
  end

  def request_inat_user_authorization
    redirect_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  # ---------------------------------

  public

  # iNat redirects here after user completes iNat authorization,
  # passing a code param if the user authorized MO to access their iNat data
  # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
  def authorization_response
    auth_code = params[:code]
    return unauthorized if auth_code.blank?

    inat_import = inat_import_authenticating(auth_code)
    inat_import.reset_last_obs_start
    tracker = fresh_tracker(inat_import)

    Rails.logger.info(
      "Enqueueing InatImportJob for InatImport id: #{inat_import.id}"
    )
    # InatImportJob.perform_now(inat_import) # uncomment to manually test job
    InatImportJob.perform_later(inat_import) # uncomment for production

    redirect_to(inat_import_path(inat_import,
                                 params: { tracker_id: tracker.id }))
  end

  # ---------------------------------

  private

  def unauthorized
    flash_error(:inat_no_authorization.l)
    redirect_to(observations_path)
  end

  def inat_import_authenticating(auth_code)
    inat_import = InatImport.find_or_create_by(user: @user)
    inat_import.update(token: auth_code, state: "Authenticating")
    inat_import
  end

  def fresh_tracker(inat_import)
    # clean out this user's old tracker(s)
    InatImportJobTracker.where(inat_import: inat_import.id).destroy_all
    InatImportJobTracker.create(inat_import: inat_import.id)
  end

  public

  def cancel
    @inat_import = InatImport.find(params[:id])
    @inat_import.update(cancel: true)
    @tracker = InatImportJobTracker.where(inat_import: @inat_import).
               order(:created_at).last
    render(:show)
  end
end

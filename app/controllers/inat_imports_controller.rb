# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
# Actions
# -------
# new (get)
# create (post)
# authorization_response (get)
#
# Work flow:
# 1. User calls `new`, fills out form
# 2. create
#      saves some user data in a InatImport instance
#        attributes include: user, inat_ids, token, state
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
#      Checks if the MO user is trying to import some else's obss
#      Makes an authenticated iNat API request for the desired observations
#      For each iNat obs in the results,
#         creates an Inat::Obs
#         adds an MO Observation, mapping Inat::Obs details to the MO Obs
#         adds Inat photos to the MO Observation via the MO API
#         maps iNat sequences to MO Sequences
#         adds an MO Comment with a snapshot of the imported data
#         updates the iNat obs with a Mushroom Observer URL Observation Field
#         updates the iNat obs Notes
#      updates the InatImport instance attributes:
#         state, importables, imported_count, response_errors
#
class InatImportsController < ApplicationController
  include Validators

  before_action :login_required
  before_action :pass_query_params

  # Site for authorization and authentication requests
  SITE = "https://www.inaturalist.org"
  # iNat calls this after iNat user authorizes MO to access their data.
  # Different in production vs. test & development
  REDIRECT_URI = Rails.configuration.redirect_uri
  # iNat's id for the MO application
  # Different in production vs. test & development
  APP_ID = Rails.application.credentials.inat.id
  # URL to obtain authorization from iNat user for access to their private data
  INAT_AUTHORIZATION_URL =
    "#{SITE}/oauth/authorize?client_id=#{APP_ID}" \
    "&redirect_uri=#{REDIRECT_URI}&response_type=code".freeze
  # The iNat API. Not called here, but referenced in tests and ActiveJob
  API_BASE = "https://api.inaturalist.org/v1"
  # notes for MO API Key used in iNat imports
  MO_API_KEY_NOTES = "inat import"

  def show
    @tracker = InatImportJobTracker.find(params[:tracker_id])
    @inat_import = InatImport.find(params[:id])
  end

  def new
    @inat_import = InatImport.find_or_create_by(user: @user)
    return unless @inat_import.pending?

    tracker = InatImportJobTracker.where(inat_import: @inat_import).last
    flash_error(:inat_import_tracker_pending.t)
    redirect_to(
      inat_import_path(@inat_import, params: { tracker_id: tracker.id })
    )
  end

  def create
    return reload_form unless params_valid?

    assure_user_has_inat_import_api_key
    @inat_import = InatImport.find_or_create_by(user: @user)
    @inat_import.update(state: "Authorizing",
                        import_all: params[:all],
                        importables: 0, imported_count: 0,
                        inat_ids: params[:inat_ids],
                        inat_username: params[:inat_username].strip,
                        response_errors: "", token: "", log: [], ended_at: nil)
    request_inat_user_authorization
  end

  # ---------------------------------

  private

  def reload_form
    @inat_ids = params[:inat_ids]
    @inat_username = params[:inat_username]
    render(:new)
  end

  def assure_user_has_inat_import_api_key
    key = APIKey.find_by(user: @user, notes: MO_API_KEY_NOTES)
    key = APIKey.create(user: @user, notes: MO_API_KEY_NOTES) if key.nil?
    key.verify! if key.verified.nil?
  end

  def request_inat_user_authorization
    redirect_to(INAT_AUTHORIZATION_URL, allow_other_host: true)
  end

  # ---------------------------------

  public

  # iNat redirects here after user completes iNat authorization
  def authorization_response
    auth_code = params[:code]
    return not_authorized if auth_code.blank?

    inat_import = inat_import_authenticating(auth_code)
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

  def not_authorized
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
end

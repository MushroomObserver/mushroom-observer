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
#    passes things off (redirects) to iNat at the inat_authorization_url
# 3. iNat
#    checks if MO is authorized to access iNat user's confidential data
#      if not, asks iNat user for authorization
#    iNat calls the MO redirect_url (authorization_response) with a code param
# 4. MO continues in the authorization_response action
#    Reads the saved InatImport instance
#    Updates the InatImport instance with the code received from iNat
#    Enqueues an InatImportJob, passing in the InatImport instance
# 5. The rest happens in the background. The InatImportJob:
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
#
class InatImportsController < ApplicationController
  include Validators

  before_action :login_required
  before_action :pass_query_params

  def show
    @tracker = InatImportJobTracker.find(params[:id])
    @inat_import = InatImport.find(@tracker.inat_import)
  end

  # Site for authorization and authentication requests
  SITE = "https://www.inaturalist.org"
  # iNat calls this after iNat user authorizes MO to access their data.
  REDIRECT_URI = Rails.configuration.redirect_uri
  # iNat's id for the MO application
  APP_ID = Rails.application.credentials.inat.id
  # The iNat API. Not called here, but referenced in tests and ActiveJob
  API_BASE = "https://api.inaturalist.org/v1"

  def new; end

  def create
    return reload_form unless params_valid?

    @inat_import = InatImport.find_or_create_by(user: User.current)
    @inat_import.update(state: "Authorizing",
                        import_all: params[:all],
                        importables: 0, imported_count: 0,
                        inat_ids: params[:inat_ids],
                        inat_username: params[:inat_username].strip,
                        response_errors: "", token: "", log: [])

    request_inat_user_authorization
  end

  # ---------------------------------

  private

  def reload_form
    @inat_ids = params[:inat_ids]
    @inat_username = params[:inat_username]
    render(:new)
  end

  def request_inat_user_authorization
    redirect_to(inat_authorization_url, allow_other_host: true)
  end

  def inat_authorization_url
    "#{SITE}/oauth/authorize" \
    "?client_id=#{APP_ID}" \
    "&redirect_uri=#{REDIRECT_URI}" \
    "&response_type=code"
  end

  # ---------------------------------

  public

  # iNat redirects here after user completes iNat authorization
  def authorization_response
    auth_code = params[:code]
    return not_authorized if auth_code.blank?

    @inat_import = InatImport.find_or_create_by(user: User.current)
    @inat_import.update(token: auth_code, state: "Authenticating")
    InatImportJobTracker.create(inat_import: @inat_import.id)

    Rails.logger.info(
      "Enqueuing InatImportJob for InatImport id: #{@inat_import.id}"
    )
    # InatImportJob.perform_now(@inat_import) # for manual testing
    InatImportJob.perform_later(@inat_import)

    redirect_to(inat_import_path(@inat_import.id))
  end

  # ---------------------------------

  private

  def not_authorized
    flash_error(:inat_no_authorization.l)
    redirect_to(observations_path)
  end
end
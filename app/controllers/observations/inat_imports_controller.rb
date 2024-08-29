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
#      saves some user data in a iNatImport instance
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
#      Makes an authenticated iNat API request for the desired observations
#      For each iNat obs in the results,
#         creates an InatObs
#         adds an MO Observation, mapping InatObs details to the MO Observation
#         adds Inat photos to the MO Observation via the MO API
#
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # Site for authorization and authentication requests
    SITE = "https://www.inaturalist.org"
    # what iNat will call after user responds to authorization request
    REDIRECT_URI =
      "http://localhost:3000/observations/inat_imports/authorization_response"
    # iNat's id for the MO application
    APP_ID = Rails.application.credentials.inat.id
    # The iNat API. Not called here, but reference in tests and ActiveJob
    API_BASE = "https://api.inaturalist.org/v1"

    def new; end

    def create
      return username_required if params[:inat_username].blank?
      return reload_form if bad_inat_ids_param?
      return designation_required unless imports_designated?
      return consent_required if params[:consent] == "0"

      @inat_import = InatImport.find_or_create_by(user: User.current)
      @inat_import.update(state: "Authorizing",
                          import_all: params[:all],
                          inat_ids: params[:inat_ids],
                          inat_username: params[:inat_username].strip)

      request_inat_user_authorization
    end

    # ---------------------------------

    private

    def reload_form
      @inat_ids = params[:inat_ids]
      @inat_username = params[:inat_username]
      render(:new)
    end

    def designation_required
      flash_warning(:inat_no_imports_designated.t)
      reload_form
    end

    def imports_designated?
      params[:all] == "1" || params[:inat_ids].present?
    end

    def consent_required
      flash_warning(:inat_consent_required.t)
      reload_form
    end

    def username_required
      flash_warning(:inat_missing_username.l)
      reload_form
    end

    def bad_inat_ids_param?
      contains_illegal_characters?
    end

    def contains_illegal_characters?
      return false unless /[^\d ,]/.match?(params[:inat_ids])

      flash_warning(:runtime_illegal_inat_id.l)
      true
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

      InatImportJob.perform_later(@inat_import)
      # InatImportJob.perform_now(@inat_import) # for manual testing

      flash_notice(:inat_import_started.t)
      redirect_to(observations_path)
    end

    # ---------------------------------

    private

    def not_authorized
      flash_error(:inat_no_authorization.l)
      redirect_to(observations_path)
    end
  end
end

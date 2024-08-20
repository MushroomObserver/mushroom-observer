# frozen_string_literal: true

# import iNaturalist Observations as MO Observations
#
# Work flow:
# 1. User calls `new`, fills out form
# 2. create
#      saves tracking information in the iNatImport model
#        attributes include: user, inat_ids, token, state.
#    passes things off (redirects) to iNat at the inat_authorization_url
# 3. iNat
#    checks if MO is authorized to access iNat user's confidential data
#      if not, asks iNat user for authorization
#    passes things back to MO at the the redirect_url (authenticate)
# 5. MO continues in the `authenticate` action
#    Gets data from, and updates, InatImport
#    Uses the `code` it received from iNat to obtain an oauth token
#    Uses the oauth token obtain a JWT
#    Makes an authenticated iNat API request for the desired observations
#    For each iNat obs in the search results, creates an InatObs and imports it
module Observations
  class InatImportsController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # Site for authorization and authentication requests
    SITE = "https://www.inaturalist.org"
    # what iNat will call after user responds to authorization request
    REDIRECT_URI =
      "http://localhost:3000/observations/inat_imports/authenticate"
    # iNat's id for the MO application; this is set in iNat
    APP_ID = Rails.application.credentials.inat.id

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
                          inat_username: params[:inat_username])

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
      "?client_id=#{Rails.application.credentials.inat.id}" \
      "&redirect_uri=#{REDIRECT_URI}" \
      "&response_type=code"
    end

    # ---------------------------------

    public

    # iNat redirects here after user completes iNat authorization
    def authenticate
      auth_code = params[:code]
      return not_authorized if auth_code.blank?

      @inat_import = InatImport.find_or_create_by(user: User.current)
      @inat_import.update(state: "Authenticating")
      access_token = obtain_access_token(auth_code)

      @inat_import.update(token: access_token, state: "Importing")

      # InatImportJob.perform_later(
      InatImportJob.perform_now(
        access_token,
        InatImport.find_or_create_by(user: User.current)
      )

      redirect_to(observations_path)
    end

    # ---------------------------------

    private

    def not_authorized
      flash_error(:inat_no_authorization.l)
      redirect_to(observations_path)
    end

    def obtain_access_token(auth_code)
      # Use "code" received from iNat to obtain an oAuth `access_token`
      # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
      payload = {
        client_id: APP_ID,
        client_secret: Rails.application.credentials.inat.secret,
        code: auth_code,
        redirect_uri: REDIRECT_URI,
        grant_type: "authorization_code"
      }
      oauth_response = RestClient.post("#{SITE}/oauth/token", payload)
      JSON.parse(oauth_response.body)["access_token"]
    end
  end
end

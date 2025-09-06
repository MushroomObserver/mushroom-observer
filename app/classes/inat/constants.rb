# frozen_string_literal: true

class Inat
  # constants used in iNat imports and export
  module Constants
    # Site for authorization and authentication requests
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    SITE = "https://www.inaturalist.org"

    # iNat calls this after iNat user authorizes MO to access their data.
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    # Differs in production vs. test & development environments
    # production redirects to webserver,
    # test & development redirect to the local server.
    REDIRECT_URI = Rails.configuration.redirect_uri

    # iNat's id for the MO application
    # Differs in production vs. test & development
    APP_ID = Rails.application.credentials.inat.id

    # URL to obtain authorization (an "Authorization Code")
    # to allow MO to access an iNat user's private data
    # https://www.inaturalist.org/pages/api+reference#authorization_code_flow
    INAT_AUTHORIZATION_URL =
      "#{SITE}/oauth/authorize?client_id=#{APP_ID}" \
      "&redirect_uri=#{REDIRECT_URI}&response_type=code".freeze

    # iNat response when authorization is denied
    AUTHORIZATION_DENIAL_CALLBACK_PARAMS = {
      error: "access_denied",
      error_description:
        "The resource owner or authorization server denied the request."
    }.freeze

    # The iNat API
    API_BASE = "https://api.inaturalist.org/v1"

    # The APIKey#notes for the user's MO API Key used for iNat imports
    MO_API_KEY_NOTES = "inat import"
    # Used to limit results of iNat API requests to mushrooms & slime molds,
    # (Protozoa serves as a proxy for slime molds.)
    ICONIC_TAXA = "Fungi,Protozoa"
    # base url for iNat CC-licensed and public domain photos
    LICENSED_PHOTO_BASE =
      "https://inaturalist-open-data.s3.amazonaws.com/photos"
    # base url for iNat unlicensed photos
    UNLICENSED_PHOTO_BASE = "https://static.inaturalist.org/photos"
    # id of iNat's "Mushroom Observer URL" observation field
    MO_URL_OBSERVATION_FIELD_ID = 5005

    # MO adds this string + date to the description of iNat observation
    IMPORTED_BY_MO = "Imported by Mushroom Observer"
  end
end

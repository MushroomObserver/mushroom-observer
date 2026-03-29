# frozen_string_literal: true

class Inat
  # constants used in importing iNaturalist observations
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

    # The iNat API
    API_BASE = "https://api.inaturalist.org/v1"

    # The APIKey#notes for the user's MO API Key used for iNat imports
    MO_API_KEY_NOTES = "inat import"

    # Limit results of iNat API requests to mushrooms & slime molds.
    # disable cop to facilitate comparing numbers to iNat url's & documentation
    FUNGI_TAXON_ID = 47170 # rubocop:disable Style/NumericLiterals
    MYCETOZOA_TAXON_ID = 47685 # rubocop:disable Style/NumericLiterals
    IMPORTABLE_TAXON_IDS_ARG = [FUNGI_TAXON_ID, MYCETOZOA_TAXON_ID].join(",").
                               freeze

    # base url for iNat CC-licensed and public domain photos
    LICENSED_PHOTO_BASE =
      "https://inaturalist-open-data.s3.amazonaws.com/photos"
    # base url for iNat unlicensed photos
    UNLICENSED_PHOTO_BASE = "https://static.inaturalist.org/photos"
    # id of iNat's "Mushroom Observer URL" observation field
    MO_URL_OBSERVATION_FIELD_ID = 5005

    # Filter params added to every iNat observation API request
    # to restrict results to observations eligible for import:
    BASE_FILTER_PARAMS = {
      # not already exported from or imported to MO
      # (field written by iNat's defunct Import from MO feature,
      # Pulk's mirror script, and ObservationImporter)
      without_field: "Mushroom Observer URL"
    }.freeze

    # Added when importing others' observations (superimporter, not own).
    # Own-observation imports accept unlicensed obs and apply the user's
    # default MO license to any unlicensed images.
    #
    # The iNat API `licensed` param returns true if the observation
    # license_code is null, which seems to happen only if **both** the
    # observation. So we have to use this filter to get the count of
    # observations that are licensed, and subtract from total to get the
    # unlicensed count.
    LICENSED_FILTER =
      { license: "license=cc0,cc-by,cc-by-nc,cc-by-nd," \
                 "cc-by-sa,cc-by-nc-nd,cc-by-nc-nd-sa" }.freeze

    # Kept for backwards compatibility; some callers may still reference this.
    IMPORT_FILTER_PARAMS = BASE_FILTER_PARAMS.merge(LICENSED_FILTER).freeze

    # MO adds this string + date to the description of iNat observation
    IMPORTED_BY_MO = "Imported by Mushroom Observer"
  end
end

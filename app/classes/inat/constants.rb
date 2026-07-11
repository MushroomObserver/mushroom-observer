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

    # iNat's id and secret for the MO application.
    # Differ in production vs. test & development.
    # Safe-navigated so module load and stubs/jobs don't crash
    # when credentials can't be decrypted — e.g. CI runs for PRs
    # from forked repos, because GitHub Actions does not pass
    # repo secrets to workflows triggered by fork PRs. When
    # credentials are missing both end up nil; the OAuth stub
    # helper and InatImportJob#authenticate both pass them
    # through, so the WebMock body comparison still matches and
    # tests run end-to-end.
    APP_ID = Rails.application.credentials.inat&.id
    APP_SECRET = Rails.application.credentials.inat&.secret

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
    IMPORTABLE_TAXON_IDS = [FUNGI_TAXON_ID, MYCETOZOA_TAXON_ID].freeze
    IMPORTABLE_TAXON_IDS_ARG = IMPORTABLE_TAXON_IDS.join(",").freeze

    # iNat UI "iconic_taxa" values corresponding to IMPORTABLE_TAXON_IDS.
    # Used for the confirm form's UI-facing links, since iNat's
    # observations search UI has no taxon_id param.
    IMPORTABLE_ICONIC_TAXA = %w[Fungi Protozoa].freeze
    IMPORTABLE_ICONIC_TAXA_ARG = IMPORTABLE_ICONIC_TAXA.join(",").freeze

    MO_URL_OBSERVATION_FIELD_ID = 5005

    # Extracts the MO observation id from a "Mushroom Observer URL" field
    # value, tolerating the URL variants that appear in the wild (current,
    # /obs/, legacy /observer/show_observation/) and prefixes like
    # "DEAD LINK: " (#4565).
    MO_URL_FIELD_VALUE_ID_RE = %r{mushroomobserver\.org/
      (?:observations/|obs/|observer/show_observation/)?(\d+)}x

    # Filter params added to every iNat observation API request
    # to restrict results to observations eligible for import:
    BASE_FILTER_PARAMS = {
      # not already exported from or imported to MO
      # (field written by iNat's defunct Import from MO feature,
      # Pulk's mirror script, and ObservationImporter)
      without_field: "Mushroom Observer URL"
    }.freeze

    # A work-around because iNat has no "has a date" filter;
    # an arbitrarily early d1 approximates it.
    EARLIEST_DATE_FILTER = "1000-01-01"

    # Added when importing others' observations (superimporter, not own).
    # Own-observation imports accept unlicensed obs and apply the user's
    # default MO license to any unlicensed images.
    LICENSED_FILTER = { licensed: true }.freeze

    # Kept for backwards compatibility; some callers may still reference this.
    IMPORT_FILTER_PARAMS = BASE_FILTER_PARAMS.merge(LICENSED_FILTER).freeze

    # MO adds this string + date to the description of iNat observation
    IMPORTED_BY_MO = "Imported by Mushroom Observer"

    # Used in the copyright line of the iNat snapshot
    OBS_COPYRIGHT_LABEL = "Observation ©"
    ALL_RIGHTS_RESERVED = "all rights reserved"
  end
end

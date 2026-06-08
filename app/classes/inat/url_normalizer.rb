# frozen_string_literal: true

class Inat
  # Converts an iNat observation search URL or iNat API URL into a cleaned
  # query string suitable for use as the base of an import query.
  #
  # Accepts:
  #   https://www.inaturalist.org/observations?project_id=291058&...
  #   https://api.inaturalist.org/v1/observations?project_id=291058&...
  #
  # Returns a query string with MO-controlled params stripped, or nil if the
  # URL is not a valid iNat observations URL.
  class URLNormalizer
    VALID_HOSTS_AND_PATHS = {
      "www.inaturalist.org" => "/observations",
      "api.inaturalist.org" => "/v1/observations"
    }.freeze

    # Params MO always controls; strip them so the user's URL doesn't conflict.
    STRIP_PARAMS = %w[
      subview view
      page per_page order order_by
      only_id id
      without_field
      taxon_id iconic_taxa
    ].freeze

    def initialize(url)
      @url = url.to_s.strip
    end

    # Returns the cleaned query string, or nil if the URL is invalid.
    def normalize
      uri = parse_uri
      return nil unless valid_inat_observations_uri?(uri)

      clean_query(uri.query)
    end

    private

    def parse_uri
      URI.parse(@url)
    rescue URI::InvalidURIError
      nil
    end

    def valid_inat_observations_uri?(uri)
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)

      expected_path = VALID_HOSTS_AND_PATHS[uri.host]
      expected_path && uri.path == expected_path
    end

    def clean_query(raw_query)
      params = Rack::Utils.parse_query(raw_query.to_s)
      params.except!(*STRIP_PARAMS)
      params.sort.to_h.to_query
    end
  end
end

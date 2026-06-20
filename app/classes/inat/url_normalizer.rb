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

    # Pagination and display params that appear routinely in UI search URLs.
    # Stripped silently — no warning shown — when the URL is from
    # www.inaturalist.org, since they're expected cruft from the browser.
    UI_NOISE_PARAMS = %w[order order_by page per_page subview view].freeze

    # Params MO always controls; strip them so the user's URL doesn't conflict.
    STRIP_PARAMS = [
      # This param yields unexpectedly broad results for Collection Projects
      # https://github.com/MushroomObserver/mushroom-observer/pull/4478#issuecomment-4702380313
      "apply_project_rules_for",
      # Makes normalization/ignored-param warnings match actual import behavior
      # The job strips `id` param in page_parser
      # (User should use ID mode, not URL mode, to import specific obs)
      "id",
      # We need the entire observation, not just a list of IDs
      "only_id",
      # ImportJob relies on order=asc, order_by=id
      "order",
      "order_by",
      # ImportJob controls pagination; no reason for users to specify these
      "page",
      "per_page",
      # UI-only param, would make API return 0 results
      "subview",
      # Don't let users mess with cache control
      "ttl",
      # UI-only param, would make API return 0 results
      "view",
      # We use without_field to avoid re-import of imported or mirrored obss
      "without_field"
    ].freeze

    def initialize(url, superimporter: false, import_others: false,
                   keep_taxon_id: false)
      @url            = url.to_s.strip
      @superimporter  = superimporter
      @import_others  = import_others
      @keep_taxon_id  = keep_taxon_id
    end

    # Returns the cleaned query string, or nil if the URL is invalid.
    def normalize
      uri = parse_uri
      return nil unless valid_inat_observations_uri?(uri)

      clean_query(uri.query)
    end

    # Returns names of user-supplied params that will be stripped, or nil
    # if the URL is not a valid iNat observations URL. Params that are routine
    # UI noise (pagination/display) are excluded when the URL comes from the
    # www.inaturalist.org site — they're expected and not worth warning about.
    def ignored_params
      uri = parse_uri
      return nil unless valid_inat_observations_uri?(uri)

      parsed = Rack::Utils.parse_query(uri.query.to_s)
      all_strips = STRIP_PARAMS + context_strip_params +
                   content_strip_params(parsed)
      # taxon_id is never reported in the generic "ignored params" warning —
      # when stripped, the controller gives a more specific message instead;
      # when kept, it is not stripped so it wouldn't appear anyway.
      silent = (ui_url?(uri) ? UI_NOISE_PARAMS.dup : []) + ["taxon_id"]
      parsed.keys & (all_strips - silent)
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

    def ui_url?(uri)
      uri.host == "www.inaturalist.org"
    end

    def context_strip_params
      strips = []
      # user_login is only meaningful in import-others mode — the inat_username
      # field controls whose observations to import in own-import mode.
      strips += ["user_login"] unless @superimporter && @import_others
      strips += ["licensed"] if @superimporter || @import_others
      strips
    end

    def clean_query(raw_query)
      params = Rack::Utils.parse_query(raw_query.to_s)
      params.except!(*STRIP_PARAMS, *context_strip_params,
                     *content_strip_params(params))
      params.sort.to_h.to_query
    end

    # taxon_id: strip unless all values are importable (Fungi/Slime Molds).
    # user_id: safe for superimporters importing others' obs
    # strip if user_login is also present to prevent iNat from ORing the two.
    def content_strip_params(params)
      strips = @keep_taxon_id ? [] : ["taxon_id"]
      if @superimporter && @import_others && !params.key?("user_login")
        return strips
      end

      strips + ["user_id"]
    end
  end
end

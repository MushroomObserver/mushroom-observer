# frozen_string_literal: true

class Inat
  # Get one page of observations results from the iNat API,
  # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
  # returning a parsed JSON object.
  class PageParser
    include Inat::Constants

    attr_accessor :last_import_id

    delegate :inat_ids, to: :@import
    delegate :user, to: :@import

    def initialize(import, per_page: 200)
      @import = import
      @per_page = per_page
      @last_import_id = 0
      return if import.adequate_constraints?

      # A belt-and-suspenders safety measure to prevent runaway imports
      raise(
        ArgumentError.new(
          "PageParser called with InatImport which lacks adequate constraints"
        )
      )
    end

    # Get next page of iNat API results, using per_page & id_above params.
    # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
    # NOTE: The `ids` parameter may be a comma-separated list of iNat obs
    # ids - that needs to be URL encoded to a string when passed as an arg here
    # because URI.encode_www_form deals with arrays by passing the same key
    # multiple times.
    # https://stackoverflow.com/a/11251654/3357635
    def next_page
      result = if url_mode?
                 next_url_request(id_above: @last_import_id)
               else
                 next_request(id: inat_ids, id_above: @last_import_id)
               end
      return nil if response_bad?(result)
      return nil if result.body.blank?

      JSON.parse(result)
    end

    private

    def url_mode?
      @import.inat_url.present?
    end

    def response_bad?(response)
      response.is_a?(::RestClient::RequestFailed) ||
        response.instance_of?(::RestClient::Response) && response.code != 200 ||
        # RestClient was happy, but the user wasn't authorized
        response.is_a?(Hash) && response[:status] == 401
    end

    def next_request(**args)
      query_args = base_query_args.merge(args)
      add_ownership_filter(query_args)
      headers = { authorization: "Bearer #{@import.token}", accept: :json }

      Inat::APIRequest.new(@import.token).
        request(path: "observations?#{query_args.to_query}", headers: headers)
    rescue ::RestClient::ExceptionWithResponse => e
      error = { error: e.http_code, query: query_args.to_json }.to_json
      @import.add_response_error(error)
      e.response
    end

    # Build a request from the user-supplied URL query string, merged with
    # MO's required safety params. without_field and pagination params always
    # win; taxon_id falls back to IMPORTABLE_TAXON_IDS_ARG only when the user
    # did not supply a validated taxon filter.
    def next_url_request(id_above:)
      query_args = url_request_query_args(id_above: id_above)
      add_ownership_filter(query_args)
      headers = { authorization: "Bearer #{@import.token}", accept: :json }

      Inat::APIRequest.new(@import.token).
        request(path: "observations?#{query_args.to_query}", headers: headers)
    rescue ::RestClient::ExceptionWithResponse => e
      error = { error: e.http_code, query: query_args.to_json }.to_json
      @import.add_response_error(error)
      e.response
    end

    def url_request_query_args(id_above:)
      args = Rack::Utils.parse_query(@import.inat_url).symbolize_keys
      # Honor the URL's id_above only for the first page (internal cursor
      # still at 0). After the first page the internal cursor takes over.
      effective_id_above = id_above.zero? ? args[:id_above].to_i : id_above
      # The confirm round-trip stores the normalized query string as a hidden
      # field, bypassing URLNormalizer. Strip MO-controlled keys defensively.
      strip_keys = Inat::URLNormalizer::STRIP_PARAMS.map(&:to_sym) + [:id]
      args.except!(*strip_keys)
      args.merge!(without_field_filter(ids_mode: false))
      args[:taxon_id] ||= IMPORTABLE_TAXON_IDS_ARG
      args.merge!(id_above: effective_id_above, per_page: @per_page,
                  order: "asc", order_by: "id")
      args
    end

    def base_query_args
      {
        id: nil, id_above: nil, only_id: false, per_page: @per_page,
        order: "asc", order_by: "id",
        taxon_id: IMPORTABLE_TAXON_IDS_ARG
      }.merge(without_field_filter(ids_mode: inat_ids.present?))
    end

    # without_field excludes obs already carrying iNat's "Mushroom Observer
    # URL" field. Explicit id lists always re-check (the user pointed at
    # specific obs, and the importer's ExternalLink gate decides); query
    # modes re-check only when the user opted in via the recheck_all
    # checkbox (#4565 orphan reimport).
    def without_field_filter(ids_mode:)
      return {} if ids_mode || @import.recheck_all?

      BASE_FILTER_PARAMS
    end

    # When importing own observations: scope by user_login, no licensed filter.
    # When importing others' observations (superimporter): require licensed,
    # no user_login — the licensed + taxon filters are the safety constraints.
    def add_ownership_filter(query_args)
      if @import.import_others
        query_args.merge!(LICENSED_FILTER)
      else
        query_args[:user_login] = @import.inat_username
      end
    end
  end
end

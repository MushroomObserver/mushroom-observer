# frozen_string_literal: true

class Inat
  # Get one page of observations results (up to 200) from the iNat API,
  # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
  # returning a parsed JSON object.
  class PageParser
    include Inat::Constants

    attr_accessor :last_import_id

    delegate :inat_ids, to: :@import
    delegate :user, to: :@import

    def initialize(import)
      @import = import
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
      result = next_request(id: inat_ids, id_above: @last_import_id)
      return nil if response_bad?(result)
      return nil if result.body.blank?

      JSON.parse(result)
    end

    private

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

    def base_query_args
      {
        id: nil, id_above: nil, only_id: false, per_page: 200,
        order: "asc", order_by: "id",
        taxon_id: IMPORTABLE_TAXON_IDS_ARG
      }.merge(BASE_FILTER_PARAMS)
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

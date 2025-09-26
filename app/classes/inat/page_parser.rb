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
      query_args = {
        id: nil, id_above: nil, only_id: false, per_page: 200,
        order: "asc", order_by: "id",
        # obss of only the iNat user with iNat login @inat_import.inat_username
        # Prevents accidentally importing observations of multiple users
        user_login: @import.inat_username,
        # only fungi and slime molds
        iconic_taxa: ICONIC_TAXA,
        # and which haven't been exported from or inported to MO
        without_field: "Mushroom Observer URL"
      }.merge(args)
      # But allow super importers to import obss of any iNat user
      if InatImport.super_importers.include?(user)
        query_args.delete(:user_login)
      end
      headers = { authorization: "Bearer #{@import.token}", accept: :json }
      Inat::APIRequest.new(@import.token).
        request(path: "observations?#{query_args.to_query}", headers: headers)
    rescue ::RestClient::ExceptionWithResponse => e
      error = { error: e.http_code, query: query_args.to_json }.to_json
      @import.add_response_error(error)
      e.response
    end
  end
end

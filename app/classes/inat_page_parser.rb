# frozen_string_literal: true

class InatPageParser
  attr_accessor :last_import_id

  # The iNat API
  API_BASE = Observations::InatImportsController::API_BASE
  # limit results iNat API requests, with Protozoa as a proxy for slime molds
  ICONIC_TAXA = "Fungi,Protozoa"

  def initialize(importer, ids)
    @importer = importer
    @last_import_id = 0
    @ids = ids
  end

  # Get one page of observations (up to 200)
  # This is where we actually hit the iNat API
  # https://api.inaturalist.org/v1/docs/#!/Observations/get_observations
  # https://stackoverflow.com/a/11251654/3357635
  # NOTE: The `ids` parameter may be a comma-separated list of iNat obs
  # ids - that needs to be URL encoded to a string when passed as an arg here
  # because URI.encode_www_form deals with arrays by passing the same key
  # multiple times.
  def next_page
    result = next_request
    return nil if response_bad?(result)

    JSON.parse(result)
  end

  private

  def response_bad?(response)
    response.is_a?(RestClient::RequestFailed) ||
      response.instance_of?(RestClient::Response) && response.code != 200 ||
      # RestClient was happy, but the user wasn't authorized
      response.is_a?(Hash) && response[:status] == 401
  end

  def next_request
    query_args = {
      id: @ids, id_above: @last_import_id, only_id: false, per_page: 200,
      order: "asc", order_by: "id",
      # obss of only the iNat user with iNat login @importer.inat_username
      user_login: @importer.inat_username,
      iconic_taxa: ICONIC_TAXA
    }

    query = URI.encode_www_form(query_args)

    # ::Inat.new(operation: query, token: @inat_import.token).body
    # Nimmo 2024-06-19 jdc. Moving the request from the inat class to here.
    # RestClient::Request.execute wasn't available in the class
    headers = { authorization: "Bearer #{@importer.token}", accept: :json }
    RestClient::Request.execute(
      method: :get, url: "#{API_BASE}/observations?#{query}", headers: headers
    )
  rescue RestClient::ExceptionWithResponse => e
    @importer.add_response_error(e.response)
    e.response
  end
end

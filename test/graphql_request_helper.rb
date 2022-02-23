# frozen_string_literal: true

require("graphql_queries")

# Helper module for testing full HTTP requests (as opposed to Schema.execute)
module GraphQLRequestHelper
  include GraphQLQueries

  # Must set this to get thru robot filter
  def setup
    @headers = {}
    @headers["User-Agent"] = "iPadApp"
    @headers["Content-type"] = "application/json"
  end

  # Add a token if we have one
  def headers_with_auth(token)
    return @headers unless token

    headers = @headers
    headers["Authorization"] = "Bearer #{token}"
    headers
  end

  def graphql_path
    "/graphql"
  end

  # Parse the response body
  def json
    JSON.parse(response.body)
  end

  # Graphql request with the `query` and `variables` defaults.
  def do_graphql_request(user: nil, qry: nil, var: nil, token: nil)
    token ||= Token.new(user_id: user&.id,
                        in_admin_mode: user&.admin).encrypt_to_header

    params = {
      query: qry || query,
      variables: var || variables
    }

    post(graphql_path,
         params: params.to_json,
         headers: headers_with_auth(token))
  end

  # Give variables an empty default
  def variables
    {}
  end
end

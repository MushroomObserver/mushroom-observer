# frozen_string_literal: true

require("graphql_queries")

# Helper module for testing Schema.execute (as opposed to HTTP requests)
module GraphQLExecuteHelper
  include GraphQLQueries

  def do_graphql(user: nil, qry: nil, var: nil, adm: nil)
    context = {
      current_user: user,
      in_admin_mode?: adm
    }

    MushroomObserverSchema.execute(
      query: qry,
      variables: var,
      context: context
    )
  end
end

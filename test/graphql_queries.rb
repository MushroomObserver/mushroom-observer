# frozen_string_literal: true

module GraphQLQueries
  def nonsense_query
    <<-GRAPHQL
    query nonsense { nonsense } 
    GRAPHQL
  end

  # Add to these by pasting valid queries from public/graphql/schema.graphql
  # Refresh current schema with rails graphql:dump_schema
  def visitor_query
    <<-GRAPHQL
    query visitor { 
      visitor { 
        login 
      }, 
      admin
    }
    GRAPHQL
  end

  def user_query
    <<-GRAPHQL
      query($id: Int, $login: String, $name: String){
        user(id: $id, login: $login, name: $name) {
          id
          name
          login
          email
          emailNamesEditor
        }
      }
    GRAPHQL
  end

  def user_login
    <<-GRAPHQL
    mutation userLogin($input: UserLoginInput!){
      userLogin( input: $input ){
        user {
          id,
          login
        },
        token
      }
    }
    GRAPHQL
  end
end

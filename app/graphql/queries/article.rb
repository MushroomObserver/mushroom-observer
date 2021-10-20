# app/graphql/queries/article.rb
module Queries
  class Article < Queries::BaseQuery
    description "get article by id"
    type Types::Models::Article, null: false
    argument :id, Integer, required: true

    def resolve(id:)
      ::Article.find(id)
    end
  end
end

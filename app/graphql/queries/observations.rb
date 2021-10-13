# app/graphql/queries/observations.rb
require("search_object")
require("search_object/plugin/graphql")

module Queries
  class Observations < Queries::BaseQuery
    # include SearchObject for GraphQL
    include SearchObject.module(:graphql)

    description "list all observations"
    # type [Types::ObservationType], null: false
    type types[Types::ObservationType], null: false

    # scope is starting point for search
    scope { Observation.all }

    # Keeping it as a filter rather than top-level options,
    # so pagination can be added later if necessary
    # # taxa: search for like string in name.text_name
    # option :name_id, Int, required: false, with: :name_id_filter,
    #        description: "Taxon by ID. Can use with select/autocomplete for names(taxa)"
    # option :name_like, String, required: false, with: :name_filter,
    #        description: "Fuzzy text search of taxon name"
    # option :user_id, Integer, required: false, with: :user_id_filter,
    #        description: "User by ID. Can use with select/populated-autocomplete for users"
    # option :user_like, String, required: false, with: :user_filter,
    #        description: "Fuzzy text search of user name, slower query than by ID"
    # # must search string for location, becase locations are not geospatially nested.
    # option :where, String, required: false, with: :where_filter,
    #        description: "Fuzzy text search of location name" # == location.name
    # option :when, GraphQL::Types::ISO8601Date, required: false, with: :when_filter
    # option :notes, String, required: false, with: :user_id_filter,
    #        description: "Fuzzy text search of notes"
    # option :image, Types::EitherWithWithout, required: false, with: :user_id_filter,
    #        description: "With image, without image, or either"
    # option :specimen, Types::EitherWithWithout, required: false, with: :user_id_filter,
    #        description: "With specimen, without specimen, or either"
    # option :lichen, Types::EitherWithWithout, required: false, with: :user_id_filter,
    #        description: "With lichen, without lichen, or either"

    # def name_filter(scope, value)
    #   scope.where("text_name LIKE ?", "%#{value}%")
    # end

    # def when_filter(scope, value)
    # end

    # inline input type definition for the advanced filter
    class ObservationFilter < ::Types::BaseInputObject
      # argument :OR, [self], required: false
      # alternative: use select w/ autocomplete for taxa
      argument :name_id, Int, required: false
      # taxa: search for like string in name.text_name
      argument :name_like, String, required: false
      # use select w/ autocomplete and force an ID
      argument :user_id, Integer, required: false
      # alternative: search for string in user.name? expensive query
      argument :user_like, String, required: false
      # must search string for location, becase locations are not nested.
      argument :where, String, required: false # this is location.name
      argument :before, Boolean, required: false
      argument :when, GraphQL::Types::ISO8601Date, required: false
      argument :notes, String, required: false
      argument :image, Types::EitherWithWithout, required: false # with, without, or either
      argument :specimen, Types::EitherWithWithout, required: false # with, without or either
      argument :lichen, Types::EitherWithWithout, required: false # with, without or either
    end

    # when "filter" is passed "apply_filter" would be called to narrow the scope
    # note this example was conceived as an OR filter, we could set the filter args as options directly
    option :filter, type: ObservationFilter, description: "Filtered observation search" do |scope, value|
      if value[:name_like]
        scope = scope.where("text_name LIKE ?", "%#{value[:name_like]}%")
      end

      scope = scope.where("where LIKE ?", "%#{value[:where]}%") if value[:where]
      scope = scope.where("notes LIKE ?", "%#{value[:notes]}%") if value[:notes]
    end
  end
end

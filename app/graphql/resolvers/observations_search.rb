require("search_object")
require("search_object/plugin/graphql")

class Resolvers::ObservationsSearch < GraphQL::Schema::Resolver
  # include SearchObject for GraphQL
  include SearchObject.module(:graphql)

  # scope is starting point for search
  scope { Observation.all }

  type types[Types::ObservationType], null: false

  # inline input type definition for the advanced filter
  class ObservationFilter < ::Types::BaseInputObject
    # argument :OR, [self], required: false
    # taxa: search for like string in name.text_name
    argument :text_name, String, required: false
    # alternative: use select w/ autocomplete for taxa
    # argument :name_id, Int, required: false
    # use select w/ autocomplete and force an ID
    argument :user_id, Integer, required: false
    # alternative: search for string in user.name? expensive query
    # argument :user_like, String, required: false
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
  option :filter, type: ObservationFilter, with: :apply_filter

  # apply_filter recursively loops through "OR" branches
  def apply_filter(scope, value)
    branches = normalize_filters(value).reduce { |a, b| a.or(b) }
    scope.merge(branches)
  end

  def normalize_filters(value, branches = [])
    scope = Observation.all
    if value[:text_name]
      scope = scope.where("text_name LIKE ?", "%#{value[:text_name]}%")
    end
    scope = scope.where("url LIKE ?", "%#{value[:where]}%") if value[:where]
    scope = scope.where("notes LIKE ?", "%#{value[:notes]}%") if value[:notes]

    branches << scope

    # if value[:OR].present?
    #   value[:OR].reduce(branches) { |s, v| normalize_filters(v, s) }
    # end

    branches
  end
end

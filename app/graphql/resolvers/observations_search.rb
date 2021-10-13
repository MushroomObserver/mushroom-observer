require("search_object")
require("search_object/plugin/graphql")

class Resolvers::ObservationsSearch
  # include SearchObject for GraphQL
  include SearchObject.module(:graphql)

  # scope is starting point for search
  scope { Observation.all }

  type types[Types::ObservationType]

  # inline input type definition for the advanced filter
  class ObservationFilter < ::Types::BaseInputObject
    argument :OR, [self], required: false
    # search for like string in name.text_name
    argument :text_name, String, required: false
    # alternative: use select w/ autocomplete for taxa
    # argument :name_id, Int, required: false
    # use select w/ autocomplete and force an ID
    argument :user_id, Integer, required: false
    # alternative: search for string in user.name? expensive query
    # argument :user_like, String, required: false
    # must search string for location, becase locations are not nested.
    argument :where, String, required: false # this is location.name
    argument :when, GraphQL::Types::ISO8601Date, required: false
    argument :notes, String, required: false # this is location.name
    argument :with_image, Boolean, required: false # this is location.name
    argument :without_image, Boolean, required: false # this is location.name
    argument :with_specimen, Boolean, required: false # this is location.name
    argument :without_specimen, Boolean, required: false # this is location.name
    argument :lichen, Boolean, required: false # this is location.name
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
    if value[:description_contains]
      scope = scope.where("description LIKE ?", "%#{value[:description_contains]}%")
    end
    if value[:url_contains]
      scope = scope.where("url LIKE ?", "%#{value[:url_contains]}%")
    end

    branches << scope

    if value[:OR].present?
      value[:OR].reduce(branches) { |s, v| normalize_filters(v, s) }
    end

    branches
  end
end

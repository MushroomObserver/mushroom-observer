require("search_object")
require("search_object/plugin/graphql")

module Resolvers
  class ObservationsSearch < GraphQL::Schema::Resolver
    # include SearchObject for GraphQL
    include SearchObject.module(:graphql)

    description "List or filter all observations"

    # scope is starting point for search
    scope { Observation.all }

    type types[Types::ObservationType], null: false

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
      # argument :user_like, String, required: false
      # must search string for location, becase locations are not nested.
      argument :where, String, required: false # where == location.name
      argument :before, Boolean, required: false
      argument :when, GraphQL::Types::ISO8601Date, required: false
      argument :notes_like, String, required: false
      argument :with_image, Boolean, required: false # with, without, or either
      argument :with_specimen, Boolean, required: false # with, without or either
      argument :with_lichen, Boolean, required: false # with, without or either
    end

    # when "filter" is passed "apply_filter" would be called to narrow the scope
    # note this example was conceived as an OR filter, we could set the filter args as options directly
    option :filter, type: ObservationFilter, with: :apply_filter

    # apply_filter recursively loops through "OR" branches
    def apply_filter(scope, value)
      branches = normalize_filters(value).reduce { |a, b| a.or(b) }
      scope.merge(branches)
    end

    def normalize_filters(value, branches = [])
      scope = Observation.all
      scope = scope.where("name_id = ?", value[:name_id]) if value[:name_id]
      if value[:name_like]
        scope = scope.where("text_name LIKE ?", "%#{value[:name_like]}%")
      end
      scope = scope.where("user_id = ?", value[:user_id]) if value[:user_id]
      # This one now a prob?
      scope = scope.where("where LIKE ?", "%#{value[:where]}%") if value[:where]
      if value[:when]
        scope = if value[:before]
                  scope.where("created_at <= ?", value[:when])
                else
                  scope.where("created_at >= ?", value[:when])
                end
      end
      if value[:notes_like]
        scope = scope.where("notes LIKE ?", "%#{value[:notes_like]}%")
      end
      case value[:with_image]
      when true
        # puts("___________________________#{value[:with_image]} IMAGE")
        scope = scope.where.not("thumb_image_id IS NOT NULL")
      when false
        # puts("___________________________#{value[:with_image]} IMAGE")
        scope = scope.where("thumb_image_id IS NULL")
      else
        # puts("___________________________EITHER IMAGE")
      end
      case value[:with_specimen]
      when true
        scope = scope.where("specimen IS TRUE")
      when false
        # puts("___________________________#{value[:with_specimen]} SPECIMEN")
        scope = scope.where("specimen IS FALSE")
      end
      case value[:with_lichen]
      # Note the critical difference -- the extra spaces in the negative
      # version.  This allows all lifeforms containing the word "lichen" to be
      # selected for in the positive version, but only excudes the one lifeform
      # in the negative.
      when true
        scope = scope.where("lifeform LIKE '%lichen%'")
      when false
        scope = scope.where("lifeform NOT LIKE '% lichen %'")
      end

      branches << scope

      # if value[:OR].present?
      #   value[:OR].reduce(branches) { |s, v| normalize_filters(v, s) }
      # end

      branches
    end
  end
end

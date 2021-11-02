require("search_object")
require("search_object/plugin/graphql")

# frozen_string_literal: true

module Resolvers
  class Observations < Resolvers::BaseSearchResolver
    type Types::Models::ObservationType.connection_type, null: false
    description "List or filter all observations"

    # scope is starting point for search
    scope { object.respond_to?(:observations) ? object.observations : Observation.all }

    option :filter, type: Inputs::Observation::Filters, with: :apply_filter

    # apply_filter recursively loops through "OR" branches
    def apply_filter(scope, value)
      # scope = scope
      scope = scope.where("name_id = ?", value[:name_id]) if value[:name_id]
      if value[:name_like]
        scope = scope.where("`text_name` LIKE ?", escape_search_term(value[:name_like]))
      end
      scope = scope.where("user_id = ?", value[:user_id]) if value[:user_id]
      # This one now a prob?
      if value[:where]
        scope = scope.where("`where` LIKE ?", escape_search_term(value[:where]))
      end
      if value[:when]
        scope = if value[:before]
                  scope.where("created_at <= ?", value[:when])
                else
                  scope.where("created_at >= ?", value[:when])
                end
      end
      if value[:notes_like]
        scope = scope.where("notes LIKE ?", escape_search_term(value[:notes_like]))
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
      scope
    end
  end
end

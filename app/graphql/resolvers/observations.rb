# frozen_string_literal: true

module Resolvers
  class Observations < Resolvers::BaseSearchResolver
    type [Types::Models::ObservationType.connection_type], null: false
    description "List or filter all observations"

    # scope is starting point for search
    # scope { object.respond_to?(:observations) ? object.observations : Observation.all }
    scope { ::Observation.all }

    option :filter, type: Inputs::Observation::Filters, with: :apply_filter
    option :order, type: Types::Enums::OrderBy, default: "WHEN"
    # def resolve
    #   ::Observation.all.order(created_at: :desc)
    #   GraphQL::Connections::Stable.new(Observation.all, keys: %W[#{column_name} id], desc: true)
    # end

    # def apply_order_with_votes(scope)
    #   scope.order("votes DESC")
    # end

    # def apply_order_with_image_votes(scope)
    #   scope.order("image_votes DESC")
    # end

    # apply_filter recursively loops through "OR" branches
    def apply_filter(scope, value)
      scope = scope.where(name_id: value[:name_id]) if value[:name_id]
      if value[:name_like]
        observation_name = ::Observation.arel_table[:text_name]
        scope = scope.where(observation_name.matches("%#{value[:name_like]}%"))
      end
      scope = scope.where(user_id: value[:user_id]) if value[:user_id]
      # # This one now a prob?
      if value[:location_like]
        observation_where = ::Observation.arel_table[:where]
        scope = scope.where(observation_where.matches("%#{value[:location_like]}%"))
      end
      if value[:when]
        observation_when = ::Observation.arel_table[:when]
        scope = if value[:before]
                  scope.where(observation_when.lteq(value[:when]))
                else
                  scope.where(observation_when.gteq(value[:when]))
                end
      end
      if value[:notes_like]
        observation_notes = ::Observation.arel_table[:notes]
        scope = scope.where(observation_where.matches("%#{value[:notes_like]}%"))
      end
      if value[:with_image]
        observation_image = ::Observation.arel_table[:thumb_image_id]
        case value[:with_image]
        when true
          # puts("___________________________#{value[:with_image]} IMAGE")
          scope = scope.where(observation_image.not_eq(nil))
        when false
          # puts("___________________________#{value[:with_image]} IMAGE")
          scope = scope.where(observation_image.eq(nil))
        end
      end
      if value[:with_specimen]
        observation_specimen = ::Observation.arel_table[:specimen]
        case value[:with_specimen]
        when true
          scope = scope.where(observation_specimen.eq(true))
        when false
          # puts("___________________________#{value[:with_specimen]} SPECIMEN")
          scope = scope.where(observation_specimen.eq(false))
        end
      end
      if value[:with_lichen]
        observation_lifeform = ::Observation.arel_table[:lifeform]
        case value[:with_lichen]
        # Note the critical difference -- the extra spaces in the negative
        # version.  This allows all lifeforms containing the word "lichen" to be
        # selected for in the positive version, but only excudes the one lifeform
        # in the negative.
        when true
          scope = scope.where(observation_lifeform.matches("%lichen%"))
        when false
          scope = scope.where(observation_lifeform.does_not_match("% lichen %"))
        end
      end
      scope
    end

    def apply_order_with_when(scope)
      scope.order("`when` DESC")
      # column_name = "when"
      # GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: true)
    end

    def apply_order_with_created_at(scope)
      scope.order("`created_at` DESC")
      # column_name = "created_at"
      # GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: true)
    end

    def apply_order_with_updated_at(scope)
      scope.order("`updated_at` DESC")
      # column_name = "updated_at"
      # GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: true)
    end

    def apply_order_with_text_name(scope)
      scope.order("`text_name` DESC")
      # column_name = "text_name"
      # GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: true)
    end
  end
end

# frozen_string_literal: true

module Resolvers
  class Observations < Resolvers::BaseResolver
    type [Types::Models::ObservationType.connection_type], null: false
    description "List or filter all observations"

    argument :filter, type: Inputs::Observation::Filters, required: false
    argument :order_by, type: Types::Enums::OrderBy, required: false
    argument :order, type: Types::Enums::Order, required: false

    def resolve(filter: nil, order_by: "WHEN", order: "DESC")
      observations = ::Observation.arel_table
      scope = ::Observation.select(observations[Arel.star])

      if filter
        if filter[:name_id]
          scope = scope.where(observations[:name_id].eq(filter[:name_id]))
        end

        if filter[:name_like]
          scope = scope.where(observations[:text_name].matches("%#{filter[:name_like]}%"))
        end

        if filter[:user_id]
          scope = scope.where(observations[:user_id].eq(filter[:user_id]))
        end

        if filter[:location_like]
          scope = scope.where(observations[:where].matches("%#{filter[:location_like]}%"))
        end

        if filter[:when]
          scope = if filter[:before]
                    scope.where(observations[:when].lteq(filter[:when]))
                  else
                    scope.where(observations[:when].gteq(filter[:when]))
                  end
        end

        if filter[:notes_like]
          scope = scope.where(observations[:notes].matches("%#{filter[:notes_like]}%"))
        end

        if filter[:with_image]
          case filter[:with_image]
          when true
            scope = scope.where(observations[:thumb_image_id].not_eq(nil))
          when false
            scope = scope.where(observations[:thumb_image_id].eq(nil))
          end
        end

        if filter[:with_specimen]
          case filter[:with_specimen]
          when true
            scope = scope.where(observations[:specimen].eq(true))
          when false
            scope = scope.where(observations[:specimen].eq(false))
          end
        end

        if filter[:with_lichen]
          case filter[:with_lichen]
          # Note the critical difference -- the extra spaces in the negative
          # version.  This allows all lifeforms containing the word "lichen" to be
          # selected for in the positive version, but only excudes the one lifeform
          # in the negative.
          when true
            scope = scope.where(observation[:lifeform].matches("%lichen%"))
          when false
            scope = scope.where(observation[:lifeform].does_not_match("% lichen %"))
          end
        end
      end

      column_name = if order_by
                      case order_by
                      when "CREATED_AT"
                        "created_at"
                      when "UPDATED_AT"
                        "updated_at"
                      when "TEXT_NAME"
                        "text_name"
                      else
                        "when"
                                    end
                    else
                      "when"
                    end

      desc = if order
               case order
               when "ASC"
                 false
               when "DESC"
                 true
               end
             else
               true
             end

      GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: desc)
    end
  end
end

# frozen_string_literal: true

module Resolvers
  class Names < Resolvers::BaseResolver
    type [Types::Models::NameType.connection_type], null: false
    description "List or filter all names"

    argument :filter, type: Inputs::Name::Filters, required: false

    def resolve(filter: nil)
      names = ::Name.arel_table
      scope = ::Name.select(names[Arel.star])
      column_name = "when"
      desc = true

      if filter
        if filter[:name_id]
          scope = scope.where(names[:name_id].eq(filter[:name_id]))
        end

        if filter[:name_like]
          scope = scope.where(names[:text_name].matches("%#{filter[:name_like]}%"))
        end

        if filter[:user_id]
          scope = scope.where(names[:user_id].eq(filter[:user_id]))
        end

        if filter[:location_like]
          scope = scope.where(names[:where].matches("%#{filter[:location_like]}%"))
        end

        if filter[:when]
          scope = if filter[:before]
                    scope.where(names[:when].lteq(filter[:when]))
                  else
                    scope.where(names[:when].gteq(filter[:when]))
                  end
        end

        column_name = if filter[:order_by]
                        case filter[:order_by]
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

        desc = if filter[:order]
                 case filter[:order]
                 when "ASC"
                   false
                 when "DESC"
                   true
                 end
               else
                 true
               end
      end

      GraphQL::Connections::Stable.new(scope, keys: %W[#{column_name} id], desc: desc)
    end
  end
end

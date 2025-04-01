# frozen_string_literal: true

module RssLog::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    scope :order_by_default,
          -> { order_by(::Query::RssLogs.default_order) }

    scope :type, lambda { |types|
      return all if types.to_s == "all"

      types = types.to_s.split unless types.is_a?(Array)
      types &= ALL_TYPE_TAGS.map(&:to_s)
      return none if types.empty?

      types.map! { |type| arel_table[:"#{type}_id"].not_eq(nil) }
      where(or_clause(*types)).distinct
    }

    # Apply content filters to all types of RssLog requested in the current
    # Query. NOTE: One content filter may apply to two or more types (e.g.
    # `:region` applies to both Observations and Locations), so we need to
    # build a query where each type of RssLog is filtered separately.
    #
    # Query itself calls this scope because it has all the current query params,
    # and because Query::Filter knows what all the possible filter params are.
    # We probably wouldn't call this scope elsewhere, except from a test.
    #
    scope :content_filters, lambda { |params|
      return all if params.blank?

      scope = all
      # `type` here is a model
      filterable_types_in_current_query(params).each do |type|
        type_filters = active_filters_for_model(params, type)
        next if type_filters.blank?

        # Join association is singular for all RssLog associations
        association = type.name.underscore
        # "logs that are not of this type, or if they are, then filtered"
        scope = scope.
                left_outer_joins(:"#{association}").
                where("#{association}_id": nil).distinct.
                or(RssLog.merge(filter_conditions_for_type(type, type_filters)))
      end
      scope
    }
  end

  module ClassMethods
    # class methods here, `self` included
    def self.filtering_statements(params)
      # `type` here is a model (var name `model` unavailable)
      filterable_types_in_current_query(params).map do |type|
        type_filters = active_filters_for_model(params, type)
        next if type_filters.blank?

        # Join association is singular for all RssLog associations
        association = type.name.underscore
        # Returns "logs that are not of this type, or if they are, then filtered"
        left_outer_joins(:"#{association}").
          where("#{association}_id": nil).distinct.
          or(RssLog.merge(filter_conditions_for_type(type, type_filters)))
      end
    end

    # Types requested in the current RssLog query that may have content filters
    # applied. Defaults to :all. Returns an array of model classes.
    def self.filterable_types_in_current_query(params)
      filterable_types = [:observation, :name, :location]
      active_types = case params[:type]
                     when nil, "", :all, "all"
                       filterable_types
                     when Array
                       params[:type]
                     when String
                       params[:type].split
                     end
      active_types.map { |type| type.to_s.camelize.constantize }
    end

    # Find any active filters relevant to a model, using Query::Filter.by_model.
    # Returns a hash of only the relevant params.
    def self.active_filters_for_model(params, model)
      ::Query::Filter.by_model(model).
        each_with_object({}) do |fltr, filter_params|
          next if (val = params[fltr.sym]).to_s == ""

          filter_params[fltr.sym] = val
        end
    end

    # Build a scope statement for one type (model).
    def self.filter_conditions_for_type(type, type_filters)
      # Condense all filters into an array of AR scope statements
      conditions_for_type = type_filters.reduce([]) do |conds, (k, v)|
        conds << type.send(k, v).distinct
      end
      # Join the array of conditions by `and`.
      and_clause(*conditions_for_type).distinct
    end
  end
end

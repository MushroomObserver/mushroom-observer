# frozen_string_literal: true

##############################################################################
#
#  :module: Subqueries
#
#  Subqueries are a way to filter one model via subquery of an associated model.
#  They're mostly used by links on indexes that offer conversion of, say, an
#  Observation query into a Name or Location query.
#
#  NOTE: Subqueries currently short-circuit any recursion. For example, if you
#  search for "Observations of Amanita in Massachusetts", then query "Names of
#  these Observations", and then "Observations of these Names" (to find all the
#  places where Massachusetts Amanita are found, whether within or outside of
#  Massachusetts), the method `restorable_query` below will not expand your
#  query as you might expect, but return you to your original query.
#
#  == Class methods:
#
#  current_or_related_query:: Convert queries from one model to another; can be
#                             called recursively. To avoid repetitive recursion,
#                             it checks for a nested query that may be for the
#                             intended target model.
#
module Query::Modules::Subqueries
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Query needs to know which joins are necessary to make these conversions
    # work. Need to maintain RELATED_TYPES if the Query class is updated.
    # These could be derived by snooping through each Query subclass's
    # attributes, but that seems wasteful; there are not so many of these.
    #
    # target_model.name.to_sym: [:Association, :AnotherAssociation],
    RELATED_QUERIES = {
      Image: [:Image, :Observation],
      Location: [:Location, :LocationDescription, :Name, :Observation],
      LocationDescription: [:Location],
      Name: [:Name, :NameDescription, :Observation],
      NameDescription: [:Name],
      Observation: [:Image, :Location, :Name, :Observation, :Sequence]
    }.freeze

    def related?(target, filter)
      return false unless RELATED_QUERIES.key?(target)

      RELATED_QUERIES[target].include?(filter)
    end

    def current_or_related_query(target, filter, current_query)
      if target == filter
        current_query
      elsif (restored_query = restorable_query(target, current_query))
        restored_query
      elsif (new_query = new_query_with_subquery(target, filter, current_query))
        new_query
      end
    end

    # Check the query params for a relevant existing query nested within.
    # This only checks for the key name of the right subquery. It would be
    # more work to check for hash equality, because the nested hash has the
    # :model param too, to be easily deserialized and rebuilt.
    # NOTE: Our custom method `deep_find` returns an array of matches.
    def restorable_query(target, current_query)
      subquery_param = current_query.class.find_subquery_param_name(target)
      restorable_query_params = current_query.params.deep_find(subquery_param)
      return false if restorable_query_params.blank?

      lookup(target, restorable_query_params.first)
    end

    # Make a new query using the current_query as the subquery. Note that this
    # will continue nesting queries unless a restorable query is found above.
    def new_query_with_subquery(target, filter, current_query)
      query_class = "Query::#{target.to_s.pluralize}".constantize
      return unless (subquery = query_class.find_subquery_param_name(filter))

      params = current_query.params.compact
      subquery_params = add_default_subquery_conditions(target, filter, params)

      lookup(target, "#{subquery}": subquery_params)
    end

    def find_subquery_param_name(filter)
      key = if filter.to_s.include?("Description")
              :description_query
            else
              :"#{filter.to_s.underscore}_query"
            end
      return key if attribute_types.symbolize_keys.key?(key)

      nil
    end

    def add_default_subquery_conditions(target, filter, params)
      return params unless needs_is_collection_location(target, filter, params)

      params.merge(is_collection_location: true)
    end

    def needs_is_collection_location(target, filter, params)
      target == Location && filter == :Observation &&
        (params[:project] || params[:species_list]) &&
        params[:is_collection_location].blank?
    end
  end
end

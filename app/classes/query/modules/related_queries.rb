# frozen_string_literal: true

# NOTE: Ideally this method could be called on Query.new, so the query caller
# could send any subquery. This method would untangle overly nested subqueries.
#
# A "current_or_related_query" may be called for links:
# (1) for a new query on a related target model, using the current_query as the
#     filtering subquery.
# (2) from an index that itself was the result of a subquery.
#     For example, if you follow links in the current UI from:
#       [target model] of these [filtering model]
#       Observations of these names -> (that's a plain obs query)
#       Locations of these observations -> (location query with an obs_subquery)
#       Map of these locations -> (loc, obs_subquery)
#       Names at these locations -> (name, obs_subquery, obs have the loc)
#       Observations of these names -> (obs query)
#     Note that the last index is really the original query, so to prevent
#     recursive subquery nesting, we always want check for the currently
#     needed (sub)query nested within the params.
# (3) from maps to indexes of the same objects. Returns the current_query.
#
# I'm currently considering these filtering subqueries provisional... they're
# not trying to become the current query, so they're not saved. - AN 2025-02
#
module Query::Modules::RelatedQueries
  def self.included(base)
    base.extend(ClassMethods)
  end

  def relatable?(target)
    self.class.related?(target, model.name.to_sym)
  end

  def subquery_of(target)
    self.class.current_or_related_query(target, model.name.to_sym, self)
  end

  module ClassMethods
    # Query needs to know which joins are necessary to make these conversions
    # work. Need to maintain RELATED_TYPES if the Query class is updated.
    # These could be derived by snooping through each Query subclass's
    # parameter_declarations, but that seems wasteful; there are not so many.
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
    # :model param too, to be easily deserialized and reconstituted.
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

      lookup(target, "#{subquery}": current_query.params.compact)
    end

    def find_subquery_param_name(filter)
      parameter_declarations.key({ subquery: filter })
    end
  end
end

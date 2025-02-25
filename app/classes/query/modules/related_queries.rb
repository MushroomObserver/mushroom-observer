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
  def relatable?(target)
    self.class.related?(target, model.name.to_sym)
  end

  def subquery_of(target)
    self.class.current_or_related_query(target, model.name.to_sym, self)
  end
end

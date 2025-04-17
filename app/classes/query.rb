# frozen_string_literal: true

#  == Query (Factory)
#
#  This class is simply a factory for Query instances. It could maybe be better
#  named QueryFactory, with class methods like `create_query`, but as it is,
#  `Query.new` and `Query.lookup` are a lot more concise.
#
#  NOTE: The `Query::#{Model}` classes do not inherit from this class. They
#        inherit from `Query::Base`, which does not inherit from this either.
#        `Query` acts also as a convenience delegator/accessor for class methods
#        that may be called from outside Query, like `Query.lookup`.
#
class Query
  include Query::Modules::QueryRecords
  include Query::Modules::Subqueries

  def self.new(model, params = {}, current = nil)
    klass = "Query::#{model.to_s.pluralize}".constantize
    # Initialize an instance, ignoring undeclared params:
    query = klass.new(params.slice(*klass.attribute_names.map(&:to_sym)))
    # Initialize `params`, where query stores the active `attributes`.
    query.params = query.attributes.compact
    # Initialize `subqueries`, to store any validated subquery instances.
    query.subqueries = {}
    query.current = current if current
    # Calling `valid?` reinitializes `params` after cleaning/validation.
    query.valid = query.valid?
    # query.initialize_query # if you want the attributes right away
    query
  end
end

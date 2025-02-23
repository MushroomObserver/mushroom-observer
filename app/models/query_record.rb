# frozen_string_literal: true

#  = Query Record Model
#
#  Query Records store the parameters of recent user queries for quicker access.
#  For certain nested queries, the inner and outer queries are stored as
#  separate query_records.
#
#  Used by MO's Query::Modules::ActiveRecord
#
#  == Attributes
#
#  id::             Unique numerical id.
#  updated_at::     Date/time it was last updated.
#  access_count::   Number of times the query record was accessed.
#  description::    Serialized parameters of the query, including the model.
#                   Not using Rails serialization because we use this column to
#                   compare queries, and SQL matching by string is faster.
#
#  == Class methods
#
#  QueryRecord.cleanup::     Removes all query_records older than one day.

# access query records saved in the db
class QueryRecord < ApplicationRecord
  attr_accessor :query

  # This method instantiates a new Query from the description.
  def query # rubocop:disable Lint/DuplicateMethods
    ::Query.deserialize(description)
  end

  # Only keep states around for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    return unless !defined?(@last_cleanup) ||
                  (@last_cleanup < 5.minutes.ago) ||
                  ::Rails.env.test?

    QueryRecord.where(QueryRecord[:updated_at] < 1.day.ago).delete_all

    @last_cleanup = Time.zone.now
  end
end

# frozen_string_literal: true

#  = Query Record Model
#
#  Query Records store the parameters of recent user queries for quicker access.
#  For nested queries, the inner and outer queries are stored as separate
#  query_records. Inner queries store an `outer_id` of the outer query.
#
#  Used by MO's Query::Modules::ActiveRecord
#
#  == Attributes
#
#  id::             Unique numerical id.
#  updated_at::     Date/time it was last updated.
#  access_count::   Number of times the query record was accessed.
#  description::    Serialized parameters of the query.
#  outer_id::       `id` of outer query, when inner query of a nested query.
#
#  == Class methods
#
#  QueryRecord.cleanup::     Removes all query_records older than one day.

# access query records saved in the db
class QueryRecord < ApplicationRecord
  require "arel-helpers"
  include ArelHelpers::ArelTable

  attr_accessor :query

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

# frozen_string_literal: true

#  = Query Record Model
#
#  Query Records save recent queries to the db for quicker access.
#  Used by MO's Query::Modules::ActiveRecord

# access query records saved in the db
class QueryRecord < ApplicationRecord
  attr_accessor :query

  def query # rubocop:disable Lint/DuplicateMethods
    ::Query.deserialize(description)
  end

  # Nimmo Note: Original SQL.
  # DELETE FROM #{table_name}  <-- `query_records`
  # WHERE
  #   access_count = 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 6 HOUR) OR
  #   access_count > 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY)

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    return unless !defined?(@@last_cleanup) ||
                  (@@last_cleanup < 5.minutes.ago) ||
                  ::Rails.env.test?

    qr = QueryRecord.arel_table

    QueryRecord.where(
      qr[:access_count].eq(0).
        and(qr[:updated_at].lt(Time.zone.now - 6.hours)).
      or(qr[:access_count].gt(0).
        and(qr[:updated_at].lt(Time.zone.now - 1.day)))
    ).delete_all

    @@last_cleanup = Time.zone.now
  end
end

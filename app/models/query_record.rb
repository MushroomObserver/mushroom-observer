# frozen_string_literal: true

# access query records saved in the db
class QueryRecord < ApplicationRecord
  attr_accessor :query

  def query # rubocop:disable Lint/DuplicateMethods
    ::Query.deserialize(description)
  end

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    return unless !defined?(@@last_cleanup) ||
                  (@@last_cleanup < 5.minutes.ago) ||
                  ::Rails.env.test?

    # connection.delete(%(
    #   DELETE FROM #{table_name}
    #   WHERE
    #     access_count = 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 6 HOUR) OR
    #     access_count > 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
    # ))
    table = Arel::Table.new(table_name)
    delete_manager = Arel::DeleteManager.new.
                     from(table).
                     where(table[:access_count].eq(0).and(
                       table[:updated_at].lt(Time.zone.now - 6.hours)
                     ).or(table[:access_count].gt(0).and(
                            table[:updated_at].lt(Time.zone.now - 1.day)
                          )))
    # puts(delete_manager.to_sql)
    connection.delete(delete_manager.to_sql)

    @@last_cleanup = Time.zone.now
  end
end

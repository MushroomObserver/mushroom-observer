class QueryRecord < ApplicationRecord
  attr_accessor :query

  def query
    ::Query.deserialize(description)
  end

  # Only keep unused states around for an hour, and used states for a day.
  # This goes through the whole lot and destroys old ones.
  def self.cleanup
    if !defined?(@@last_cleanup) ||
       (@@last_cleanup < Time.now - 5.minutes)
      if ::Rails.env != "test"
        connection.delete %(
          DELETE FROM #{table_name}
          WHERE access_count = 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 6 HOUR) OR
                access_count > 0 AND updated_at < DATE_SUB(NOW(), INTERVAL 1 DAY)
        )
        @@last_cleanup = Time.now
      end
    end
  end
end

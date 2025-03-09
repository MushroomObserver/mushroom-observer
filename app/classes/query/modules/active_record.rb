# frozen_string_literal: true

# Handles saving and looking up query records in database.
module Query::Modules::ActiveRecord
  attr_accessor :record

  # def record
  #   # This errors out if @record is not set since it
  #   # cannot find Query.get_record.  If you copy the
  #   # above definition of get_record into the same scope
  #   # as this method and get rid of "Query." it works,
  #   # but that is not a great solution.
  #   # You can trigger the issue which is
  #   # triggered if the :wolf_fart observation has
  #   # second image.  See query_test.rb for more.
  #   @record ||= Query.get_record(self)
  # end

  # delegate :id, to: :record

  # delegate :save, to: :record

  # def increment_access_count
  #   record.access_count += 1
  # end
end

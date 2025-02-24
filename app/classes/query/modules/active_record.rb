# frozen_string_literal: true

# Handles saving and looking up query records in database.
module Query::Modules::ActiveRecord
  attr_accessor :record

  def self.included(base)
    base.extend(ClassMethods)
  end

  # Class methods.
  module ClassMethods
    def safe_find(id)
      find(id)
    rescue ::ActiveRecord::RecordNotFound
      nil
    end

    def find(id)
      record = QueryRecord.find(id)
      query = Query.rebuild(record.description)
      record.query = query
      query.record = record
      QueryRecord.cleanup
      query
    end

    def lookup_and_save(*)
      query = lookup(*)
      query.record.save!
      query
    end

    def lookup(*)
      query = Query.new(*)
      record = get_record(query)
      record.query = query
      query.record = record
      QueryRecord.cleanup
      query
    end

    def get_record(query)
      desc = query.serialize
      QueryRecord.find_by(description: desc) ||
        QueryRecord.new(
          description: desc,
          updated_at: Time.zone.now,
          access_count: 0
        )
    end
  end

  def record
    # This errors out if @record is not set since it
    # cannot find Query.get_record.  If you copy the
    # above definition of get_record into the same scope
    # as this method and get rid of "Query." it works,
    # but that is not a great solution.
    # You can trigger the issue which is
    # triggered if the :wolf_fart observation has
    # second image.  See query_test.rb for more.
    @record ||= Query.get_record(self)
  end

  delegate :id, to: :record

  delegate :save, to: :record

  def increment_access_count
    record.access_count += 1
  end
end

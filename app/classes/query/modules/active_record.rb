# frozen_string_literal: true

module Query
  module Modules
    # Handles saving and looking up query records in database.
    module ActiveRecord
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
          query = Query.deserialize(record.description)
          record.query = query
          query.record = record
          query.outer_id = record.outer_id
          QueryRecord.cleanup
          query
        end

        def lookup_and_save(*args)
          query = lookup(*args)
          query.record.save!
          query
        end

        def lookup(*args)
          query = Query.new(*args)
          record = get_record(query)
          record.query = query
          query.record = record
          query.outer_id = record.outer_id
          QueryRecord.cleanup
          query
        end

        def get_record(query)
          desc = query.serialize
          QueryRecord.find_by_description(desc) ||
            QueryRecord.new(
              description: desc,
              updated_at: Time.zone.now,
              access_count: 0
            )
        end
      end

      def record
        @record ||= Query.get_record(self)
      end

      delegate :id, to: :record

      def save
        record.outer_id = outer_id
        record.save
      end

      def increment_access_count
        record.access_count += 1
      end
    end
  end
end

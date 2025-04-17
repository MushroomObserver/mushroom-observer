# frozen_string_literal: true

##############################################################################
#
#  :module: QueryRecords
#
#  Methods that are available to instances as class methods, and to ::Query.
#  ::Query is a convenience delegator class so callers can access these methods.
#
#  QueryRecords:
#  find::               Find a QueryRecord id and reinstantiate a Query from it.
#  safe_find::          Same as above, with rescue.
#  lookup::             Instantiate Query of given model, flavor and params.
#  lookup_and_save::    Ditto, plus save the QueryRecord
#  rebuild_from_description:: Instantiate Query described by description string.
#
module Query::Modules::QueryRecords
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def safe_find(id)
      find(id)
    rescue ::ActiveRecord::RecordNotFound
      nil
    end

    def find(id)
      record = QueryRecord.find(id)
      query = Query.rebuild_from_description(record.description)
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
      query = Query.create_query(*)
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

    # Get the model from the serialized params and instantiate new Query.
    def rebuild_from_description(description)
      model, params = deserialize(description)
      ::Query.create_query(model, params)
    end

    def deserialize(description)
      params = JSON.parse(description).deep_symbolize_keys
      model = params.delete(:model)
      [model, params]
    end
  end
end

module Query
  def self.safe_find(id)
    find(id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def self.find(id)
    record = QueryRecord.find(id)
    query = Query.deserialize(record.description)
    record.query = query
    query.record = record
    query.outer_id = record.outer_id
    QueryRecord.cleanup
    query
  end

  def self.lookup_and_save(*args)
    query = lookup(*args)
    query.record.save!
    query
  end

  def self.lookup(*args)
    query = Query.new(*args)
    record =
      QueryRecord.find_by_params(query.serialize) ||
      QueryRecord.new(
        description:  query.serialize,
        updated_at:   Time.now,
        access_count: 0
      )
    record.query = query
    query.record = record
    query.outer_id = record.outer_id
    QueryRecord.cleanup
    query
  end
end

module Query::Modules::ActiveRecord
  attr_accessor :record

  def id
    record.id
  end

  def save
    record.outer_id = outer_id
    record.save
  end

  def increment_access_count
    record.access_count += 1
  end
end

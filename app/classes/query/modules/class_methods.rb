# frozen_string_literal: true

# Methods that are available to instances as class methods, and to ::Query.
# ::Query is a convenience delegator class so callers can access these methods.
module Query::Modules::ClassMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Query::Modules::ActiveRecord
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

    # Query::Modules::Serialization
    #
    # Get the model from the serialized params and instantiate new Query.
    def rebuild_from_description(description)
      model, params = deserialize(description)
      ::Query.new(model, params)
    end

    def deserialize(description)
      params = JSON.parse(description).deep_symbolize_keys
      model = params.delete(:model)
      [model, params]
    end

    # Query::Modules::RelatedQueries
    #
    # Query needs to know which joins are necessary to make these conversions
    # work. Need to maintain RELATED_TYPES if the Query class is updated.
    # These could be derived by snooping through each Query subclass's
    # parameter_declarations, but that seems wasteful; there are not so many.
    #
    # target_model.name.to_sym: [:Association, :AnotherAssociation],
    RELATED_QUERIES = {
      Image: [:Image, :Observation],
      Location: [:Location, :LocationDescription, :Name, :Observation],
      LocationDescription: [:Location],
      Name: [:Name, :NameDescription, :Observation],
      NameDescription: [:Name],
      Observation: [:Image, :Location, :Name, :Observation, :Sequence]
    }.freeze

    def related?(target, filter)
      return false unless RELATED_QUERIES.key?(target)

      RELATED_QUERIES[target].include?(filter)
    end

    def current_or_related_query(target, filter, current_query)
      if target == filter
        current_query
      elsif (restored_query = restorable_query(target, current_query))
        restored_query
      elsif (new_query = new_query_with_subquery(target, filter, current_query))
        new_query
      end
    end

    # Check the query params for a relevant existing query nested within.
    # This only checks for the key name of the right subquery. It would be
    # more work to check for hash equality, because the nested hash has the
    # :model param too, to be easily deserialized and rebuilt.
    # NOTE: Our custom method `deep_find` returns an array of matches.
    def restorable_query(target, current_query)
      subquery_param = current_query.class.find_subquery_param_name(target)
      restorable_query_params = current_query.params.deep_find(subquery_param)
      return false if restorable_query_params.blank?

      lookup(target, restorable_query_params.first)
    end

    # Make a new query using the current_query as the subquery. Note that this
    # will continue nesting queries unless a restorable query is found above.
    def new_query_with_subquery(target, filter, current_query)
      query_class = "Query::#{target.to_s.pluralize}".constantize
      return unless (subquery = query_class.find_subquery_param_name(filter))

      params = current_query.params.compact
      subquery_params = add_default_subquery_conditions(target, filter, params)

      lookup(target, "#{subquery}": subquery_params)
    end

    def find_subquery_param_name(filter)
      parameter_declarations.key({ subquery: filter })
    end

    def add_default_subquery_conditions(target, filter, params)
      return params unless needs_is_collection_location(target, filter, params)

      params.merge(is_collection_location: true)
    end

    def needs_is_collection_location(target, filter, params)
      target == Location && filter == :Observation &&
        (params[:project] || params[:species_list]) &&
        params[:is_collection_location].blank?
    end
  end
end

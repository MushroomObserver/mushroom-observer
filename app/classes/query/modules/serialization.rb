# frozen_string_literal: true

# :description is not a serialized column; we call `to_json` for serialization.
module Query::Modules::Serialization
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Prepare the query params, adding the model, for saving to the db. The
  # :description column is accessed not just to recompose a query, but to
  # identify existing query records that match current params. That's why the
  # keys are sorted here before being stored as strings in to_json - because
  # when matching a serialized hash, strings must match exactly. This is
  # more efficient however than using a Rails-serialized column and comparing
  # the parsed hashes (in whatever order), because when a column is serialized
  # you can't use SQL on the column value, you have to compare parsed instances.
  def serialize
    params.sort.to_h.merge(model: model.name).to_json
  end

  module ClassMethods
    # Get the model from the serialized params and instantiate new Query.
    def rebuild_from_description(description)
      model  = params[:model].to_sym
      params = deserialize(description)
      ::Query.new(model, params)
    end

    def deserialize(description)
      params = JSON.parse(description).deep_symbolize_keys
      params.delete(:model)
      params
    end
  end
end

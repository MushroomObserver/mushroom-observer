# frozen_string_literal: true

# :description is now a serialized column, so Rails does the de/serialization.
module Query::Modules::Serialization
  def self.included(base)
    base.extend(ClassMethods)
  end

  # Prepare the query params for saving to the db, adding the model.
  # The keys are stored as strings in to_json
  def serialize
    params.merge(model: model.name).deep_transform_keys(&:to_s)
  end

  # Class methods.
  module ClassMethods
    # Extract the model from the serialized params and instantiate new Query.
    def deserialize(description)
      params = description.symbolize_keys
      model  = params[:model].to_sym
      params.delete(:model)
      ::Query.new(model, params)
    end
  end
end

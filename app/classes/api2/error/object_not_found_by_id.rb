# frozen_string_literal: true

class API2
  # Referenced object id doesn't exist.
  class ObjectNotFoundById < FatalError
    def initialize(id, model)
      super()
      args.merge!(id: id.to_s, type: model.type_tag)
    end
  end
end

# frozen_string_literal: true

class API2
  # Referenced object name doesn't exist.
  class ObjectNotFoundByString < FatalError
    def initialize(str, model)
      super()
      args.merge!(str: str.to_s, type: model.type_tag)
    end
  end
end

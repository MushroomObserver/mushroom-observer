# frozen_string_literal: true

class API2
  # POST request couldn't create object.
  class CreateFailed < ObjectError
    def initialize(obj)
      super(obj)
      args.merge!(error: obj.formatted_errors.map(&:to_s).join("; "))
    end
  end
end
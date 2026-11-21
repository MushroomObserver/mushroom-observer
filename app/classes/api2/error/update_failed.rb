# frozen_string_literal: true

class API2
  # PATCH request couldn't save object.
  class UpdateFailed < ObjectError
    def initialize(obj)
      super
      args.merge!(error: obj.formatted_errors.join("; "))
    end
  end
end

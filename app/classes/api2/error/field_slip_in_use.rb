# frozen_string_literal: true

class API2
  # Field slip with code exists and already has an observation
  class FieldSlipInUse < ObjectError
    def initialize(obj)
      super(obj)
      args.merge!(code: obj.code)
    end
  end
end

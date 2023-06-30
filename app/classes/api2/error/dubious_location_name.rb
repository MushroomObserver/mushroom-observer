# frozen_string_literal: true

class API2
  # Location name is "dubious".
  class DubiousLocationName < Error
    def initialize(reasons)
      super()
      args.merge!(reasons: reasons.join("; ").gsub(".;", ";"))
    end
  end
end

# frozen_string_literal: true

class API2
  # Name parameter has multiple matches.
  class AmbiguousName < FatalError
    def initialize(name, others)
      super()
      str = others.map(&:real_search_name).join(" / ")
      args.merge!(name: name.to_s, others: str)
    end
  end
end

# frozen_string_literal: true

class API2
  # Tried to both clear synonyms and add synonyms at the same time.
  class OneOrTheOther < FatalError
    def initialize(args)
      super()
      args.merge!(args: args.map(&:to_s).join(", "))
    end
  end
end

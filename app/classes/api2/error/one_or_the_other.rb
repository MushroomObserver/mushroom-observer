# frozen_string_literal: true

class API2
  # Tried to both clear synonyms and add synonyms at the same time.
  class OneOrTheOther < FatalError
    def initialize(fields)
      super()
      self.args.merge!(args: fields.join(", "))
    end
  end
end

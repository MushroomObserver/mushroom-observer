# frozen_string_literal: true

class API2
  # Can't set both specimen_id and herbarium_label, choose one or the other.
  class CanOnlyUseOneOfTheseFields < FatalError
    def initialize(*fields)
      super()
      args.merge!(fields: fields.join(", "))
    end
  end
end

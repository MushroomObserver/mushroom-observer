# frozen_string_literal: true

class API2
  # Tried to create herbarium record already been used by someone else.
  class HerbariumRecordAlreadyExists < FatalError
    def initialize(obj)
      super()
      args.merge!(herbarium: obj.herbarium.name, number: obj.accession_number)
    end
  end
end

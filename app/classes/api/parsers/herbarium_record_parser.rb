class API
  module Parsers
    # Parse herbarium_records for API.
    class HerbariumRecordParser < ObjectBase
      def model
        HerbariumRecord
      end
    end
  end
end

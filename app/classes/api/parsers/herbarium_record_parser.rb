class API
  module Parsers
    # Parse herbarium_records for API.
    class HerbariumRecordParser < ObjectBase
      def model
        HerbariumRecord
      end

      def try_finding_by_string(str)
        HerbariumRecord.find_by_herbarium_label(str)
      end
    end
  end
end

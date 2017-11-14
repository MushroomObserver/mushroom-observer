class API
  module Parsers
    # Parse API external sites
    class ExternalSiteParser < ObjectBase
      def model
        ExternalSite
      end

      def try_finding_by_string(str)
        ExternalSite.find_by_name(str)
      end
    end
  end
end

class API
  module Parsers
    # Parse API image sizes
    class SizeParser < EnumParser
      def initialize(api, key, args)
        args[:limit] ||= Image.all_sizes - [:full_size]
        super
      end
    end
  end
end

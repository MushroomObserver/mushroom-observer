class API
  module Parsers
    # Parse API image sizes
    class SizeParser < EnumParser
      def initialize(api, key, args)
        args[:limit] ||= Image.all_sizes - [:full_size]
        super(api, key, args)
      end
    end
  end
end

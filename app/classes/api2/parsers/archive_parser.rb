# frozen_string_literal: true

class API2
  module Parsers
    # Parse sequence archives for API.
    class ArchiveParser < EnumParser
      def initialize(api, key, args)
        args[:limit] ||= WebSequenceArchive.all_archives.map(&:to_sym)
        super
      end
    end
  end
end

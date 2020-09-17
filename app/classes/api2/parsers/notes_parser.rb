# frozen_string_literal: true

class API2
  module Parsers
    # Parse notes for API2.
    class NotesParser < StringParser
      def parse(str)
        return Observation.no_notes if str.empty?

        { Observation.other_notes_key => str }
      end
    end
  end
end

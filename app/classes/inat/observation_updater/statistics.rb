# frozen_string_literal: true

class Inat
  class ObservationUpdater
    # Tracks statistics and details for observation update process
    class Statistics
      attr_reader :observations_processed, :namings_added,
                  :provisional_names_added, :sequences_added,
                  :errors, :details

      def initialize
        @observations_processed = 0
        @namings_added = 0
        @provisional_names_added = 0
        @sequences_added = 0
        @errors = []
        @details = []
      end

      def increment(counter)
        case counter
        when :observations_processed
          @observations_processed += 1
        when :namings_added
          @namings_added += 1
        when :provisional_names_added
          @provisional_names_added += 1
        when :sequences_added
          @sequences_added += 1
        end
      end

      def add_error(message)
        @errors << message
      end

      def add_detail(message)
        @details << message
      end

      def error_count
        @errors.count
      end
    end
  end
end

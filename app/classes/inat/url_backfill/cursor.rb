# frozen_string_literal: true

class Inat
  class URLBackfill
    # The walk's resume point: the iNat observation id the next run
    # starts below. Kept in a file rather than a column because the
    # pass is temporary -- a column would ride along in every database
    # dump taken over the five weeks it runs, and need a second
    # migration to remove.
    #
    # Losing the file costs one re-walk of the observations already
    # visited: the values there are in /obs/ form, so nothing is
    # rewritten and nothing is lost, just a couple of hours of reading
    # and resyncing spread over the next few runs.
    class Cursor
      PATH = Rails.root.join("tmp/inat_url_backfill_cursor")

      def initialize(path: PATH)
        @path = path
      end

      # nil means "start from the newest observation".
      def read
        return nil unless File.exist?(@path)

        value = File.read(@path).to_i
        value.positive? ? value : nil
      rescue SystemCallError
        nil
      end

      def write(id)
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, id.to_s)
      end
    end
  end
end

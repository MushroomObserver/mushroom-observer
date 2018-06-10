# frozen_string_literal: true
#
# Prime the name auto-completer
class Name < AbstractModel
  # Get list of most used names to prime auto-completer.
  # Return a simple Array of up to 1000 name String's (no authors).
  #
  # *NOTE*: Since this is an expensive query (well, okay it only takes a tenth
  # of a second but that could change...), it gets cached periodically (daily?)
  # in a plain old file (MO.name_primer_cache_file).
  #
  def self.primer
    current_name_cache || refreshed_name_cache
  end

  # private class methods
  class << self
    private

    def current_name_cache
      return unless name_primer_cache_current?
      File.open(MO.name_primer_cache_file, "r:UTF-8") do |file|
        return file.readlines.map(&:chomp)
      end
    end

    def name_primer_cache_current?
      File.exist?(MO.name_primer_cache_file) &&
        File.mtime(MO.name_primer_cache_file) >= Time.now.getlocal - 1.day
    end

    def refreshed_name_cache
      result = most_used_names
      FileUtils.mkdir_p(File.dirname(MO.name_primer_cache_file))
      File.open(MO.name_primer_cache_file, "w:utf-8") do |file|
        file.write(result.join("\n") + "\n")
      end
      result
    end

    # List of names sorted by how many times they've been used,
    # then re-sorted by name.
    def most_used_names
      connection.select_values(%(
        SELECT names.text_name, COUNT(*) AS n
        FROM namings
        LEFT OUTER JOIN names ON names.id = namings.name_id
        WHERE correct_spelling_id IS NULL
        GROUP BY names.text_name
        ORDER BY n DESC
        LIMIT 1000
      )).uniq.sort
    end
  end
end

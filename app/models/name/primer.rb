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
    # Temporarily disable. It rarely takes autocomplete long even on my horrible
    # internet connection. And the primer can -- at least briefly -- have names
    # that have been merged or deprecated or misspelled.  That may be confusing
    # some users.  Let's try it without for a while to see if anyone complains.
    # current_name_cache || refreshed_name_cache
    []
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
      Name.left_outer_joins(:namings).select(:text_name, Arel.star.count).
        where(correct_spelling_id: nil).group(:text_name).
        order(Name[:text_name].count.desc).
        limit(1000).pluck(:text_name).uniq.sort
    end
  end
end

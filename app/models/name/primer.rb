# frozen_string_literal: true

module Name::Primer
  # When we `include` a module, the way to add class methods is like this:
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Get list of most used names to prime auto-completer.
    # Return a simple Array of up to 1000 name String's (no authors).
    #
    # NOTE: Since this is an expensive query (well, okay it only takes a tenth
    # of a second but that could change), it gets cached periodically (daily?)
    # in a plain old file (MO.name_primer_cache_file).
    #
    def primer
      # Temporarily disable. It rarely takes autocomplete long even on my
      # horrible internet connection. And the primer can -- at least briefly --
      # have names that have been merged or deprecated or misspelled.
      # That may be confusing some users.
      # Let's try it without for a while to see if anyone complains.
      # current_name_cache || refreshed_name_cache
      []
    end

    # Returns a list of the most popular 100 names that don't have descriptions.
    # NOTE!! -- all this extra info and help will be lost if user re-sorts.
    def needed_descriptions
      data = Name.connection.select_rows(%(
        SELECT names.id, name_counts.count
        FROM names LEFT OUTER JOIN name_descriptions
          ON names.id = name_descriptions.name_id,
             (SELECT count(*) AS count, name_id
              FROM observations group by name_id) AS name_counts
        WHERE names.id = name_counts.name_id
          # include "to_i" to avoid Brakeman "SQL injection" false positive.
          # (Brakeman does not know that Name.ranks[:xxx] is an enum.)
          AND names.`rank` = #{Name.ranks[:Species].to_i}
          AND name_counts.count > 1
          AND name_descriptions.name_id IS NULL
          AND CURRENT_TIMESTAMP - names.updated_at > #{1.week.to_i}
        ORDER BY name_counts.count DESC, names.sort_name ASC
        LIMIT 100
      ))
      # name_counts = Name.left_outer_joins(:name_descriptions).
      #                 select(Name[:observations].count,
      #                   NameDescription[:name_id]).
      #                 group(:name_id)

      # data = Name.joins(name_counts).
      #         where(Name[:id] == name_counts[:name_id]).
      #         where(Name[:rank] == Name.ranks[:Species]).
      #         where(name_counts[:count] > 1).
      #         where(NameDescription[:name_id] == nil).
      #         where(Name[:updated_at] > 1.week.ago).
      #         select(Name[:id], name_counts[:count]).
      #         order(name_counts[:count].desc, Name[:sort_name].asc).
      #         take(100)
      #
      # pp data

      Query.lookup(:Name, :in_set,
        ids: data.map(&:first),
        title: :needed_descriptions_title.l)
    end

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

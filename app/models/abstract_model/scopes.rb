# frozen_string_literal: true

module AbstractModel::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    scope :order_by_user, lambda {
      joins(:user).
        reorder(User[:name].when(nil).then(User[:login]).
                when("").then(User[:login]).
                else(User[:name]).asc, id: :desc).distinct
    }
    scope :order_by_rss_log, lambda {
      joins(:rss_log).
        reorder(RssLog[:updated_at].desc, model.arel_table[:id].desc).distinct
    }

    scope :by_user,
          ->(user) { where(user: user) }
    scope :by_editor, lambda { |user|
      version_table = :"#{type_tag}_versions"
      unless ActiveRecord::Base.connection.table_exists?(version_table)
        return all
      end

      user_id = user.is_a?(Integer) ? user : user&.id

      joins(:versions).where("#{version_table}": { user_id: user_id }).
        where.not(user: user)
    }

    scope :created_on, lambda { |ymd_string|
      where(arel_table[:created_at].format("%Y-%m-%d").eq(ymd_string))
    }
    scope :created_after,
          ->(datetime) { datetime_compare(:created_at, :gt, datetime) }
    scope :created_before,
          ->(datetime) { datetime_compare(:created_at, :lt, datetime) }
    scope :created_between, lambda { |earliest, latest|
      created_after(earliest).created_before(latest)
    }

    scope :updated_on, lambda { |ymd_string|
      where(arel_table[:updated_at].format("%Y-%m-%d").eq(ymd_string))
    }
    scope :updated_after,
          ->(datetime) { datetime_compare(:updated_at, :gt, datetime) }
    scope :updated_before,
          ->(datetime) { datetime_compare(:updated_at, :lt, datetime) }
    scope :updated_between, lambda { |earliest, latest|
      updated_after(earliest).updated_before(latest)
    }

    scope :datetime_after,
          ->(col, datetime) { datetime_compare(col, :gt, datetime) }
    scope :datetime_before,
          ->(col, datetime) { datetime_compare(col, :lt, datetime) }
    scope :datetime_between, lambda { |col, earliest, latest|
      datetime_after(col, earliest).datetime_before(col, latest)
    }
    scope :datetime_compare, lambda { |col, dir, val|
      # `datetime_condition_formatted` defined in ClassMethods below
      return unless (datetime = datetime_condition_formatted(dir, val))

      where(arel_table[col].format("%Y-%m-%d %H:%i:%s").send(dir, datetime))
    }

    scope :when_after,
          ->(date) { date_compare(:when, :gt, date) }
    scope :when_before,
          ->(date) { date_compare(:when, :lt, date) }
    scope :when_between,
          ->(earliest, latest) { date_between(:when, earliest, latest) }

    # Note that these two conditions can take dates, or months, or month-days!
    scope :date_after,
          ->(col, date) { date_compare(col, :gt, date) }
    scope :date_before,
          ->(col, date) { date_compare(col, :lt, date) }
    # Allows searching for date ranges in a date (:when) column, either within
    # a logical time range, or within a periodic time range in recurring years.
    # This is possible because a date column already has the format("%Y-%m-%d").
    scope :date_between, lambda { |col, earliest, latest|
      if wrapped_date?(earliest, latest)
        date_in_period_wrapping_new_year(col, earliest, latest)
      else
        date_after(col, earliest).date_before(col, latest)
      end
    }
    # Scope for objects whose date is in a certain period of the year that
    # overlaps the new year, defined by a range of months or mm-dd
    scope :date_in_period_wrapping_new_year, lambda { |col, earliest, latest|
      m1, d1 = earliest.to_s.split("-")
      m2, d2 = latest.to_s.split("-")
      where(
        arel_table[col].month.gt(m1).
        or(arel_table[col].month.lt(m2)).
        or(arel_table[col].month.eq(m1).and(arel_table[col].day.gteq(d1))).
        or(arel_table[col].month.eq(m2).and(arel_table[col].day.lteq(d2)))
      )
    }
    # NOTE: all three conditions validate numeric format
    scope :date_compare, lambda { |col, dir, val|
      if starts_with_year?(val)
        date_compare_year(col, dir, val)
      elsif month_and_day?(val)
        date_compare_month_and_day(col, dir, val)
      elsif month_only?(val)
        where(arel_table[col].month.send(:"#{dir}eq", val))
      end
    }
    # Compare only the year
    scope :date_compare_year, lambda { |col, dir, val|
      date = date_condition_formatted(dir, val)
      where(arel_table[col].send(dir, date))
    }
    # Compare only the month and day, any year (i.e. "season")
    scope :date_compare_month_and_day, lambda { |col, dir, val|
      m, d = val.split("-")
      where(
        arel_table[col].month.send(dir, m).
        or(
          arel_table[col].month.eq(m).
          and(arel_table[col].day.send(:"#{dir}eq", d))
        )
      )
    }

    # Search given `table_columns` for given values (both "good" and "bad").
    # The arg `table_columns` can be a column, like Name[:text_name], or a
    # concatenation of columns, like (Name[:text_name] + Name[:classification]).
    # If you send a concatenation from different tables be sure to join to them.
    # `phrase` should be a google-search-phrased search string. This method
    # creates a SearchParams instance to parse the phrase's `goods` and `bads`.
    # Then generates a chain of AR `where` clauses that gets those matches from
    # the given columns, and avoids the `does_not_match`es.
    # This can be called on joins, because the columns specify the table.
    scope :search_columns, lambda { |table_columns, phrase|
      return all if phrase.blank?

      search = SearchParams.new(phrase:)
      conditions = search_conditions_good(table_columns, search.goods)
      conditions += search_conditions_bad(table_columns, search.bads)
      send_where_chain(conditions).distinct
    }
  end

  module ClassMethods
    # class methods here, `self` included

    # Fills out the datetime with min/max values for month, day, hour, minute,
    # second, as appropriate for < > comparisons. Only year is required.
    def datetime_condition_formatted(dir, val)
      y, m, d, h, n, s = val.split("-").map!(&:to_i)
      return unless /^\d\d\d\d/.match?(y.to_s)

      returns = dir == :gt ? [y, 1, 1, 0, 0, 0] : [y, 12, 31, 23, 59, 59]
      vals = [m, d, h, n, s].compact # get as many specific values as were sent
      returns[1, vals.length] = vals # merge these into the defaults, after year
      # reformat to "%Y-%m-%d %H:%i:%s" as expected
      [returns[0..2]&.join("-"), returns[3..5]&.join(":")].join(" ")
    end

    # Only works on month/day periods, because years where earliest > latest
    # would make no sense
    def wrapped_date?(earliest, latest)
      earliest.to_s.match(/^\d\d-\d\d$/) && latest.to_s.match(/^\d\d-\d\d$/) &&
        earliest.to_s > latest.to_s
    end

    # Fills out the date with min/max values for month and day as appropriate
    # for < > comparisons. Requires year, prevalidated by `starts_with_year?`.
    def date_condition_formatted(dir, val)
      min = (dir == :gt)
      y, m, d = val.split("-").map!(&:to_i)
      m ||= min ? 1 : 12
      d ||= min ? 1 : 31
      [y, m, d].join("-")
    end

    def starts_with_year?(val)
      /^\d\d\d\d/.match?(val.to_s)
    end

    def month_and_day?(val)
      /^\d\d-\d\d/.match?(val.to_s)
    end

    def month_only?(val)
      /^\d\d/.match?(val.to_s) && val.to_i <= 12
    end

    # This stacks `where` conditions in a chain, on the class (self).
    # The conditions should be Arel::Nodes, e.g. Observation[:id].eq(foo)
    def send_where_chain(conditions)
      conditions.reduce(self) { |result, cond| result.send(:where, cond) }
    end

    # Combine args into one parenthesized condition by ANDing them.
    def and_clause(*args)
      if args.length > 1
        # "(#{args.join(" AND ")})"
        starting = args.shift
        args.reduce(starting) { |result, arg| result.and(arg) }
      else
        args.first
      end
    end

    # Combine args into one parenthesized condition by ORing them.
    def or_clause(*args)
      if args.length > 1
        # "(#{args.join(" OR ")})"
        starting = args.shift
        args.reduce(starting) { |result, arg| result.or(arg) }
      else
        args.first
      end
    end

    # Returns an array of AR conditions describing what a search is looking for.
    #
    # Each array member ["foo", "fah"] gets joined in a chain of AR "where"
    # clauses by `send_where_chain`, producing this SQL:
    #     WHERE (`table`.`col` LIKE '%foo%') AND (`table`.`col` LIKE '%fah%')"
    # Nested subarrays [["foo", "fah"]] are joined here with OR.
    #     WHERE (`table`.`col` LIKE '%foo%') OR (`table`.`col` LIKE '%fah%')"
    # so they can be `AND`ed with the other members of the array.
    #
    # For example this search string (from QueryTest):
    #   'foo OR bar OR "any*thing" -bad surprise! -"lost boys"'
    # will produce this SQL:
    #   "(x LIKE '%foo%' OR x LIKE '%bar%' OR x LIKE '%any%thing%') " \
    #   "AND x LIKE '%surprise!%' AND x NOT LIKE '%bad%' " \
    #   "AND x NOT LIKE '%lost boys%'"
    #
    def search_conditions_good(table_columns, goods)
      conditions = []
      goods.each do |good|
        # break up phrases
        parts = *good.map(&:clean_pattern)
        # pop the first phrase off, to start the condition chain without an `OR`
        condition = table_columns.matches("%#{parts.shift}%")
        parts.each do |str|
          # join the parts with `or`
          condition = condition.or(table_columns.matches("%#{str}%"))
        end
        # Add a where condition for each good (equivalent to `AND`)
        conditions << condition
      end
      conditions
    end

    # Array of conditions for what the search wants to avoid. Joined with `AND`.
    def search_conditions_bad(table_columns, bads)
      bads.map do |bad|
        table_columns.does_not_match("%#{bad.clean_pattern}%")
      end
    end

    # These should be defined in the model
    def searchable_columns
      return [] unless defined?(self::SEARCHABLE_FIELDS)

      fields = self::SEARCHABLE_FIELDS.dup
      starting = arel_table[fields.shift].coalesce("")
      fields.reduce(starting) do |result, field|
        result + arel_table[field].coalesce("")
      end
    end

    def lookup_external_sites_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        ExternalSite.where(name: name)
      end
    end

    def lookup_herbaria_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        Herbarium.where(name: name)
      end
    end

    def lookup_herbarium_records_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        HerbariumRecord.where(id: name)
      end
    end

    def lookup_locations_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        pattern = Location.clean_name(name.to_s).clean_pattern
        Location.name_contains(pattern)
      end
    end

    def lookup_regions_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        # does not lowercase it, because we want a match to the end of string
        pattern = name.to_s.clean_pattern
        Location.in_region(pattern)
      end
    end

    def lookup_projects_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        Project.where(title: name)
      end
    end

    def lookup_lists_for_projects_by_name(vals)
      return unless vals

      project_ids = lookup_projects_by_name(vals)
      return [] if project_ids.empty?

      # Have to map(&:id) because it doesn't return lookup_object_ids_by_name
      SpeciesList.joins(:project_species_lists).
        where(project_species_lists: { project_id: project_ids }).
        distinct.map(&:id)
    end

    def lookup_species_lists_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        SpeciesList.where(title: name)
      end
    end

    def lookup_users_by_name(vals)
      lookup_object_ids_by_name(vals) do |name|
        User.where(login: User.remove_bracketed_name(name))
      end
    end

    # Used by scopes to get IDs when they're passed strings or instances.
    # In the last condition, `yield` == run any block provided to this method.
    # (Only in the case it doesn't have an ID does it look up the record.)
    def lookup_object_ids_by_name(vals)
      return unless vals

      vals = [vals] unless vals.is_a?(Array)
      vals.map do |val|
        if val.is_a?(AbstractModel)
          val.id
        elsif /^\d+$/.match?(val.to_s)
          val
        else
          yield(val).map(&:id)
        end
      end.flatten.uniq.compact
    end
  end
end

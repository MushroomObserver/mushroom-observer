# frozen_string_literal: true

#  == Scopes
#
#  Examples:
#    Observation.created_at("2006-09-01", "2012-09-01")
#    Name.updated_at("2016-12-01") # returns names updated after
#
#  Ordering Scopes
#
#  order_by_user::
#  order_by_rss_log::
#  order_by_set::
#
#  Filtering scopes
#
#  id_in_set::
#  by_users::
#  by_editor::
#  created_at::
#  updated_at::
#  date::
#  has_comments::
#  comments_has::
#
#  Utility Scopes
#
#  created_on::
#  updated_on::
#  datetime_at::
#  datetime_on::
#  datetime_in_month::
#  datetime_in_year::
#  datetime_after::
#  datetime_before::
#  datetime_between::
#  on_date::
#  date_after::
#  date_before::
#  date_between::
#  search_columns::

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
    scope :order_by_set, lambda { |set|
      reorder(Arel::Nodes.build_quoted(set.join(",")) & arel_table[:id])
    }

    scope :id_in_set, lambda { |ids|
      set = limited_id_set(ids) # [] is valid
      return none if set.empty?

      where(arel_table[:id].in(set)).order_by_set(set)
    }

    scope :by_users, lambda { |users|
      ids = lookup_users_by_name(users)
      where(user: ids)
    }
    scope :by_editor, lambda { |user|
      version_table = :"#{type_tag}_versions"
      unless ActiveRecord::Base.connection.table_exists?(version_table)
        return all
      end

      user_id = user.is_a?(Integer) ? user : user&.id

      joins(:versions).where("#{version_table}": { user_id: user_id }).
        where.not(user: user)
    }

    # `created_at`/`updated_at` are versatile, and handle all Queries currently.
    #
    #   Value handling:
    #   - For two datetimes, early and late can be any order.
    #   - A single date(time) returns all records _after_ that date(time).
    #   - A single "yyyy-mm" returns all records _within_ that year and month.
    #   - A single "yyyy" returns all records within that year.
    #
    # The values we're getting in the scopes should be parseable as datetimes
    # in Ruby. Parsing of user text values like "yesterday"/"la semana pasada"
    # needs to be done upstream in PatternSearch.
    #
    scope :created_at,
          ->(early, late = early) { datetime_at(early, late, col: :created_at) }
    scope :updated_at,
          ->(early, late = early) { datetime_at(early, late, col: :updated_at) }

    # These scopes match records of one day only. (API parses single dates
    # differently, turning them into a range of datetimes from 00:01 to 12:00.)
    scope :created_on,
          ->(ymd_string) { datetime_on(ymd_string, col: :created_at) }
    scope :updated_on,
          ->(ymd_string) { datetime_on(ymd_string, col: :updated_at) }

    ##########################################################################
    #  DATETIME UTILITY SCOPES
    #
    # For other datetime columns, e.g. `:log_updated_at`
    scope :datetime_at, lambda { |early, late = early, col:|
      early, late = early if early.is_a?(Array) && early.size == 2
      if late == early
        datetime_in_year_or_in_month_or_after_date(early, col:)
      else
        datetime_between(early, late, col:)
      end
    }
    scope :datetime_on, lambda { |ymd_string, col:|
      where(arel_table[col].format("%Y-%m-%d").eq(ymd_string))
    }
    scope :datetime_before,
          ->(datetime, col:) { datetime_compare(:lt, datetime, col:) }
    scope :datetime_in_month, lambda { |ym_string, col:|
      year, month = ym_string.split("-")
      return all unless year.present? && month.present?

      where(arel_table[col].year.eq(year).and(arel_table[col].month.eq(month)))
    }
    scope :datetime_in_year,
          ->(year, col:) { where(arel_table[col].year.eq(year)) }
    scope :datetime_after,
          ->(datetime, col:) { datetime_compare(:gt, datetime, col:) }
    scope :datetime_between, lambda { |early, late, col:|
      early, late = [late, early] if early > late
      datetime_after(early, col:).datetime_before(late, col:)
    }

    # NOTE: In a date (not datetime) column, we can allow searching for date
    # ranges: not just specific dates, but also dates within a seasonal range in
    # recurring years. This is possible via string parsing class methods (below)
    # because in the database, a date column already has the format("%Y-%m-%d").
    # NOTE: On MO so far, all date columns are named :when.
    # In this scope, the order of early and late matter. early > late can mean
    # a date range wrapping the end/beginning of the year.
    scope :date, lambda { |early, late = early, col: :when|
      early, late = early if early.is_a?(Array) && early.size == 2
      if late == early
        date_after(early, col:)
      else
        date_between(early, late, col:)
      end
    }

    ##########################################################################
    #  DATE UTILITY SCOPES
    #
    scope :on_date,
          ->(date, col: :when) { date_compare(nil, date, col:) }
    scope :date_after,
          ->(date, col: :when) { date_compare(:gt, date, col:) }
    scope :date_before,
          ->(date, col: :when) { date_compare(:lt, date, col:) }
    scope :date_between, lambda { |early, late, col: :when|
      # do not correct early > late, which means something different here
      if wrapped_date?(early, late)
        date_in_period_wrapping_new_year(early, late, col:)
      else
        date_after(early, col:).date_before(late, col:)
      end
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

    # Used in Name, Observation and Project so far.
    scope :has_comments,
          ->(bool = true) { joined_relation_condition(:comments, bool:) }
    scope :comments_has, lambda { |phrase|
      joins(:comments).merge(Comment.search_content(phrase)).distinct
    }
  end

  # class methods here, `self` included
  module ClassMethods
    # array of max of MO.query_max_array unique ids for use with Arel "in"
    #    where(<x>.in(limited_id_set(ids)))
    def limited_id_set(ids)
      [ids].flatten.map(&:to_i).uniq[0, MO.query_max_array] # [] is valid
    end

    def datetime_compare(dir, val, col:)
      # `datetime_condition_formatted` defined in ClassMethods below
      return unless (datetime = datetime_condition_formatted(dir, val))

      where(arel_table[col].send(dir, datetime))
    end

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

    # If a single "YYYY" is passed to a datetime scope, it should return
    # records where the col value is within the year. Ditto for "YYYY-MM".
    # If it gets a full date, though, Query returns records after that date.
    def datetime_in_year_or_in_month_or_after_date(date, col:)
      y, m, d = date.split("-").map!(&:to_i) # times ignored here
      return unless /^\d\d\d\d/.match?(y.to_s)
      return datetime_after(date, col:) if d.present?
      return datetime_in_month(date, col:) if m.present?

      datetime_in_year(date, col:)
    end

    # Scope for objects whose date is in a certain period of the year that
    # overlaps the new year, defined by a range of months or mm-dd
    # rubocop:disable Metrics/AbcSize
    def date_in_period_wrapping_new_year(early, late, col:)
      m1, d1 = early.to_s.split("-")
      m2, d2 = late.to_s.split("-")
      where(
        arel_table[col].month.gt(m1).
        or(arel_table[col].month.lt(m2)).
        or(arel_table[col].month.eq(m1).and(arel_table[col].day.gteq(d1))).
        or(arel_table[col].month.eq(m2).and(arel_table[col].day.lteq(d2)))
      )
    end

    # NOTE: all three conditions validate numeric format
    def date_compare(dir, val, col:)
      if starts_with_year?(val)
        date_compare_year(dir, val, col:)
      elsif month_and_day?(val)
        date_compare_month_and_day(dir, val, col:)
      elsif month_only?(val)
        where(arel_table[col].month.send(:"#{dir}eq", val))
      end
    end
    # rubocop:enable Metrics/AbcSize

    # Compare full date, or only the year.
    # date_condition_formatted fills out min/max dates for year or year-month.
    def date_compare_year(dir, val, col:)
      date = date_condition_formatted(dir, val)
      where(arel_table[col].send(:"#{dir}eq", date))
    end

    # Compare only the month and day, any year (i.e. "season")
    def date_compare_month_and_day(dir, val, col:)
      m, d = val.split("-")
      where(
        arel_table[col].month.send(dir, m).
        or(
          arel_table[col].month.eq(m).
          and(arel_table[col].day.send(:"#{dir}eq", d))
        )
      )
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

    # SEARCHABLE_FIELDS should be defined in the model
    def searchable_columns
      return [] unless defined?(self::SEARCHABLE_FIELDS)

      fields = self::SEARCHABLE_FIELDS.dup
      starting = arel_table[fields.shift].coalesce("")
      fields.reduce(starting) do |result, field|
        result + arel_table[field].coalesce("")
      end
    end

    def lookup_external_sites_by_name(vals)
      Lookup::ExternalSites.new(vals).ids
    end

    def lookup_field_slips_by_name(vals)
      Lookup::FieldSlips.new(vals).ids
    end

    def lookup_herbaria_by_name(vals)
      Lookup::Herbaria.new(vals).ids
    end

    def lookup_herbarium_records_by_name(vals)
      Lookup::HerbariumRecords.new(vals).ids
    end

    def lookup_locations_by_name(vals)
      Lookup::Locations.new(vals).ids
    end

    def lookup_names_by_name(vals, params = {})
      Lookup::Names.new(vals, **params).ids
    end

    def lookup_projects_by_name(vals)
      Lookup::Projects.new(vals).ids
    end

    def lookup_lists_for_projects_by_name(vals)
      Lookup::ProjectSpeciesLists.new(vals).ids
    end

    def lookup_species_lists_by_name(vals)
      Lookup::SpeciesLists.new(vals).ids
    end

    def lookup_regions_by_name(vals)
      Lookup::Regions.new(vals).ids
    end

    def lookup_users_by_name(vals)
      Lookup::Users.new(vals).ids
    end

    def exact_match_condition(table_column, vals)
      vals = [vals].flatten.map { |val| val.to_s.downcase }
      if vals.length == 1
        where(table_column.downcase.eq(vals.first))
      elsif vals.length > 1
        where(table_column.downcase.in(*vals))
      end
    end

    def presence_condition(table_column, bool: true)
      if bool.to_s.to_boolean == true
        where(table_column.not_eq(nil))
      else
        where(table_column.eq(nil))
      end
    end

    # AR cares if the relation (table) is plural or singular (has_one/many)
    def joined_relation_condition(relation, bool: true)
      if bool.to_s.to_boolean == true
        joins(relation).distinct
      else
        where.not(id: joins(relation).distinct)
      end
    end

    def boolean_condition(table_column, val, bool: true)
      if bool.to_s.to_boolean == true
        where(table_column.eq(val))
      else
        where(table_column.not_eq(val))
      end
    end

    # Try not_blank_condition before uncommenting this
    # def coalesce_presence_condition(table_column, bool: true)
    #   if bool.to_s.to_boolean == true
    #     where(table_column.coalesce("").length.gt(0))
    #   else
    #     where(table_column.coalesce("").length.eq(0))
    #   end
    # end

    def not_blank_condition(table_column, bool: true)
      if bool.to_s.to_boolean == true
        where(table_column.not_blank)
      else
        where(table_column.blank)
      end
    end
  end
end

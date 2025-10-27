# frozen_string_literal: true

#  == Scopes
#
#  Examples:
#    Observation.created_at("2006-09-01", "2012-09-01")
#    Name.updated_at("2016-12-01") # returns names updated after
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
  included do
    scope :id_in_set, lambda { |ids|
      set = limited_id_set(ids) # [] is valid and should return none
      return none if set.empty?

      where(arel_table[:id].in(set)).order_by_set(set)
    }

    scope :by_users, lambda { |users|
      ids = Lookup::Users.new(users).ids
      where(user: ids)
    }
    scope :by_editor, lambda { |users|
      version_table = :"#{type_tag}_versions"
      unless ActiveRecord::Base.connection.table_exists?(version_table)
        return all
      end

      ids = Lookup::Users.new(users).ids
      joins(:versions).where("#{version_table}": { user_id: ids }).
        where.not(user: ids).distinct
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
          ->(early, late = nil) { datetime_at(early, late, col: :created_at) }
    scope :updated_at,
          ->(early, late = nil) { datetime_at(early, late, col: :updated_at) }

    # These scopes match records of one day only. (API parses single dates
    # differently, turning them into a range of datetimes from 00:01 to 12:00.)
    scope :created_on,
          ->(ymd_string) { datetime_on(ymd_string, col: :created_at) }
    scope :updated_on,
          ->(ymd_string) { datetime_on(ymd_string, col: :updated_at) }

    ##########################################################################
    #
    #  DATETIME UTILITY SCOPES
    #
    # Can be used for other datetime columns, e.g. `:log_updated_at`.
    scope :datetime_at, lambda { |early, late = nil, col:|
      early, late = early if early.is_a?(Array)
      if late == early
        datetime_with_levels_of_precision(early, col:)
      elsif late.present?
        datetime_between(early, late, col:)
      else
        datetime_after(early, col:)
      end
    }
    # NOTE: these two scopes currently only tolerate fully hyphenated formats
    # "%Y-%m-%d" and "%Y-%m-%d-%H-%M-%S". Switching to DateTime.parse might be
    # more tolerant, but it can't parse "%Y-%m-%d-%H-%M-%S", so it would require
    # Query to send datetimes as "%Y-%m-%d %H:%M:%S". This complicates MO's
    # level-of-detail parser datetime_with_levels_of_precision.
    scope :datetime_on, lambda { |ymd_string, col:|
      reformat = DateTime.strptime(ymd_string, "%Y-%m-%d").strftime("%Y-%m-%d")
      where(arel_table[col].format("%Y-%m-%d").eq(reformat))
    }
    scope :at_datetime, lambda { |ymd_string, col:|
      reformat = DateTime.strptime(ymd_string, "%Y-%m-%d-%H-%M-%S").
                 strftime("%Y-%m-%d-%H-%M-%S")
      where(arel_table[col].format("%Y-%m-%d-%H-%M-%S").eq(reformat))
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
    # ranges: not just between dates, but also dates within a seasonal range in
    # recurring years. This is possible via string parsing class methods (below)
    # because in the database, a date column already has the format("%Y-%m-%d").
    # In this scope, the order of early and late do matter. early > late can
    # mean a date range wrapping the end/beginning of the year.
    # NOTE: On MO so far, all date columns are named :when.
    scope :date, lambda { |early, late = nil, col: :when|
      early, late = early if early.is_a?(Array)
      early, late = ::DateRangeParser.new(early).range if late.blank?
      if late.blank?
        date_after(early, col:)
      else
        date_between(early, late, col:)
      end
    }

    ##########################################################################
    #
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

    ############################################################################
    #
    # ADVANCED SEARCH SCOPES
    #
    # Search Content
    # Could do left outer join from observations to comments, but it
    # takes longer.  Instead, break it into two queries, one without
    # comments, and another with inner join on comments.
    # NOTE: `klass` refers to the model of an ActiveRecord_Relation
    scope :search_content, lambda { |phrase|
      if klass.name == "Observation"
        obs_joins = nil
        comment_joins = :comments
      else
        obs_joins = :observations
        comment_joins = { observations: :comments }
      end
      ids = joins(obs_joins).
            search_columns(Observation[:notes], phrase).distinct.map(&:id)
      ids += joins(comment_joins).
             search_columns(
               Observation[:notes] + Comment[:summary] + Comment[:comment],
               phrase
             ).distinct.map(&:id)
      where(id: ids).distinct
    }
    scope :search_name, lambda { |phrase|
      joins = case klass.name
              when "Name"
                nil
              when "Observation"
                :name
              else
                { observations: :name }
              end
      joins(joins).search_columns(Name[:search_name], phrase)
    }
    scope :search_user, lambda { |phrase|
      phrase = User.remove_bracketed_name(phrase)
      scope = all
      scope = case klass.name
              when "Observation"
                scope.joins(:user)
              when "Name", "Location"
                scope.joins(observations: :user)
              else
                scope
              end
      scope.search_columns(User[:login] + User[:name], phrase)
    }
    scope :search_where, lambda { |phrase|
      scope = all
      scope = case klass.name
              when "Observation"
                scope.left_outer_joins(:location)
              when "Name"
                scope.joins(
                  :observations,
                  Observation.left_outer_joins(:location).arel.join_sources
                )
              when "Location"
                scope
              end
      field = if klass.name == "Location"
                Location[:name]
              else
                Observation[:where]
              end
      scope.search_columns(field, phrase)
    }

    # Used in Name, Observation and Project so far.
    # Ignores false.
    scope :has_comments, lambda { |bool = true|
      return all unless bool

      joined_relation_condition(:comments, bool:)
    }
    scope :comments_has, lambda { |phrase|
      joins(:comments).merge(Comment.search_content(phrase)).distinct
    }
  end

  # class methods here, `self` included
  module ClassMethods
    # Utility for all subqueries, which are defined on the model
    # Callers must do their own joins to `model_name` because we can't know
    # whether the association (has_one, has_many) is singular or plural.
    def subquery(model_name, params)
      return all if params.blank?

      subquery = Query.create_query(model_name, **params).scope.reorder("")
      merge(subquery).distinct
    end

    # array of max of MO.query_max_array unique ids for use with Arel "in"
    #    where(<x>.in(limited_id_set(ids)))
    def limited_id_set(ids)
      ids = [ids].flatten
      ids.map!(&:id) if ids.first.is_a?(AbstractModel)
      ids.map(&:to_i).uniq[0, MO.query_max_array] # [] is valid
    end

    def datetime_compare(dir, val, col:)
      # `datetime_condition_formatted` defined in ClassMethods below
      return unless (datetime = datetime_condition_formatted(dir, val))

      where(arel_table[col].send(:"#{dir}eq", datetime))
    end

    # Fills out the datetime with min/max values for month, day, hour, minute,
    # second, as appropriate for < > comparisons. Only year is required.
    def datetime_condition_formatted(dir, val)
      y, m, d, h, n, s = val.split("-").map(&:to_i)
      return unless /^\d\d\d\d/.match?(y.to_s)

      returns = dir == :gt ? [y, 1, 1, 0, 0, 0] : [y, 12, 31, 23, 59, 59]
      vals = [m, d, h, n, s].compact # get as many specific values as were sent
      returns[1, vals.length] = vals # merge these into the defaults, after year
      # reformat to "%Y-%m-%d %H:%i:%s" as expected
      [returns[0..2]&.join("-"), returns[3..5]&.join(":")].join(" ")
    end

    # We infer different scopes from the level of detail provided:
    # - If a single "YYYY" is passed to a datetime scope, it should return
    #   records where the col value is within the year.
    # - Ditto for "YYYY-MM" - records within that month.
    # - If it gets a full date, it returns records on that date.
    # - If it gets a full datetime, returns records at that exact time.
    def datetime_with_levels_of_precision(date, col:)
      y, m, d, h = date.split("-").map!(&:to_i) # minute and second ignored here
      return unless /^\d\d\d\d/.match?(y.to_s)
      return at_datetime(date, col:) if h.present? # precise time
      return datetime_on(date, col:) if d.present? # within day
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

    # This tolerates text values for "true" and "false"
    def boolean_condition(table_column, bool: true)
      if bool.to_s.to_boolean == true
        where(table_column.eq(true))
      else
        where(table_column.not_eq(true))
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

    # this actually produces coalesce("").length.gt(0)
    def not_blank_condition(table_column, bool: true)
      if bool.to_s.to_boolean == true
        where(table_column.not_blank)
      else
        where(table_column.blank)
      end
    end
  end
end

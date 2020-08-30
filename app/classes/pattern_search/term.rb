# frozen_string_literal: true

module PatternSearch
  # Parse PatternSearch parameter terms
  # Sample use:
  #   elsif term.var == :specimen
  #     args[:has_specimen] = term.parse_boolean_string
  class Term
    attr_accessor :var, :vals

    def initialize(var)
      self.var = var
      self.vals = []
    end

    CONTAINS_QUOTES =
      /^("([^\"\\]+|\\.)*"|'([^\"\\]+|\\.)*'|[^\"\',]*)(\s*,\s*|$)/.freeze

    def <<(val)
      while val.to_s =~ CONTAINS_QUOTES
        vals << dequote(Regexp.last_match(1))
        val = val.to_s[Regexp.last_match(0).length..-1]
        break if val.blank?
      end
    end

    def quote(val)
      if /['" \\]/.match?(val.to_s)
        '"' + val.to_s.gsub(/(['"\\])/) { |v| '\\' + v } + '"'
      else
        val.to_s
      end
    end

    def dequote(val)
      val.to_s.sub(/^['"](.*)['"]$/, '\1').gsub(/\\(.)/, '\1')
    end

    def parse_pattern
      make_sure_values_not_empty!
      vals.map { |v| quote(v) }.join(" ")
    end

    def parse_boolean(only_yes = false)
      val = make_sure_there_is_one_value!
      return true if /^(1|yes|true)$/i.match?(val)

      raise(BadYesError.new(var: var, val: val)) if only_yes
      return false if /^(0|no|false)$/i.match?(val)

      raise(BadBooleanError.new(var: var, val: val))
    end

    def parse_yes
      parse_boolean(:only_yes) && "yes"
    end

    def parse_yes_no_both
      val = make_sure_there_is_one_value!
      return "only"   if /^(1|yes|true)$/i.match?(val)
      return "no"     if /^(0|no|false)$/i.match?(val)
      return "either" if /^(both|either)$/i.match?(val)

      raise(BadYesNoBothError.new(var: var, val: val))
    end

    def parse_list_of_names
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          ::Name.safe_find(val) ||
            raise(BadNameError.new(var: var, val: val))
        else
          ::Name.find_by_text_name(val) || ::Name.find_by_search_name(val) ||
            raise(BadNameError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_herbaria
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          Herbarium.safe_find(val) ||
            raise(BadHerbariumError.new(var: var, val: val))
        else
          Herbarium.find_by_code(val) ||
            Herbarium.find_by_name(val) ||
            raise(BadHerbariumError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_locations
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          Location.safe_find(val) ||
            raise(BadLocationError.new(var: var, val: val))
        else
          Location.find_by_name(val) ||
            Location.find_by_scientific_name(val) ||
            raise(BadLocationError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_projects
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          Project.safe_find(val) ||
            raise(BadProjectError.new(var: var, val: val))
        else
          Project.find_by_title(val) ||
            raise(BadProjectError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_species_lists
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          SpeciesList.safe_find(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        else
          SpeciesList.find_by_title(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_users
      make_sure_values_not_empty!
      vals.map do |val|
        if /^\d+$/.match?(val)
          User.safe_find(val) ||
            raise(BadUserError.new(var: var, val: val))
        else
          User.find_by_login(val) ||
            User.find_by_name(val) ||
            raise(BadUserError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_string
      make_sure_there_is_one_value!
    end

    def parse_float(min, max)
      val = make_sure_there_is_one_value!
      raise(BadFloatError.new(var: var, val: val, min: min, max: max)) \
        unless /^-?(\d+(\.\d+)?|\.\d+)$/.match?(val.to_s)
      raise(BadFloatError.new(var: var, val: val, min: min, max: max)) \
        unless val.to_f >= min && val.to_f <= max

      val.to_f
    end

    def parse_latitude
      parse_float(-90, 90)
    end

    def parse_longitude
      parse_float(-180, 180)
    end

    def parse_confidence
      val = make_sure_there_is_one_value!
      from, to = val.to_s.split("-", 2)
      [parse_one_confidence_value(from),
       parse_one_confidence_value(to || "100")]
    end

    def parse_one_confidence_value(val)
      val.to_s.match(/^-?(\d+(\.\d+)?|\.\d+)$/) &&
        (-100..100).cover?(val.to_f) ||
        raise(BadConfidenceError.new(var: var, val: val))

      [val.to_f * 3 / 100, 3]
    end

    def parse_date_range
      val = make_sure_there_is_one_value!
      # rubocop:disable Style/CaseLikeIf
      # case does not work if the code nested after "when /regex/" uses a
      # named capture group
      if /^(?<yr>\d{4})$/ =~ val
        yyyymmdd([yr, 1, 1], [yr, 12, 31])
      elsif /^(?<yr>\d{4})-(?<mo>\d\d?)$/ =~ val
        yyyymmdd([yr, mo, 1], [yr, mo, 31])
      elsif /^(?<yr>\d{4})-(?<mo>\d\d?)-(?<day>\d\d?)$/ =~ val
        yyyymmdd([yr, mo, day], [yr, mo, day])
      elsif /^(?<yr1>\d{4})-(?<yr2>\d{4})$/ =~ val
        yyyymmdd([yr1, 1, 1], [yr2, 12, 31])
      elsif /^(?<yr1>\d{4})-(?<mo1>\d\d?)-(?<yr2>\d{4})-(?<mo2>\d\d?)$/ =~ val
        yyyymmdd([yr1, mo1, 1], [yr2, mo2, 31])
      elsif /^(?<yr1>\d{4})-(?<mo1>\d\d?)-(?<dy1>\d\d?)-
             (?<yr2>\d{4})-(?<mo2>\d\d?)-(?<dy2>\d\d?)$/x =~ val
        yyyymmdd([yr1, mo1, dy1], [yr2, mo2, dy2])
      elsif /^(?<mo>\d\d?)$/ =~ val
        mmdd([mo, 1], [mo, 31])
      elsif /^(?<mo1>\d\d?)-(?<mo2>\d\d?)$/ =~ val
        mmdd([mo1, 1], [mo2, 31])
      elsif /^(?<mo1>\d\d?)-(?<dy1>\d\d?)-(?<mo2>\d\d?)-(?<dy2>\d\d?)$/ =~ val
        mmdd([mo1, dy1], [mo2, dy2])
      else
        raise(BadDateRangeError.new(var: var, val: val))
      end
      # rubocop:enable Style/CaseLikeIf
    end

    def yyyymmdd(from, to)
      [format("%04d-%02d-%02d", from.first, from.second.to_i, from.third.to_i),
       format("%04d-%02d-%02d", to.first, to.second.to_i, to.third.to_i)]
    end

    def mmdd(from, to)
      [format("%02d-%02d", from.first.to_i, from.second.to_i),
       format("%02d-%02d", to.first.to_i, to.second.to_i)]
    end

    def parse_rank_range
      val = make_sure_there_is_one_value!
      from, to = val.split("-", 2).map(&:strip)
      to ||= from
      from = lookup_rank(from)
      to   = lookup_rank(to)
      raise(BadRankRangeError.new(var: var, val: val)) if from.nil? || to.nil?

      from == to ? [from] : [from, to]
    end

    def lookup_rank(val)
      val = val.downcase
      ::Name.all_ranks.each do |rank|
        if val == rank.to_s.downcase ||
           val == :"rank_#{rank.to_s.downcase}".l || alt_rank_check(rank, val)
          return rank
        end
      end
      nil
    end

    def alt_rank_check(rank, val)
      if [:Phylum, :Group].include?(rank)
        ranks = :"rank_alt_#{rank.to_s.downcase}".l.split(",")
        ranks.map(&:strip).include?(val)
      else
        false
      end
    end

    def make_sure_values_not_empty!
      raise(MissingValueError.new(var: var)) if vals.empty?
    end

    def make_sure_there_is_one_value!
      raise(MissingValueError.new(var: var)) if vals.empty?
      raise(TooManyValuesError.new(var: var)) if vals.length > 1

      vals.first
    end
  end
end

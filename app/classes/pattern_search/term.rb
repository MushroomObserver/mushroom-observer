# frozen_string_literal: true

module PatternSearch
  # Parse PatternSearch parameter terms
  # Sample use:
  #   elsif term.var == :specimen
  #     args[:has_specimen] = term.parse_boolean_string
  class Term
    require_dependency "pattern_search/term/dates"
    include Dates

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

    def first_val
      vals.first
    end

    def parse_pattern
      make_sure_values_not_empty!
      vals.map { |v| quote(v) }.join(" ")
    end

    def parse_boolean(only_yes = false)
      val = make_sure_there_is_one_value!
      return true if /^(1|yes|true|#{:search_value_true.l})$/i.match?(val)

      raise(BadYesError.new(var: var, val: val)) if only_yes
      return false if /^(0|no|false|#{:search_value_false.l})$/i.match?(val)

      raise(BadBooleanError.new(var: var, val: val))
    end

    def parse_yes
      parse_boolean(:only_yes) && "yes"
    end

    def parse_yes_no_both
      val = make_sure_there_is_one_value!
      return "only"   if /^(1|yes|true|#{:search_value_true.l})$/i.match?(val)
      return "no"     if /^(0|no|false|#{:search_value_false.l})$/i.match?(val)
      return "either" if /^(both|either|#{:search_value_both.l})$/i.match?(val)

      raise(BadYesNoBothError.new(var: var, val: val))
    end

    def parse_list_of_names
      make_sure_values_not_empty!
      vals.map do |val|
        # cop gives false positive
        if /^\d+$/.match?(val) # rubocop:disable Style/GuardClause
          ::Name.safe_find(val) ||
            raise(BadNameError.new(var: var, val: val))
        else
          ::Name.find_by_text_name(val) || ::Name.find_by_search_name(val) ||
            raise(BadNameError.new(var: var, val: val))
        end
      end.flatten.map(&:id).uniq
    end

    def parse_list_of_herbaria
      make_sure_values_not_empty!
      vals.map do |val|
        # cop gives false positive
        if /^\d+$/.match?(val) # rubocop:disable Style/GuardClause
          Herbarium.safe_find(val) ||
            raise(BadHerbariumError.new(var: var, val: val))
        else
          Herbarium.find_by_code_with_wildcards(val) ||
            Herbarium.find_by_name_with_wildcards(val) ||
            raise(BadHerbariumError.new(var: var, val: val))
        end
      end.flatten.map(&:id).uniq
    end

    def parse_list_of_locations
      make_sure_values_not_empty!
      vals.map do |val|
        # cop gives false positive
        if /^\d+$/.match?(val) # rubocop:disable Style/GuardClause
          Location.safe_find(val) ||
            raise(BadLocationError.new(var: var, val: val))
        else
          Location.find_by_name_with_wildcards(val) ||
            Location.find_by_scientific_name_with_wildcards(val) ||
            raise(BadLocationError.new(var: var, val: val))
        end
      end.flatten.map(&:id).uniq
    end

    def parse_list_of_projects
      make_sure_values_not_empty!
      vals.map do |val|
        # cop gives false positive
        if /^\d+$/.match?(val) # rubocop:disable Style/GuardClause
          Project.safe_find(val) ||
            raise(BadProjectError.new(var: var, val: val))
        else
          Project.find_by_title_with_wildcards(val) ||
            raise(BadProjectError.new(var: var, val: val))
        end
      end.flatten.map(&:id).uniq
    end

    def parse_list_of_species_lists
      make_sure_values_not_empty!
      vals.map do |val|
        # cop gives false positive
        if /^\d+$/.match?(val) # rubocop:disable Style/GuardClause
          SpeciesList.safe_find(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        else
          SpeciesList.find_by_title_with_wildcards(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        end
      end.flatten.map(&:id).uniq
    end

    def parse_list_of_users
      make_sure_values_not_empty!
      vals.map { |val| parse_one_user(val) }.flatten.map(&:id).uniq
    end

    def parse_one_user(val)
      case val
      when "me" || :search_value_me.l
        User.current ||
          raise(UserMeNotLoggedInError.new)
      when /^\d+$/
        User.safe_find(val) ||
          raise(BadUserError.new(var: var, val: val))
      else
        User.find_by_login(val) ||
          User.find_by_name(val) ||
          raise(BadUserError.new(var: var, val: val))
      end
    end

    def parse_list_of_strings
      vals
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
      from, to = val.to_s.split(/(?<=\d)-/, 2)
      [parse_one_confidence_value(from),
       parse_one_confidence_value(to || "100")]
    end

    def parse_one_confidence_value(val)
      val.to_s.match(/^-?(\d+(\.\d+)?|\.\d+)$/) &&
        (-100..100).cover?(val.to_f) ||
        raise(BadConfidenceError.new(var: var, val: val))

      val.to_f * 3 / 100
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

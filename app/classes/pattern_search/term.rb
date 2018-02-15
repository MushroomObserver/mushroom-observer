module PatternSearch
  # Parse PatternSearch parameter terms
  # Sample use:
  #   elsif term.var == :specimen
  #     args[:has_specimen] = term.parse_boolean_string
  class Term
    attr_accessor :var
    attr_accessor :vals

    def initialize(var)
      self.var = var
      self.vals = []
    end

    def <<(val)
      while val.to_s.match(/^("([^\"\\]+|\\.)*"|'([^\"\\]+|\\.)*'|[^\"\',]*)(\s*,\s*|$)/)
        vals << dequote(Regexp.last_match(1))
        val = val.to_s[Regexp.last_match(0).length..-1]
        break if val.blank?
      end
    end

    def quote(x)
      if x.to_s.match(/['" \\]/)
        '"' + x.to_s.gsub(/(['"\\])/) { |v| '\\' + v } + '"'
      else
        x.to_s
      end
    end

    def dequote(x)
      x.to_s.sub(/^['"](.*)['"]$/, '\1').gsub(/\\(.)/, '\1')
    end

    def parse_pattern
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map { |v| quote(v) }.join(" ")
    end

    def parse_boolean(only_yes = false)
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      return true  if val.match(/^(1|yes|true)$/i)
      return false if val.match(/^(0|no|false)$/i) && !only_yes
      raise BadYesError.new(var: var, val: val) if only_yes
      raise BadBooleanError.new(var: var, val: val)
    end

    def parse_yes
      parse_boolean(:only_yes) && "yes"
    end

    def parse_yes_no_both
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      return "only"   if val.match(/^(1|yes|true)$/i)
      return "no"     if val.match(/^(0|no|false)$/i)
      return "either" if val.match(/^(both|either)$/i)
      raise BadYesNoBothError.new(var: var, val: val)
    end

    # Assure that param has only one value - a booleanish string -
    #   returning "TRUE" or "FALSE" (rather than true/false).
    # This is needed where the param interacts with user content filters and
    #   and where the relevant sql string is TRUE / FALSE
    #   e.g., :has_specimen
    def parse_to_true_false_string(only_yes = false)
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      return "TRUE" if val.match(/^(1|yes|true)$/i)
      return "FALSE" if val.match(/^(0|no|false)$/i) && !only_yes
      raise BadYesError.new(var: var, val: val) if only_yes
      raise BadBooleanError.new(var: var, val: val)
    end

    # Assure that param has only one value - a booleanish string -
    #   returning "NULL" or "NOT NULL" (rather than true/false).
    # This is needed where the param interacts with user content filters and
    #   and where the relevant sql string is NULL / NOT NULL
    #   e.g., :has_images
    def parse_to_null_not_null_string(only_yes = false)
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      return "NOT NULL" if val.match(/^(1|yes|true)$/i)
      return "NULL" if val.match(/^(0|no|false)$/i) && !only_yes
      raise BadYesError.new(var: var, val: val) if only_yes
      raise BadBooleanError.new(var: var, val: val)
    end

    def parse_list_of_names
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
          ::Name.safe_find(val) ||
            raise(BadNameError.new(var: var, val: val))
        else
          ::Name.find_by_text_name(val) || ::Name.find_by_search_name(val) ||
            raise(BadNameError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_herbaria
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
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
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
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
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
          Project.safe_find(val) ||
            raise(BadProjectError.new(var: var, val: val))
        else
          Project.find_by_title(val) ||
            raise(BadProjectError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_species_lists
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
          SpeciesList.safe_find(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        else
          SpeciesList.find_by_title(val) ||
            raise(BadSpeciesListError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_list_of_users
      raise MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
          User.safe_find(val) ||
            raise(BadUserError.new(var: var, val: val))
        else
          User.find_by_login(val) ||
            User.find_by_name(val)  ||
            raise(BadUserError.new(var: var, val: val))
        end
      end.map(&:id)
    end

    def parse_string
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      vals.first
    end

    def parse_float(min, max)
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      raise BadFloatError.new(var: var, val:val, min: min, max: max) \
        unless val.to_s.match(/^-?(\d+(\.\d+)?|\.\d+)$/)
      raise BadFloatError.new(var: var, val:val, min: min, max: max) \
        unless val.to_f >= min && val.to_f <= max
      return val.to_f
    end

    def parse_latitude
      parse_float(-90, 90)
    end

    def parse_longitude
      parse_float(-180, 180)
    end

    def parse_confidence
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      if val.to_s.match(/^-?(\d+(\.\d+)?|\.\d+)$/) &&
         (-100..100).include?(val.to_f)
        [val.to_f * 3 / 100, 3]
      elsif val.to_s.match(/^(-?\d+(\.\d+)?|-?\.\d+)-(-?\d+(\.\d+)?|-?\.\d+)$/) &&
            (-100..100).include?(Regexp.last_match(1).to_f) &&
            (-100..100).include?(Regexp.last_match(3).to_f) &&
            Regexp.last_match(1).to_f <= Regexp.last_match(3).to_f
        [Regexp.last_match(1).to_f * 3 / 100, Regexp.last_match(3).to_f * 3 / 100]
      else
        raise BadConfidenceError.new(var: var, val: val)
      end
    end

    def parse_date_range
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      if val.match(/^(\d\d\d\d)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, 1, 1], "%04d-%02d-%02d" % [Regexp.last_match(1).to_i, 12, 31]]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, 1], "%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, 31]]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d?)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i], "%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i]]
      elsif val.match(/^(\d\d\d\d)-(\d\d\d\d)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, 1, 1], "%04d-%02d-%02d" % [Regexp.last_match(2).to_i, 12, 31]]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d\d\d)-(\d\d?)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, 1], "%04d-%02d-%02d" % [Regexp.last_match(3).to_i, Regexp.last_match(4).to_i, 31]]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d?)-(\d\d\d\d)-(\d\d?)-(\d\d?)$/)
        ["%04d-%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i], "%04d-%02d-%02d" % [Regexp.last_match(4).to_i, Regexp.last_match(5).to_i, Regexp.last_match(6).to_i]]
      elsif val.match(/^(\d\d?)$/)
        ["%02d-%02d" % [Regexp.last_match(1).to_i, 1], "%02d-%02d" % [Regexp.last_match(1).to_i, 31]]
      elsif val.match(/^(\d\d?)-(\d\d?)$/)
        ["%02d-%02d" % [Regexp.last_match(1).to_i, 1], "%02d-%02d" % [Regexp.last_match(2).to_i, 31]]
      elsif val.match(/^(\d\d?)-(\d\d?)-(\d\d?)-(\d\d?)$/)
        ["%02d-%02d" % [Regexp.last_match(1).to_i, Regexp.last_match(2).to_i], "%02d-%02d" % [Regexp.last_match(3).to_i, Regexp.last_match(4).to_i]]
      else
        raise BadDateRangeError.new(var: var, val: val)
      end
    end

    def parse_rank_range
      raise MissingValueError.new(var: var) if vals.empty?
      raise TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      from, to = val.split("-", 2).map(&:strip)
      to ||= from
      from = lookup_rank(from)
      to   = lookup_rank(to)
      raise BadRankRangeError.new(var: var, val: val) if from.nil? || to.nil?
      from == to ? [from] : [from, to]
    end

    def lookup_rank(val)
      val = val.downcase
      ::Name.all_ranks.each do |rank|
        if val == rank.to_s.downcase ||
           val == :"rank_#{rank.to_s.downcase}".l ||
           (rank == :Phylum || rank == :Group) &&
             :"rank_alt_#{rank.to_s.downcase}".l.
               split(",").map(&:strip).include?(val)
          return rank
        end
      end
      nil
    end
  end
end

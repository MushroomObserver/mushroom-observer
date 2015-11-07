# encoding: utf-8

module PatternSearch
  class Term
    attr_accessor :var
    attr_accessor :vals

    def initialize(var)
      self.var = var
      self.vals = []
    end

    def <<(val)
      vals << val
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
      fail MissingValueError.new(var: var) if vals.empty?
      vals.map { |v| quote(v) }.join(" ")
    end

    def parse_boolean
      fail MissingValueError.new(var: var) if vals.empty?
      fail TooManyValuesError.new(var: var) if vals.length > 1
      val = vals.first
      return true  if val.match(/^(1|yes|true)$/i)
      return false if val.match(/^(0|no|false)$/i)
      fail BadBooleanError.new(var: var, val: val)
    end

    def parse_list_of_users
      fail MissingValueError.new(var: var) if vals.empty?
      vals.map do |val|
        if val.match(/^\d+$/)
          (user = User.safe_find(val)) ||
            fail(BadUserError.new(var: var, val: val))
        else
          (user = User.find_by_login(val)) ||
            (user = User.find_by_name(val)) ||
            fail(BadUserError.new(var: var, val: val))
        end
        user
      end
    end

    def parse_date_range
      fail MissingValueError.new(var: var) if vals.empty?
      fail TooManyValuesError.new(var: var) if vals.length > 1
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
        fail BadDateRangeError.new(var: var, val: val)
      end
    end
  end
end

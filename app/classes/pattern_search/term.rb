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
      self.vals << val
    end

    def quote(x)
      if x.to_s.match(/['" \\]/)
        '"' + x.to_s.gsub(/(['"\\])/) {|v| '\\'+v} + '"'
      else
        x.to_s
      end
    end

    def dequote(x)
      x.to_s.sub(/^['"](.*)['"]$/, '\1').gsub(/\\(.)/, '\1')
    end

    def parse_pattern
      raise MissingValueError.new(:var => var) if vals.empty?
      return vals.map {|v| quote(v)}.join(' ')
    end

    def parse_boolean
      raise MissingValueError.new(:var => var) if vals.empty?
      raise TooManyValuesError.new(:var => var) if vals.length > 1
      val = vals.first
      return true  if val.match(/^(1|yes|true)$/i) 
      return false if val.match(/^(0|no|false)$/i)
      raise BadBooleanError.new(:var => var, :val => val)
    end

    def parse_list_of_users
      raise MissingValueError.new(:var => var) if vals.empty?
      return vals.map do |val|
        if val.match(/^\d+$/)
          (user = User.safe_find(val)) or
            raise BadUserError.new(:var => var, :val => val)
        else
          (user = User.find_by_login(val)) or
          (user = User.find_by_name(val)) or
            raise BadUserError.new(:var => var, :val => val)
        end
        user
      end
    end

    def parse_date_range
      raise MissingValueError.new(:var => var) if vals.empty?
      raise TooManyValuesError.new(:var => var) if vals.length > 1
      val = vals.first
      if val.match(/^(\d\d\d\d)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, 1, 1], '%04d-%02d-%02d' % [$1.to_i, 12, 31] ]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, $2.to_i, 1], '%04d-%02d-%02d' % [$1.to_i, $2.to_i, 31] ]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d?)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, $2.to_i, $3.to_i], '%04d-%02d-%02d' % [$1.to_i, $2.to_i, $3.to_i] ]
      elsif val.match(/^(\d\d\d\d)-(\d\d\d\d)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, 1, 1], '%04d-%02d-%02d' % [$2.to_i, 12, 31] ]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d\d\d)-(\d\d?)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, $2.to_i, 1], '%04d-%02d-%02d' % [$3.to_i, $4.to_i, 31] ]
      elsif val.match(/^(\d\d\d\d)-(\d\d?)-(\d\d?)-(\d\d\d\d)-(\d\d?)-(\d\d?)$/)
        [ '%04d-%02d-%02d' % [$1.to_i, $2.to_i, $3.to_i], '%04d-%02d-%02d' % [$4.to_i, $5.to_i, $6.to_i] ]
      elsif val.match(/^(\d\d?)$/)
        [ '%02d-%02d' % [$1.to_i, 1], '%02d-%02d' % [$1.to_i, 31] ]
      elsif val.match(/^(\d\d?)-(\d\d?)$/)
        [ '%02d-%02d' % [$1.to_i, 1], '%02d-%02d' % [$2.to_i, 31] ]
      elsif val.match(/^(\d\d?)-(\d\d?)-(\d\d?)-(\d\d?)$/)
        [ '%02d-%02d' % [$1.to_i, $2.to_i], '%02d-%02d' % [$3.to_i, $4.to_i] ]
      else
        raise BadDateRangeError.new(:var => var, :val => val)
      end
    end
  end
end

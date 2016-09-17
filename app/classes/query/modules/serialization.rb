module Query::Modules::Serialization
  def self.included(base)
    base.extend(ClassMethods)
  end

  def serialize
    hash = params.merge(
      model:  model.to_s.to_sym,
      flavor: flavor
    )
    hash.keys.sort_by(&:to_s).map do |key|
      val = hash[key]
      if key.to_s.match(/\W/)
        fail "Keys of params must be all alphanumeric: '#{key}'"
      end
      key.to_s + "=" + serialize_value(val)
    end.join(";")
  end

  def serialize_value(val)
    case val
    when Array      then "@" + val.map { |v| serialize_value(v) }.join(",")
    when String     then '$' + serialize_string(val)
    when Symbol     then ":" + serialize_string(val.to_s)
    when Fixnum     then '#' + val.to_s
    when Float      then "#" + val.to_s
    when TrueClass  then "1"
    when FalseClass then "0"
    when NilClass   then "-"
    else fail "Invalid value in params: '#{val.class.name}:#{val}'"
    end
  end

  def serialize_string(val)
    # The "n" modifier forces the Regexp to be in ascii 8 bit encoding = binary.
    val.force_encoding("binary").gsub(/[,;:#%&=\/\?\x00-\x1F\x7F-\xFF]/n) do |char|
      "%" + ("%02.2X" % char.ord)
    end
  end

  module ClassMethods
    def deserialize(str)
      params = {}
      str.split(";").each do |line|
        if line.match(/^(\w+)=(.*)/)
          key = Regexp.last_match(1)
          val = Regexp.last_match(2)
          params[key.to_sym] = deserialize_value(val)
        end
      end
      model  = params[:model]
      flavor = params[:flavor]
      params.delete(:model)
      params.delete(:flavor)
      Query.new(model, flavor, params)
    end

    def deserialize_value(val)
      val = val.sub(/^(.)/, "")
      case Regexp.last_match(1)
      when "@" then val.split(",").map { |v| deserialize_value(v) }
      when "$" then deserialize_string(val)
      when ":" then deserialize_string(val).to_sym
      when '#' then deserialize_number(val)
      when "1" then true
      when "0" then false
      when "-" then nil
      else fail "Invalid value in params: '#{Regexp.last_match(1)}#{val}'"
      end
    end

    def deserialize_string(val)
      val.force_encoding("binary").gsub(/%(..)/) do |match|
        match[1..2].hex.chr("binary")
      end.force_encoding("UTF-8")
    end

    def deserialize_number(val)
      val.include?(".") ? val.to_f : val.to_i
    end
  end
end

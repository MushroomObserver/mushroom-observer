# frozen_string_literal: true

class API2
  # Information about an API parameter to provide automatic documentation
  class ParameterDeclaration
    attr_accessor :key, :type, :args, :set_parameter, :deprecated

    def initialize(key, type, args = {})
      self.key  = key
      self.type = type
      self.args = args
    end

    def set_parameter?
      @set_parameter
    end

    def deprecated?
      @deprecated
    end

    def inspect
      "#{key}: #{show_type}#{show_args}"
    end

    def show_type
      val = type.to_s
      val += " range" if args[:range]
      val += " list"  if args[:list]
      val
    end

    def show_args
      hash = args.except(:as, :list, :range)
      hash.delete(:default) if hash[:default].to_s == ""
      if /^\d+$/.match?(hash[:limit].to_s)
        hash[:limit] = "#{hash[:limit]} chars"
      end
      return "" if hash.empty?

      body = hash.map { |key, val| show_arg(key, val) }.join(", ")
      " (#{body})"
    end

    def show_arg(key, val)
      key = key.to_s.tr("_", " ")
      if key == "help"
        val = @key if val == 1
        tag = :"api_help_#{val}"
        tag.l
      elsif key != "limit" && val == true
        key
      else
        "#{key}=#{show_val(val)}"
      end
    end

    def show_val(val)
      case val
      when String, Symbol, Integer, Float, Range
        val.to_s
      when Array
        val.map(&:to_s).sort.join("|")
      when TrueClass
        "true"
      when FalseClass
        "false"
      when Date, License
        "varies"
      when Name
        val.search_name
      when User
        "you"
      else
        raise("Don't know how to display #{val.class.name} in api help msg.")
      end
    end
  end
end
